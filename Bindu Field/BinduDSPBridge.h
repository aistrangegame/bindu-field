//
//  BinduDSPBridge.h
//  ASG / Bindu Field
//
//  ObjC++ wrapper around the C++ BinduDSP kernel.
//  Provides Swift-compatible interface via Objective-C class.
//
//  This file is .h — public header.
//  Implementation lives in BinduDSPBridge.mm (ObjC++ — note the .mm extension).
//
//  Why this layer exists:
//    - Swift cannot directly call C++ classes
//    - ObjC++ (.mm files) can mix Objective-C and C++
//    - This bridge exposes a pure ObjC interface that Swift consumes naturally
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BinduDSPBridge : NSObject

/// Initialize the DSP kernel with the given sample rate.
/// Allocates FFT setups and analysis buffers. Not real-time safe.
- (void)initializeWithSampleRate:(float)sampleRate;

/// Process a block of mono PCM samples. Real-time safe.
/// Called from the AVAudioEngine tap callback thread.
///
/// @param samples Pointer to mono float PCM data
/// @param count Number of samples in the block
/// @param hostTime Timestamp for the start of this block, in seconds
- (void)processBlockWithSamples:(const float *)samples
                          count:(int32_t)count
                       hostTime:(double)hostTime;

/// Read the most recent BinduFrame from the DSP ring buffer.
/// Returns a dictionary representation, or nil if no frame available.
///
/// Dictionary keys:
///   - "timestamp"     : NSNumber (double) — host time in seconds
///   - "rms"           : NSNumber (float)  — normalized RMS, 0–1
///   - "rmsRaw"        : NSNumber (float)  — raw RMS, unnormalized
///   - "centroid"      : NSNumber (float)  — spectral centroid / Nyquist, 0–1
///   - "flux"          : NSNumber (float)  — normalized spectral flux, 0–1
///   - "onsetFlag"     : NSNumber (bool)   — onset detected this frame
///   - "onsetStrength" : NSNumber (float)  — onset prominence, 0–1
///
/// Note: magnitudeSpectrum is NOT marshalled by default — it's 512 floats
/// per frame and would dominate the bridge cost. Use spectrumSnapshot for
/// occasional spectrum reads.
- (nullable NSDictionary<NSString *, id> *)readLatestFrame;

/// Get a one-shot snapshot of the current magnitude spectrum.
/// Heavier than readLatestFrame — only call when needed (e.g., visualization).
///
/// @return Array of 512 NSNumber floats, or nil if no frame available.
- (nullable NSArray<NSNumber *> *)spectrumSnapshot;

/// Derive the session carrier frequency from accumulated spectrum.
/// Call once, after ~10 seconds of playback. Not real-time safe.
///
/// Dictionary keys:
///   - "carrierHz"        : NSNumber (float)
///   - "salienceScore"    : NSNumber (float)
///   - "derivedFromAudio" : NSNumber (bool)
- (NSDictionary<NSString *, id> *)deriveCarrier;

/// Reset DSP state for a new session.
- (void)reset;

/// Diagnostic: count of frames produced since last reset.
- (int32_t)framesProduced;

@end

NS_ASSUME_NONNULL_END
