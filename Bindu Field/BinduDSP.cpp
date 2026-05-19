//
//  BinduDSP.cpp
//  ASG / Bindu Field
//
//  Implementation of real-time audio feature extraction kernel.
//  See BinduDSP.h for interface contract and threading model.
//

#include "BinduDSP.h"
#include <algorithm>
#include <cmath>
#include <cstring>

namespace ASG {

// ============================================================================
//  FrameRingBuffer
// ============================================================================
//  SPSC lock-free ring buffer using std::atomic indices.
//  Producer writes at writeIdx_, consumer reads at readIdx_.
//  Empty when read == write. Full when (write + 1) % CAPACITY == read.
//  CAPACITY chosen as power of 2 for fast modulo via bitmask, but we use
//  modulo arithmetic for clarity — branch predictor handles it.
// ============================================================================

FrameRingBuffer::FrameRingBuffer() {
    static_assert(CAPACITY > 0 && (CAPACITY & (CAPACITY - 1)) == 0,
                  "RING_CAPACITY must be power of 2");
    // POD members default-initialized in struct; explicit zero not needed
    // but reset state to defined values for safety:
    writeIdx_.store(0, std::memory_order_relaxed);
    readIdx_.store(0, std::memory_order_relaxed);
}

bool FrameRingBuffer::push(const BinduFrame& frame) {
    const uint32_t w = writeIdx_.load(std::memory_order_relaxed);
    const uint32_t next = (w + 1) % CAPACITY;
    const uint32_t r = readIdx_.load(std::memory_order_acquire);

    if (next == r) {
        // Buffer full — drop frame.
        // Acceptable: JS polls at 100ms, frames produced ~47fps,
        // capacity 64 ≈ 1.3s backlog. Full state implies consumer stalled.
        return false;
    }

    buffer_[w] = frame;
    writeIdx_.store(next, std::memory_order_release);
    return true;
}

bool FrameRingBuffer::pop(BinduFrame& out) {
    const uint32_t r = readIdx_.load(std::memory_order_relaxed);
    const uint32_t w = writeIdx_.load(std::memory_order_acquire);

    if (r == w) {
        return false;  // empty
    }

    out = buffer_[r];
    readIdx_.store((r + 1) % CAPACITY, std::memory_order_release);
    return true;
}

bool FrameRingBuffer::peekLatest(BinduFrame& out) {
    // Read the most recently written frame without advancing readIdx_.
    // Used by JS bridge — "give me the latest" semantics.
    const uint32_t w = writeIdx_.load(std::memory_order_acquire);
    const uint32_t r = readIdx_.load(std::memory_order_relaxed);

    if (r == w) {
        return false;  // empty
    }

    // Most recent = position (w - 1) mod CAPACITY
    const uint32_t latest = (w == 0) ? (CAPACITY - 1) : (w - 1);
    out = buffer_[latest];

    // Advance readIdx_ to current w so subsequent reads see only new frames.
    // This is a "consume up to now" pattern — drops intermediate frames.
    readIdx_.store(w, std::memory_order_release);
    return true;
}

void FrameRingBuffer::clear() {
    // Not real-time safe. Caller must guarantee no concurrent producer.
    writeIdx_.store(0, std::memory_order_release);
    readIdx_.store(0, std::memory_order_release);
}

// ============================================================================
//  BinduDSP — Construction / Initialization
// ============================================================================

BinduDSP::BinduDSP()
    : sampleRate_(48000.0f)
    , initialized_(false)
    , framesProduced_(0)
    , fftSetup_(nullptr)
    , carrierFftSetup_(nullptr)
    , accumWritePos_(0)
    , prevMagsWriteIdx_(0)
    , fluxHistoryWriteIdx_(0)
    , fluxHistoryCount_(0)
    , onsetCooldownFrames_(0)
    , onsetCooldownReset_(0)
    , rmsRollingMax_(0.001f)
    , carrierAccumWritePos_(0)
    , carrierFramesAccumulated_(0)
{
    splitComplex_.realp = fftRealBuffer_;
    splitComplex_.imagp = fftImagBuffer_;

    std::memset(accumBuffer_, 0, sizeof(accumBuffer_));
    std::memset(windowedBuffer_, 0, sizeof(windowedBuffer_));
    std::memset(fftRealBuffer_, 0, sizeof(fftRealBuffer_));
    std::memset(fftImagBuffer_, 0, sizeof(fftImagBuffer_));
    std::memset(magnitudes_, 0, sizeof(magnitudes_));
    std::memset(normalizedMags_, 0, sizeof(normalizedMags_));
    std::memset(prevMags_, 0, sizeof(prevMags_));
    std::memset(fluxHistory_, 0, sizeof(fluxHistory_));
    std::memset(binFrequencies_, 0, sizeof(binFrequencies_));
    std::memset(carrierAccumBuffer_, 0, sizeof(carrierAccumBuffer_));
    std::memset(carrierAvgSpectrum_, 0, sizeof(carrierAvgSpectrum_));
    std::memset(carrierHannWindow_, 0, sizeof(carrierHannWindow_));
}

BinduDSP::~BinduDSP() {
    if (fftSetup_) {
        vDSP_destroy_fftsetup(fftSetup_);
        fftSetup_ = nullptr;
    }
    if (carrierFftSetup_) {
        vDSP_destroy_fftsetup(carrierFftSetup_);
        carrierFftSetup_ = nullptr;
    }
}

void BinduDSP::init(float sampleRate) {
    sampleRate_ = sampleRate;

    // Allocate FFT setups (NOT in processBlock — this is the init path)
    fftSetup_ = vDSP_create_fftsetup(BinduConstants::FFT_LOG2, kFFTRadix2);
    carrierFftSetup_ = vDSP_create_fftsetup(BinduConstants::CARRIER_FFT_LOG2, kFFTRadix2);

    // Precompute Hann window (1024-pt)
    vDSP_hann_window(hannWindow_, BinduConstants::FFT_SIZE, vDSP_HANN_NORM);

    // Precompute Hann window (4096-pt) for carrier derivation
    vDSP_hann_window(carrierHannWindow_, BinduConstants::CARRIER_FFT_SIZE, vDSP_HANN_NORM);

    // Precompute bin frequency table
    const float binHz = sampleRate_ / (float)BinduConstants::FFT_SIZE;
    for (int k = 0; k < BinduConstants::SPECTRUM_BINS; ++k) {
        binFrequencies_[k] = (float)k * binHz;
    }

    // Onset cooldown: ONSET_MIN_IOI_SEC / (HOP_SIZE / sampleRate)
    const float hopSec = (float)BinduConstants::HOP_SIZE / sampleRate_;
    onsetCooldownReset_ = (int)(BinduConstants::ONSET_MIN_IOI_SEC / hopSec + 0.5f);
    if (onsetCooldownReset_ < 1) onsetCooldownReset_ = 1;

    initialized_ = true;
}

void BinduDSP::reset() {
    accumWritePos_ = 0;
    prevMagsWriteIdx_ = 0;
    fluxHistoryWriteIdx_ = 0;
    fluxHistoryCount_ = 0;
    onsetCooldownFrames_ = 0;
    rmsRollingMax_ = 0.001f;
    carrierAccumWritePos_ = 0;
    carrierFramesAccumulated_ = 0;
    framesProduced_.store(0);

    std::memset(accumBuffer_, 0, sizeof(accumBuffer_));
    std::memset(prevMags_, 0, sizeof(prevMags_));
    std::memset(fluxHistory_, 0, sizeof(fluxHistory_));
    std::memset(carrierAccumBuffer_, 0, sizeof(carrierAccumBuffer_));
    std::memset(carrierAvgSpectrum_, 0, sizeof(carrierAvgSpectrum_));

    ringBuffer_.clear();
}

// ============================================================================
//  BinduDSP — processBlock (REAL-TIME HOT PATH)
// ============================================================================
//  Called from audio tap thread. No allocation, no locks, no syscalls.
//  Accumulates incoming samples into two windows simultaneously:
//    - 1024-pt analysis window with 512-pt hop (50% overlap)
//    - 4096-pt carrier window, sequential (no hop) for slow accumulation
// ============================================================================

void BinduDSP::processBlock(const float* samples, int count, double hostTime) {
    if (!initialized_ || samples == nullptr || count <= 0) return;

    // Estimate timestamp for the START of the first emitted frame.
    // Each emitted frame corresponds to a 1024-sample window.
    // We approximate timestamp linearly across the input block.
    const double secPerSample = 1.0 / (double)sampleRate_;

    int inputPos = 0;
    while (inputPos < count) {
        // === Accumulate into 1024-pt analysis buffer ===
        const int spaceInAnalysis = BinduConstants::FFT_SIZE - accumWritePos_;
        const int spaceInCarrier  = BinduConstants::CARRIER_FFT_SIZE - carrierAccumWritePos_;
        const int remaining       = count - inputPos;

        const int copyAmount = std::min({spaceInAnalysis, spaceInCarrier, remaining});

        std::memcpy(accumBuffer_ + accumWritePos_,
                    samples + inputPos,
                    copyAmount * sizeof(float));

        std::memcpy(carrierAccumBuffer_ + carrierAccumWritePos_,
                    samples + inputPos,
                    copyAmount * sizeof(float));

        accumWritePos_        += copyAmount;
        carrierAccumWritePos_ += copyAmount;
        inputPos              += copyAmount;

        // === If analysis window full: analyze, then shift by HOP_SIZE ===
        if (accumWritePos_ >= BinduConstants::FFT_SIZE) {
            // Compute timestamp for THIS window's center
            const double windowCenterOffset = (BinduConstants::FFT_SIZE / 2) * secPerSample;
            const double windowStartTime = hostTime + (inputPos - copyAmount) * secPerSample;
            const double frameTime = windowStartTime + windowCenterOffset;

            analyzeWindow_(frameTime);

            // Shift accumBuffer left by HOP_SIZE — keep last (FFT_SIZE - HOP_SIZE) samples
            const int retain = BinduConstants::FFT_SIZE - BinduConstants::HOP_SIZE;
            std::memmove(accumBuffer_,
                         accumBuffer_ + BinduConstants::HOP_SIZE,
                         retain * sizeof(float));
            accumWritePos_ = retain;
        }

        // === If carrier window full: run carrier FFT, accumulate into average ===
        if (carrierAccumWritePos_ >= BinduConstants::CARRIER_FFT_SIZE) {
            runCarrierFFT_();
            carrierAccumWritePos_ = 0;  // sequential — no overlap
        }
    }
}

// ============================================================================
//  BinduDSP::analyzeWindow_ — Per-frame FFT + features
// ============================================================================

void BinduDSP::analyzeWindow_(double timestamp) {
    constexpr int N = BinduConstants::FFT_SIZE;
    constexpr int BINS = BinduConstants::SPECTRUM_BINS;

    // 1. Window: windowedBuffer_ = accumBuffer_ * hannWindow_
    vDSP_vmul(accumBuffer_, 1, hannWindow_, 1, windowedBuffer_, 1, N);

    // 2. Pack real signal into split-complex form for vDSP_fft_zrip
    //    vDSP packs real input as even/odd interleaved into real/imag halves
    vDSP_ctoz((DSPComplex*)windowedBuffer_, 2, &splitComplex_, 1, BINS);

    // 3. Forward FFT in-place
    vDSP_fft_zrip(fftSetup_, &splitComplex_, 1, BinduConstants::FFT_LOG2, FFT_FORWARD);

    // 4. Magnitude squared, then sqrt
    //    vDSP_zvmags computes |z|^2 = real^2 + imag^2
    vDSP_zvmags(&splitComplex_, 1, magnitudes_, 1, BINS);

    //    Apply scaling: vDSP packs Nyquist into imag[0]; standard correction
    //    For our purposes (relative magnitudes, normalized to peak), exact scaling
    //    not critical — we work with relative spectrum shape.
    int bins_int = BINS;
    vvsqrtf(magnitudes_, magnitudes_, &bins_int);

    // 5. Normalize to frame peak
    float peak = 0.0f;
    vDSP_maxv(magnitudes_, 1, &peak, BINS);
    if (peak > 1e-6f) {
        float invPeak = 1.0f / peak;
        vDSP_vsmul(magnitudes_, 1, &invPeak, normalizedMags_, 1, BINS);
    } else {
        std::memset(normalizedMags_, 0, sizeof(normalizedMags_));
    }

    // 6. RMS — computed from the WINDOWED buffer (consistent with spectral energy)
    //    Alternative: compute from accumBuffer_ directly (pre-window). For breath
    //    modulation, windowed RMS is preferable — matches what's spectrally analyzed.
    float rmsRaw = 0.0f;
    vDSP_rmsqv(accumBuffer_, 1, &rmsRaw, N);  // raw signal, not windowed

    // Update rolling max with slow decay
    rmsRollingMax_ *= RMS_DECAY;
    if (rmsRaw > rmsRollingMax_) rmsRollingMax_ = rmsRaw;

    const float rmsNorm = (rmsRollingMax_ > 1e-6f) ? (rmsRaw / rmsRollingMax_) : 0.0f;
    const float rmsClamped = std::min(1.0f, std::max(0.0f, rmsNorm));

    // 7. Spectral centroid: Σ(mag * freq) / Σ(mag)
    float weightedSum = 0.0f;
    float magSum = 0.0f;
    vDSP_dotpr(normalizedMags_, 1, binFrequencies_, 1, &weightedSum, BINS);
    vDSP_sve(normalizedMags_, 1, &magSum, BINS);

    float centroidHz = (magSum > 1e-6f) ? (weightedSum / magSum) : 0.0f;
    const float nyquist = sampleRate_ * 0.5f;
    const float centroidNorm = std::min(1.0f, centroidHz / nyquist);

    // 8. SuperFlux spectral flux
    //    Max-filter across MAX_FILTER_FRAMES previous magnitude spectra per bin,
    //    then half-wave rectified difference from current.
    float fluxSum = 0.0f;
    {
        // For each bin: maxRef = max over previous 3 frames
        // diff = max(0, current - maxRef)
        // fluxSum = Σ diff
        for (int k = 0; k < BINS; ++k) {
            float maxRef = 0.0f;
            for (int p = 0; p < BinduConstants::MAX_FILTER_FRAMES; ++p) {
                if (prevMags_[p][k] > maxRef) maxRef = prevMags_[p][k];
            }
            const float d = normalizedMags_[k] - maxRef;
            if (d > 0.0f) fluxSum += d;
        }
    }
    // Normalize flux: divide by BINS so it sits in roughly [0, 1] range
    // (typical values << 1; we'll renormalize against history)
    const float fluxRaw = fluxSum / (float)BINS;

    // Push current spectrum into prevMags ring
    pushPrevMags_(normalizedMags_);

    // 9. SuperFlux onset detection (adaptive threshold + cooldown)
    bool onsetFlag = false;
    float onsetStrength = 0.0f;
    superFluxOnset_(fluxRaw, onsetFlag, onsetStrength);

    // Update flux history (for adaptive threshold next call)
    fluxHistory_[fluxHistoryWriteIdx_] = fluxRaw;
    fluxHistoryWriteIdx_ = (fluxHistoryWriteIdx_ + 1) % BinduConstants::FLUX_HISTORY_SIZE;
    if (fluxHistoryCount_ < BinduConstants::FLUX_HISTORY_SIZE) ++fluxHistoryCount_;

    // 10. Assemble and push BinduFrame
    BinduFrame frame;
    frame.timestamp     = timestamp;
    frame.rms           = rmsClamped;
    frame.rmsRaw        = rmsRaw;
    frame.centroid      = centroidNorm;
    frame.flux          = std::min(1.0f, fluxRaw * 10.0f);  // visual scaling
    frame.onsetFlag     = onsetFlag;
    frame.onsetStrength = onsetStrength;
    std::memcpy(frame.magnitudeSpectrum, normalizedMags_,
                sizeof(float) * BINS);

    ringBuffer_.push(frame);
    framesProduced_.fetch_add(1, std::memory_order_relaxed);
}

// ============================================================================
//  BinduDSP::superFluxOnset_ — Adaptive threshold + minimum IOI
// ============================================================================

void BinduDSP::superFluxOnset_(float flux, bool& outFlag, float& outStrength) {
    // Decrement cooldown
    if (onsetCooldownFrames_ > 0) {
        --onsetCooldownFrames_;
        outFlag = false;
        outStrength = 0.0f;
        return;
    }

    // Need history before any detection
    if (fluxHistoryCount_ < 10) {
        outFlag = false;
        outStrength = 0.0f;
        return;
    }

    const float threshold = computeAdaptiveThreshold_();

    if (flux > threshold) {
        outFlag = true;
        // Strength: 0 at threshold, 1 at 2x threshold, clamped
        outStrength = std::min(1.0f, (flux / threshold) - 1.0f);
        onsetCooldownFrames_ = onsetCooldownReset_;
    } else {
        outFlag = false;
        outStrength = 0.0f;
    }
}

// ============================================================================
//  BinduDSP::computeAdaptiveThreshold_
// ============================================================================
//  Adaptive: 0.5 × median(fluxHistory) + FLUX_THRESHOLD_FLOOR
//  For real-time, use partial sort via nth_element on stack copy.
// ============================================================================

float BinduDSP::computeAdaptiveThreshold_() const {
    const int count = fluxHistoryCount_;
    if (count == 0) return BinduConstants::FLUX_THRESHOLD_FLOOR;

    // Stack copy — bounded size, no allocation
    float copy[BinduConstants::FLUX_HISTORY_SIZE];
    std::memcpy(copy, fluxHistory_, count * sizeof(float));

    const int mid = count / 2;
    std::nth_element(copy, copy + mid, copy + count);
    const float median = copy[mid];

    return BinduConstants::FLUX_THRESHOLD_SCALE * median +
           BinduConstants::FLUX_THRESHOLD_FLOOR;
}

void BinduDSP::pushPrevMags_(const float* mags) {
    std::memcpy(prevMags_[prevMagsWriteIdx_], mags,
                sizeof(float) * BinduConstants::SPECTRUM_BINS);
    prevMagsWriteIdx_ = (prevMagsWriteIdx_ + 1) % BinduConstants::MAX_FILTER_FRAMES;
}

float BinduDSP::computeRMS_(const float* samples, int count) const {
    float rms = 0.0f;
    vDSP_rmsqv(samples, 1, &rms, count);
    return rms;
}

// ============================================================================
//  BinduDSP::runCarrierFFT_ — 4096-pt spectrum accumulation
// ============================================================================
//  Called once per 4096 samples accumulated. Windows, FFTs, magnitude,
//  and accumulates running average for later deriveCarrier() call.
// ============================================================================

void BinduDSP::runCarrierFFT_() {
    constexpr int N = BinduConstants::CARRIER_FFT_SIZE;
    constexpr int BINS = BinduConstants::CARRIER_BINS;

    // Stack-allocated working buffers — large but safe
    // (4096 floats = 16 KB stack — well under typical limits)
    float windowed[N];
    float realBuf[BINS];
    float imagBuf[BINS];
    float mags[BINS];

    vDSP_vmul(carrierAccumBuffer_, 1, carrierHannWindow_, 1, windowed, 1, N);

    DSPSplitComplex split;
    split.realp = realBuf;
    split.imagp = imagBuf;

    vDSP_ctoz((DSPComplex*)windowed, 2, &split, 1, BINS);
    vDSP_fft_zrip(carrierFftSetup_, &split, 1, BinduConstants::CARRIER_FFT_LOG2, FFT_FORWARD);
    vDSP_zvmags(&split, 1, mags, 1, BINS);

    int bins_int = BINS;
    vvsqrtf(mags, mags, &bins_int);

    // Normalize to peak before accumulation (each contribution weighted equally)
    float peak = 0.0f;
    vDSP_maxv(mags, 1, &peak, BINS);
    if (peak > 1e-6f) {
        float invPeak = 1.0f / peak;
        vDSP_vsmul(mags, 1, &invPeak, mags, 1, BINS);
    }

    // Running average: avg[k] = ((n * avg[k]) + mags[k]) / (n + 1)
    const float n = (float)carrierFramesAccumulated_;
    const float scale = n / (n + 1.0f);
    const float weight = 1.0f / (n + 1.0f);

    vDSP_vsmul(carrierAvgSpectrum_, 1, &scale, carrierAvgSpectrum_, 1, BINS);
    vDSP_vsma(mags, 1, &weight, carrierAvgSpectrum_, 1, carrierAvgSpectrum_, 1, BINS);

    ++carrierFramesAccumulated_;
}

// ============================================================================
//  BinduDSP::deriveCarrier — Harmonic salience candidate scan
// ============================================================================
//  Called ~10s after session start. Scans 80–200 Hz for the candidate f0
//  whose implied harmonic stack is strongly present but whose fundamental
//  is weakly present — the "absent sub-harmonic."
//
//  Score(f0) = Σ_{h=2..8} mag(h*f0) / h  ×  (1 - tanh(mag(f0) / 0.3))
// ============================================================================

CarrierProfile BinduDSP::deriveCarrier() {
    CarrierProfile result;
    result.carrierHz = BinduConstants::CARRIER_FALLBACK_HZ;
    result.salienceScore = 0.0f;
    result.derivedFromAudio = false;

    if (carrierFramesAccumulated_ < 1) {
        // No carrier accumulator data — return fallback
        return result;
    }

    const float binHz = sampleRate_ / (float)BinduConstants::CARRIER_FFT_SIZE;
    const int   bins  = BinduConstants::CARRIER_BINS;

    float bestScore = 0.0f;
    float bestF0 = BinduConstants::CARRIER_FALLBACK_HZ;
    float scoreSum = 0.0f;
    int   scoreCount = 0;

    // Scan candidates from 80 Hz to 200 Hz at 1 Hz steps
    for (int f0_int = (int)BinduConstants::CARRIER_MIN_HZ;
         f0_int <= (int)BinduConstants::CARRIER_MAX_HZ;
         ++f0_int) {
        const float f0 = (float)f0_int;

        // Harmonic implication: weighted sum over harmonics 2..8
        float implication = 0.0f;
        for (int h = 2; h <= 8; ++h) {
            const float fh = f0 * (float)h;
            if (fh >= sampleRate_ * 0.5f) break;  // beyond Nyquist
            const float fractionalBin = fh / binHz;
            const float mag = interpolateMagnitude_(carrierAvgSpectrum_,
                                                    fractionalBin, bins);
            implication += mag / (float)h;
        }

        // Fundamental presence at f0 itself
        const float f0Bin = f0 / binHz;
        const float presence = interpolateMagnitude_(carrierAvgSpectrum_, f0Bin, bins);

        // Score: high implication, low presence
        // tanh(p / 0.3) maps presence to [0, ~1) smoothly
        const float presenceFactor = 1.0f - std::tanh(presence / 0.3f);
        const float score = implication * presenceFactor;

        scoreSum += score;
        ++scoreCount;

        if (score > bestScore) {
            bestScore = score;
            bestF0 = f0;
        }
    }

    // Salience: best score / mean score (signal-to-noise)
    const float meanScore = (scoreCount > 0) ? (scoreSum / (float)scoreCount) : 1e-6f;
    const float salience = (meanScore > 1e-6f) ? (bestScore / meanScore) : 0.0f;

    if (salience >= BinduConstants::CARRIER_SALIENCE_THRESHOLD && bestScore > 0.05f) {
        result.carrierHz = bestF0;
        result.salienceScore = salience;
        result.derivedFromAudio = true;
    } else {
        // Fallback to OM frequency
        result.carrierHz = BinduConstants::CARRIER_FALLBACK_HZ;
        result.salienceScore = salience;
        result.derivedFromAudio = false;
    }

    return result;
}

float BinduDSP::interpolateMagnitude_(const float* spectrum,
                                      float fractionalBin,
                                      int binCount) const {
    if (fractionalBin < 0.0f) return spectrum[0];
    if (fractionalBin >= (float)(binCount - 1)) return spectrum[binCount - 1];

    const int lo = (int)fractionalBin;
    const int hi = lo + 1;
    const float frac = fractionalBin - (float)lo;

    return spectrum[lo] * (1.0f - frac) + spectrum[hi] * frac;
}

// ============================================================================
//  BinduDSP::readLatestFrame — Consumer side, JS bridge thread
// ============================================================================

bool BinduDSP::readLatestFrame(BinduFrame& out) {
    return ringBuffer_.peekLatest(out);
}

} // namespace ASG
