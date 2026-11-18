#pragma once
#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioToolbox.h>
#include "AudioEngine.hpp"
#include <memory>

@interface CoreAudioHALManager : NSObject

@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, assign) float sampleRate;
@property (nonatomic, assign) std::shared_ptr<OnLive::DSP::AudioEngine> audioEngine;

- (instancetype)initWithAudioEngine:(std::shared_ptr<OnLive::DSP::AudioEngine>)engine;
- (BOOL)start;
- (void)stop;

- (float)getVocalMeterDb;
- (float)getMusicMeterDb;
- (float)getMasterMeterDb;

@end
