//
//  BinduDSPBridge.mm
//  ASG / Bindu Field
//
//  ObjC++ implementation bridging Swift to the C++ BinduDSP kernel.
//  Note the .mm extension — required for mixed Objective-C / C++ compilation.
//

#import "BinduDSPBridge.h"
#import "BinduDSP.h"

#include <memory>

@implementation BinduDSPBridge {
    std::unique_ptr<ASG::BinduDSP> _dsp;
}

// MARK: - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _dsp = std::make_unique<ASG::BinduDSP>();
    }
    return self;
}

- (void)dealloc {
    // _dsp unique_ptr cleans up automatically
    // BinduDSP destructor releases vDSP FFT setups
}

// MARK: - Initialization

- (void)initializeWithSampleRate:(float)sampleRate {
    if (_dsp) {
        _dsp->init(sampleRate);
    }
}

// MARK: - Real-time processing

- (void)processBlockWithSamples:(const float *)samples
                          count:(int32_t)count
                       hostTime:(double)hostTime {
    if (_dsp && samples != nullptr && count > 0) {
        _dsp->processBlock(samples, (int)count, hostTime);
    }
}

// MARK: - Frame retrieval

- (nullable NSDictionary<NSString *, id> *)readLatestFrame {
    if (!_dsp) return nil;

    ASG::BinduFrame frame;
    if (!_dsp->readLatestFrame(frame)) {
        return nil;
    }

    // Marshal frame into NSDictionary.
    // We DO NOT include magnitudeSpectrum here — 512 NSNumbers per poll
    // would dominate bridge cost. Use spectrumSnapshot for that.
    return @{
        @"timestamp":     @(frame.timestamp),
        @"rms":           @(frame.rms),
        @"rmsRaw":        @(frame.rmsRaw),
        @"centroid":      @(frame.centroid),
        @"flux":          @(frame.flux),
        @"onsetFlag":     @(frame.onsetFlag),
        @"onsetStrength": @(frame.onsetStrength)
    };
}

- (nullable NSArray<NSNumber *> *)spectrumSnapshot {
    if (!_dsp) return nil;

    ASG::BinduFrame frame;
    if (!_dsp->readLatestFrame(frame)) {
        return nil;
    }

    NSMutableArray<NSNumber *> *spectrum =
        [NSMutableArray arrayWithCapacity:ASG::BinduConstants::SPECTRUM_BINS];

    for (int i = 0; i < ASG::BinduConstants::SPECTRUM_BINS; ++i) {
        [spectrum addObject:@(frame.magnitudeSpectrum[i])];
    }

    return spectrum;
}

// MARK: - Carrier derivation

- (NSDictionary<NSString *, id> *)deriveCarrier {
    if (!_dsp) {
        return @{
            @"carrierHz":        @(136.1f),
            @"salienceScore":    @(0.0f),
            @"derivedFromAudio": @(NO)
        };
    }

    ASG::CarrierProfile profile = _dsp->deriveCarrier();

    return @{
        @"carrierHz":        @(profile.carrierHz),
        @"salienceScore":    @(profile.salienceScore),
        @"derivedFromAudio": @(profile.derivedFromAudio)
    };
}

// MARK: - State management

- (void)reset {
    if (_dsp) {
        _dsp->reset();
    }
}

- (int32_t)framesProduced {
    return _dsp ? (int32_t)_dsp->framesProduced() : 0;
}

@end
