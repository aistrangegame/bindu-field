//
//  BinduDSP.h
//  ASG / Bindu Field
//
//  Real-time audio feature extraction kernel.
//  Consumes PCM float audio, produces BinduFrame features via lock-free ring buffer.
//  Derives session carrier frequency via 4096-pt harmonic salience pass.
//
//  Threading contract:
//    - processBlock()      : called from audio tap thread (background serial)
//    - readFrame()         : called from any thread (typically JS bridge thread)
//    - deriveCarrier()     : called once, ~10s after session start
//    - reset() / init()    : called from main thread only, not during playback
//
//  Real-time safety:
//    - processBlock() performs no allocation, no locks, no syscalls
//    - All buffers allocated in init()
//    - Ring buffer uses std::atomic for SPSC lock-free access
//

#ifndef BinduDSP_h
#define BinduDSP_h

#ifdef __cplusplus

#include <atomic>
#include <cstdint>
#include <Accelerate/Accelerate.h>

namespace ASG {

// ============================================================================
//  CONSTANTS
// ============================================================================

struct BinduConstants {
    static constexpr int   FFT_SIZE          = 1024;
    static constexpr int   FFT_LOG2          = 10;       // log2(1024)
    static constexpr int   HOP_SIZE          = 512;
    static constexpr int   SPECTRUM_BINS     = FFT_SIZE / 2;  // 512

    static constexpr int   CARRIER_FFT_SIZE  = 4096;
    static constexpr int   CARRIER_FFT_LOG2  = 12;       // log2(4096)
    static constexpr int   CARRIER_BINS      = CARRIER_FFT_SIZE / 2;  // 2048

    static constexpr int   RING_CAPACITY     = 64;
    static constexpr int   FLUX_HISTORY_SIZE = 100;      // ~2.1s @ 47fps
    static constexpr int   MAX_FILTER_FRAMES = 3;        // SuperFlux trajectory

    static constexpr float CARRIER_MIN_HZ    = 80.0f;
    static constexpr float CARRIER_MAX_HZ    = 200.0f;
    static constexpr float CARRIER_FALLBACK_HZ = 136.1f;
    static constexpr float CARRIER_SALIENCE_THRESHOLD = 1.5f;

    static constexpr float FLUX_THRESHOLD_FLOOR   = 0.08f;
    static constexpr float FLUX_THRESHOLD_SCALE   = 0.5f;
    static constexpr float ONSET_MIN_IOI_SEC      = 0.10f;
};

// ============================================================================
//  DATA STRUCTURES
// ============================================================================

// One frame of analysis output. POD type — safe for memcpy, ring buffer.
struct BinduFrame {
    double  timestamp;          // host time in seconds
    float   rms;                // 0–1, normalized to session-rolling max
    float   rmsRaw;             // raw RMS before normalization
    float   centroid;           // 0–1, spectral centroid / Nyquist
    float   flux;               // 0–1, normalized spectral flux
    bool    onsetFlag;          // SuperFlux onset this frame
    float   onsetStrength;      // 0–1, onset prominence above threshold
    float   magnitudeSpectrum[BinduConstants::SPECTRUM_BINS];
                                // half-spectrum magnitudes, normalized to frame peak
                                // bin k -> freq = k * (sampleRate / FFT_SIZE)
};

// Result of session-start carrier derivation.
struct CarrierProfile {
    float   carrierHz;          // derived carrier in [80, 200] Hz
    float   salienceScore;      // SNR of best candidate (>1.5 = high confidence)
    bool    derivedFromAudio;   // false = fallback to 136.1 Hz
};

// ============================================================================
//  RING BUFFER (Lock-Free SPSC)
// ============================================================================

// Single-producer single-consumer ring buffer for BinduFrame.
// Producer: audio tap thread (processBlock)
// Consumer: JS bridge thread (readFrame)
// Capacity is fixed at compile time. Power of 2 for fast modulo.
class FrameRingBuffer {
public:
    FrameRingBuffer();

    // Producer side — non-blocking. Drops frame if full (acceptable rarity).
    // Returns true if pushed, false if dropped.
    bool push(const BinduFrame& frame);

    // Consumer side — non-blocking. Returns true if frame retrieved.
    bool pop(BinduFrame& out);

    // Returns most recent frame without removing. Used for "latest" reads.
    // Returns true if any frame exists.
    bool peekLatest(BinduFrame& out);

    void clear();

private:
    static constexpr int CAPACITY = BinduConstants::RING_CAPACITY;
    BinduFrame buffer_[CAPACITY];
    std::atomic<uint32_t> writeIdx_{0};
    std::atomic<uint32_t> readIdx_{0};
};

// ============================================================================
//  DSP KERNEL
// ============================================================================

class BinduDSP {
public:
    BinduDSP();
    ~BinduDSP();

    // Configure for a given sample rate. Allocates all internal buffers.
    // MUST be called before processBlock(). Not real-time safe.
    void init(float sampleRate);

    // Real-time entry point. Called from audio tap thread.
    // samples : mono float PCM (downmix in Swift wrapper before calling)
    // count   : number of samples in this block
    // hostTime: timestamp for the START of this block, in seconds
    //
    // Performs:
    //   1. Accumulate into 1024-sample window with 512-sample hop
    //   2. For each complete window: FFT, features, SuperFlux onset
    //   3. Also accumulate into 4096-sample carrier window (separate, no hop)
    //   4. Push completed BinduFrame to ring buffer
    void processBlock(const float* samples, int count, double hostTime);

    // Read most recent frame. Non-blocking. Thread-safe.
    bool readLatestFrame(BinduFrame& out);

    // Derive carrier from accumulated spectrum. Call once, ~10s after start.
    // Not real-time safe — performs the full 4096-pt FFT and candidate scan.
    CarrierProfile deriveCarrier();

    // Reset state for new session. Not real-time safe.
    void reset();

    // Diagnostics
    bool isInitialized() const { return initialized_; }
    int  framesProduced() const { return framesProduced_.load(); }

private:
    // === Configuration ===
    float        sampleRate_;
    bool         initialized_;
    std::atomic<int> framesProduced_;

    // === FFT setup (vDSP) ===
    FFTSetup     fftSetup_;             // 1024-pt
    FFTSetup     carrierFftSetup_;      // 4096-pt

    // === Real-time analysis buffers ===
    // Accumulator: incoming samples land here, analyzed when 1024 collected.
    float        accumBuffer_[BinduConstants::FFT_SIZE];
    int          accumWritePos_;        // next write position in accumBuffer

    // Hann window (precomputed in init)
    float        hannWindow_[BinduConstants::FFT_SIZE];

    // Windowed input ready for FFT
    float        windowedBuffer_[BinduConstants::FFT_SIZE];

    // FFT working storage (split complex form)
    DSPSplitComplex splitComplex_;
    float        fftRealBuffer_[BinduConstants::SPECTRUM_BINS];
    float        fftImagBuffer_[BinduConstants::SPECTRUM_BINS];

    // Per-frame magnitude spectrum
    float        magnitudes_[BinduConstants::SPECTRUM_BINS];
    float        normalizedMags_[BinduConstants::SPECTRUM_BINS];

    // SuperFlux: ring buffer of last 3 normalized magnitude spectra
    float        prevMags_[BinduConstants::MAX_FILTER_FRAMES][BinduConstants::SPECTRUM_BINS];
    int          prevMagsWriteIdx_;     // next slot to overwrite

    // Bin frequency table (precomputed: bin k -> k * sampleRate / FFT_SIZE)
    float        binFrequencies_[BinduConstants::SPECTRUM_BINS];

    // === Flux history for adaptive threshold ===
    float        fluxHistory_[BinduConstants::FLUX_HISTORY_SIZE];
    int          fluxHistoryWriteIdx_;
    int          fluxHistoryCount_;     // saturates at FLUX_HISTORY_SIZE

    // === Onset cooldown ===
    int          onsetCooldownFrames_;
    int          onsetCooldownReset_;   // computed from ONSET_MIN_IOI_SEC + hop rate

    // === RMS normalization ===
    float        rmsRollingMax_;        // tracks session-rolling RMS max
    static constexpr float RMS_DECAY = 0.9999f;  // slow decay so old maxes fade

    // === Carrier derivation accumulator (4096-pt) ===
    float        carrierAccumBuffer_[BinduConstants::CARRIER_FFT_SIZE];
    int          carrierAccumWritePos_;
    float        carrierAvgSpectrum_[BinduConstants::CARRIER_BINS];
    int          carrierFramesAccumulated_;
    float        carrierHannWindow_[BinduConstants::CARRIER_FFT_SIZE];

    // === Output ===
    FrameRingBuffer ringBuffer_;

    // === Internal methods (all real-time safe) ===
    void analyzeWindow_(double timestamp);
    void runCarrierFFT_();
    float computeRMS_(const float* samples, int count) const;
    float computeAdaptiveThreshold_() const;
    void  superFluxOnset_(float flux, bool& outFlag, float& outStrength);
    void  pushPrevMags_(const float* mags);
    float interpolateMagnitude_(const float* spectrum, float fractionalBin, int binCount) const;
};

} // namespace ASG

#endif // __cplusplus
#endif // BinduDSP_h
