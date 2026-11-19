#pragma once
#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#include "AudioEngine.hpp"
#include <memory>

@interface AudioHardwareDevice : NSObject
@property (nonatomic, assign) AudioDeviceID deviceID;
@property (nonatomic, copy) NSString* name;
@property (nonatomic, assign) int inputChannels;
@property (nonatomic, assign) int outputChannels;
@property (nonatomic, assign) BOOL isInput;
@property (nonatomic, assign) BOOL isOutput;
@end

@interface CoreAudioHALManager : NSObject

@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, assign) float sampleRate;
@property (nonatomic, assign) std::shared_ptr<OnLive::DSP::AudioEngine> audioEngine;
@property (nonatomic, assign) BOOL testToneEnabled;
@property (nonatomic, assign) BOOL isMusicPlaying;
@property (nonatomic, assign) float musicPeakLevel;
@property (nonatomic, copy) NSString* activeInputDeviceName;
@property (nonatomic, copy) NSString* activeOutputDeviceName;

- (instancetype)initWithAudioEngine:(std::shared_ptr<OnLive::DSP::AudioEngine>)engine;
- (BOOL)start;
- (void)stop;

+ (void)requestMicrophonePermission:(void (^)(BOOL granted))completion;
+ (NSArray<AudioHardwareDevice*>*)scanAvailableDevices;
+ (NSArray<NSString*>*)getAvailableInputNames;
+ (NSArray<NSString*>*)getAvailableOutputNames;

- (void)selectInputDeviceByName:(NSString*)name;
- (void)selectOutputDeviceByName:(NSString*)name;
- (void)toggleTestTone;

- (float)getVocalMeterDb;
- (float)getMusicMeterDb;
- (float)getMasterMeterDb;

@end
