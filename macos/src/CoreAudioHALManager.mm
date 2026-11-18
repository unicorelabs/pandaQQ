#import "CoreAudioHALManager.h"
#include <vector>
#include <algorithm>

static OSStatus audioOutputCallback(void* inRefCon,
                                   [[maybe_unused]] AudioUnitRenderActionFlags* ioActionFlags,
                                   [[maybe_unused]] const AudioTimeStamp* inTimeStamp,
                                   [[maybe_unused]] UInt32 inBusNumber,
                                   UInt32 inNumberFrames,
                                   AudioBufferList* ioData) {
    CoreAudioHALManager* manager = (__bridge CoreAudioHALManager*)inRefCon;
    if (!manager) return noErr;

    float* outL = (float*)ioData->mBuffers[0].mData;
    float* outR = (ioData->mNumberBuffers > 1) ? (float*)ioData->mBuffers[1].mData : outL;

    static std::vector<float> micDummy(1024, 0.0f);
    static std::vector<float> musicDummyL(1024, 0.0f);
    static std::vector<float> musicDummyR(1024, 0.0f);
    static std::vector<float> broadcastDummyL(1024, 0.0f);
    static std::vector<float> broadcastDummyR(1024, 0.0f);
    static std::vector<float> monitorDummyL(1024, 0.0f);
    static std::vector<float> monitorDummyR(1024, 0.0f);

    const UInt32 frames = std::min(inNumberFrames, (UInt32)1024);

    auto engine = manager.audioEngine;
    if (engine) {
        engine->processAudio(micDummy.data(),
                            musicDummyL.data(), musicDummyR.data(),
                            broadcastDummyL.data(), broadcastDummyR.data(),
                            monitorDummyL.data(), monitorDummyR.data(),
                            frames);

        for (UInt32 i = 0; i < inNumberFrames; ++i) {
            float sL = (i < frames) ? monitorDummyL[i] : 0.0f;
            float sR = (i < frames) ? monitorDummyR[i] : 0.0f;
            outL[i] = sL;
            if (ioData->mNumberBuffers > 1) {
                outR[i] = sR;
            }
        }
    } else {
        for (UInt32 c = 0; c < ioData->mNumberBuffers; ++c) {
            memset(ioData->mBuffers[c].mData, 0, ioData->mBuffers[c].mDataByteSize);
        }
    }

    return noErr;
}

@implementation AudioHardwareDevice
@end

@implementation CoreAudioHALManager {
    AudioComponentInstance _outputUnit;
}

+ (NSArray<AudioHardwareDevice*>*)scanAvailableDevices {
    NSMutableArray<AudioHardwareDevice*>* list = [NSMutableArray array];
    AudioObjectPropertyAddress addr = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };

    UInt32 dataSize = 0;
    OSStatus status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &addr, 0, NULL, &dataSize);
    if (status != noErr || dataSize == 0) return list;

    UInt32 deviceCount = dataSize / sizeof(AudioDeviceID);
    std::vector<AudioDeviceID> deviceIDs(deviceCount);
    status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &dataSize, deviceIDs.data());
    if (status != noErr) return list;

    for (AudioDeviceID devID : deviceIDs) {
        CFStringRef cfName = NULL;
        UInt32 nameSize = sizeof(CFStringRef);
        AudioObjectPropertyAddress nameAddr = {
            kAudioDevicePropertyDeviceNameCFString,
            kAudioObjectPropertyScopeGlobal,
            kAudioObjectPropertyElementMaster
        };
        AudioObjectGetPropertyData(devID, &nameAddr, 0, NULL, &nameSize, &cfName);
        NSString* name = cfName ? (__bridge_transfer NSString*)cfName : [NSString stringWithFormat:@"Device %u", (unsigned int)devID];

        // Check Input Channels
        AudioObjectPropertyAddress streamAddr = {
            kAudioDevicePropertyStreamConfiguration,
            kAudioDevicePropertyScopeInput,
            kAudioObjectPropertyElementMaster
        };
        UInt32 bufListSize = 0;
        int inCh = 0;
        if (AudioObjectGetPropertyDataSize(devID, &streamAddr, 0, NULL, &bufListSize) == noErr && bufListSize > 0) {
            std::vector<uint8_t> buffer(bufListSize);
            AudioBufferList* bufList = (AudioBufferList*)buffer.data();
            if (AudioObjectGetPropertyData(devID, &streamAddr, 0, NULL, &bufListSize, bufList) == noErr) {
                for (UInt32 b = 0; b < bufList->mNumberBuffers; ++b) {
                    inCh += bufList->mBuffers[b].mNumberChannels;
                }
            }
        }

        // Check Output Channels
        streamAddr.mScope = kAudioDevicePropertyScopeOutput;
        bufListSize = 0;
        int outCh = 0;
        if (AudioObjectGetPropertyDataSize(devID, &streamAddr, 0, NULL, &bufListSize) == noErr && bufListSize > 0) {
            std::vector<uint8_t> buffer(bufListSize);
            AudioBufferList* bufList = (AudioBufferList*)buffer.data();
            if (AudioObjectGetPropertyData(devID, &streamAddr, 0, NULL, &bufListSize, bufList) == noErr) {
                for (UInt32 b = 0; b < bufList->mNumberBuffers; ++b) {
                    outCh += bufList->mBuffers[b].mNumberChannels;
                }
            }
        }

        if (inCh > 0 || outCh > 0) {
            AudioHardwareDevice* dev = [[AudioHardwareDevice alloc] init];
            dev.deviceID = devID;
            dev.name = name;
            dev.inputChannels = inCh;
            dev.outputChannels = outCh;
            dev.isInput = (inCh > 0);
            dev.isOutput = (outCh > 0);
            [list addObject:dev];
        }
    }

    return list;
}

+ (NSArray<NSString*>*)getAvailableInputNames {
    NSMutableArray<NSString*>* names = [NSMutableArray array];
    NSArray<AudioHardwareDevice*>* devs = [self scanAvailableDevices];
    for (AudioHardwareDevice* d in devs) {
        if (d.isInput) {
            if (d.inputChannels >= 2) {
                [names addObject:[NSString stringWithFormat:@"In 1 (%@)", d.name]];
                [names addObject:[NSString stringWithFormat:@"In 2 (%@)", d.name]];
                [names addObject:[NSString stringWithFormat:@"In 1-2 Stereo (%@)", d.name]];
            } else {
                [names addObject:[NSString stringWithFormat:@"In 1 (%@)", d.name]];
            }
        }
    }
    if (names.count == 0) {
        [names addObject:@"Built-in Microphone (Mac)"];
    }
    return names;
}

+ (NSArray<NSString*>*)getAvailableOutputNames {
    NSMutableArray<NSString*>* names = [NSMutableArray array];
    [names addObject:@"Master Main Mix"];
    NSArray<AudioHardwareDevice*>* devs = [self scanAvailableDevices];
    for (AudioHardwareDevice* d in devs) {
        if (d.isOutput) {
            [names addObject:[NSString stringWithFormat:@"Out (%@)", d.name]];
        }
    }
    return names;
}

- (instancetype)initWithAudioEngine:(std::shared_ptr<OnLive::DSP::AudioEngine>)engine {
    self = [super init];
    if (self) {
        _audioEngine = engine;
        _sampleRate = 48000.0f;
        _isRunning = NO;
        [self setupAudioUnit];
    }
    return self;
}

- (void)dealloc {
    [self stop];
    if (_outputUnit) {
        AudioComponentInstanceDispose(_outputUnit);
    }
}

- (void)setupAudioUnit {
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_DefaultOutput;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;

    AudioComponent comp = AudioComponentFindNext(NULL, &desc);
    if (!comp) {
        NSLog(@"[CoreAudio] Failed to find default output component");
        return;
    }

    OSStatus status = AudioComponentInstanceNew(comp, &_outputUnit);
    if (status != noErr) {
        NSLog(@"[CoreAudio] AudioComponentInstanceNew failed: %d", (int)status);
        return;
    }

    AudioStreamBasicDescription asbd;
    memset(&asbd, 0, sizeof(asbd));
    asbd.mSampleRate = _sampleRate;
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagIsPacked;
    asbd.mBytesPerPacket = sizeof(float);
    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerFrame = sizeof(float);
    asbd.mChannelsPerFrame = 2;
    asbd.mBitsPerChannel = 32;

    status = AudioUnitSetProperty(_outputUnit,
                                 kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Input,
                                 0,
                                 &asbd,
                                 sizeof(asbd));
    if (status != noErr) {
        NSLog(@"[CoreAudio] Failed to set stream format: %d", (int)status);
    }

    AURenderCallbackStruct callback;
    callback.inputProc = audioOutputCallback;
    callback.inputProcRefCon = (__bridge void*)self;

    status = AudioUnitSetProperty(_outputUnit,
                                 kAudioUnitProperty_SetRenderCallback,
                                 kAudioUnitScope_Input,
                                 0,
                                 &callback,
                                 sizeof(callback));
    if (status != noErr) {
        NSLog(@"[CoreAudio] Failed to set render callback: %d", (int)status);
    }

    AudioUnitInitialize(_outputUnit);
}

- (BOOL)start {
    if (_isRunning || !_outputUnit) return _isRunning;
    OSStatus status = AudioOutputUnitStart(_outputUnit);
    if (status == noErr) {
        _isRunning = YES;
        NSLog(@"[CoreAudio] Audio output unit started at %.1f kHz", _sampleRate);
    } else {
        NSLog(@"[CoreAudio] Failed to start output unit: %d", (int)status);
    }
    return _isRunning;
}

- (void)stop {
    if (!_isRunning || !_outputUnit) return;
    AudioOutputUnitStop(_outputUnit);
    _isRunning = NO;
    NSLog(@"[CoreAudio] Audio output unit stopped");
}

- (float)getVocalMeterDb {
    return _audioEngine ? _audioEngine->getVocalChannel().getPeakMeterDb() : -96.0f;
}

- (float)getMusicMeterDb {
    return _audioEngine ? _audioEngine->getMusicChannel().getPeakMeterDb() : -96.0f;
}

- (float)getMasterMeterDb {
    return _audioEngine ? _audioEngine->getMasterChannel().getPeakMeterDb() : -96.0f;
}

@end
