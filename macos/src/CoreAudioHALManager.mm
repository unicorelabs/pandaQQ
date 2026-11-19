#import "CoreAudioHALManager.h"
#include <vector>
#include <algorithm>
#include <atomic>
#include <cmath>

static const size_t RING_BUFFER_SIZE = 16384;

struct AudioRingBuffer {
    std::vector<float> data;
    std::atomic<size_t> writeHead{0};
    std::atomic<size_t> readHead{0};

    AudioRingBuffer() : data(RING_BUFFER_SIZE, 0.0f) {}

    void write(const float* input, size_t count) {
        size_t currentWrite = writeHead.load(std::memory_order_relaxed);
        for (size_t i = 0; i < count; ++i) {
            data[(currentWrite + i) % RING_BUFFER_SIZE] = input[i];
        }
        writeHead.store((currentWrite + count) % RING_BUFFER_SIZE, std::memory_order_release);
    }

    void read(float* output, size_t count) {
        size_t currentRead = readHead.load(std::memory_order_relaxed);
        size_t currentWrite = writeHead.load(std::memory_order_acquire);
        size_t available = (currentWrite >= currentRead) ? (currentWrite - currentRead) : (RING_BUFFER_SIZE - currentRead + currentWrite);

        if (available < count) {
            // Underflow: Pad with zero
            memset(output, 0, count * sizeof(float));
            return;
        }

        for (size_t i = 0; i < count; ++i) {
            output[i] = data[(currentRead + i) % RING_BUFFER_SIZE];
        }
        readHead.store((currentRead + count) % RING_BUFFER_SIZE, std::memory_order_release);
    }
};

@implementation AudioHardwareDevice
@end

@interface CoreAudioHALManager () {
@public
    AudioComponentInstance _inputUnit;
    AudioComponentInstance _outputUnit;
    AudioRingBuffer _micRingBuffer;
    float _testTonePhase;
}
@end

// CoreAudio Input Callback (Records Microphone Audio)
static OSStatus audioInputCallback(void* inRefCon,
                                  AudioUnitRenderActionFlags* ioActionFlags,
                                  const AudioTimeStamp* inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  [[maybe_unused]] AudioBufferList* ioData) {
    CoreAudioHALManager* manager = (__bridge CoreAudioHALManager*)inRefCon;
    if (!manager) return noErr;

    AudioBufferList bufferList;
    static std::vector<float> inputStorage(2048, 0.0f);
    if (inNumberFrames > inputStorage.size()) {
        inputStorage.resize(inNumberFrames);
    }

    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mNumberChannels = 1;
    bufferList.mBuffers[0].mDataByteSize = inNumberFrames * sizeof(float);
    bufferList.mBuffers[0].mData = inputStorage.data();

    // Render audio from microphone hardware input (Bus 1)
    OSStatus status = AudioUnitRender(manager->_inputUnit,
                                     ioActionFlags,
                                     inTimeStamp,
                                     inBusNumber,
                                     inNumberFrames,
                                     &bufferList);

    if (status == noErr) {
        manager->_micRingBuffer.write(inputStorage.data(), inNumberFrames);
    }

    return noErr;
}

// CoreAudio Output Callback (Processes DSP Engine & Plays Audio)
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

    static std::vector<float> micBuffer(1024, 0.0f);
    static std::vector<float> musicDummyL(1024, 0.0f);
    static std::vector<float> musicDummyR(1024, 0.0f);
    static std::vector<float> broadcastL(1024, 0.0f);
    static std::vector<float> broadcastR(1024, 0.0f);
    static std::vector<float> monitorL(1024, 0.0f);
    static std::vector<float> monitorR(1024, 0.0f);

    const UInt32 frames = std::min(inNumberFrames, (UInt32)1024);

    // Read real microphone samples from the ring buffer
    manager->_micRingBuffer.read(micBuffer.data(), frames);

    // If Music from YouTube is playing, feed modulated music signal into DSP engine
    if (manager.isMusicPlaying && manager.musicPeakLevel > -60.0f) {
        float peakLinear = powf(10.0f, std::clamp(manager.musicPeakLevel, -48.0f, 0.0f) / 20.0f);
        static float musicPhase = 0.0f;
        for (UInt32 i = 0; i < frames; ++i) {
            float s = sinf(musicPhase) * 0.7f + sinf(musicPhase * 1.5f) * 0.3f;
            musicPhase += 2.0f * M_PI * 220.0f / 48000.0f;
            if (musicPhase > 2.0f * M_PI) musicPhase -= 2.0f * M_PI;
            musicDummyL[i] = s * peakLinear;
            musicDummyR[i] = s * peakLinear;
        }
    } else {
        std::fill(musicDummyL.begin(), musicDummyL.end(), 0.0f);
        std::fill(musicDummyR.begin(), musicDummyR.end(), 0.0f);
    }

    // If Test Tone is enabled, synthesize live vocal test tone (440Hz warm voice wave)
    if (manager.testToneEnabled) {
        float& phase = manager->_testTonePhase;
        for (UInt32 i = 0; i < frames; ++i) {
            float s = 0.25f * sinf(phase) + 0.08f * sinf(phase * 2.0f);
            phase += 2.0f * M_PI * 440.0f / 48000.0f;
            if (phase > 2.0f * M_PI) phase -= 2.0f * M_PI;
            micBuffer[i] += s;
        }
    }

    auto engine = manager.audioEngine;
    if (engine) {
        engine->processAudio(micBuffer.data(),
                            musicDummyL.data(), musicDummyR.data(),
                            broadcastL.data(), broadcastR.data(),
                            monitorL.data(), monitorR.data(),
                            frames);

        for (UInt32 i = 0; i < inNumberFrames; ++i) {
            float sL = (i < frames) ? monitorL[i] : 0.0f;
            float sR = (i < frames) ? monitorR[i] : 0.0f;
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

@implementation CoreAudioHALManager

+ (void)requestMicrophonePermission:(void (^)(BOOL granted))completion {
    if (@available(macOS 10.14, *)) {
        AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
        if (status == AVAuthorizationStatusNotDetermined) {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
                NSLog(@"[CoreAudioHAL] Microphone permission granted: %d", granted);
                if (completion) completion(granted);
            }];
        } else {
            if (completion) completion(status == AVAuthorizationStatusAuthorized);
        }
    } else {
        if (completion) completion(YES);
    }
}

+ (NSArray<AudioHardwareDevice*>*)scanAvailableDevices {
    NSMutableArray<AudioHardwareDevice*>* list = [NSMutableArray array];
    AudioObjectPropertyAddress addr = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
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
            kAudioObjectPropertyElementMain
        };
        AudioObjectGetPropertyData(devID, &nameAddr, 0, NULL, &nameSize, &cfName);
        NSString* name = cfName ? (__bridge_transfer NSString*)cfName : [NSString stringWithFormat:@"Device %u", (unsigned int)devID];

        // Check Input Channels
        AudioObjectPropertyAddress streamAddr = {
            kAudioDevicePropertyStreamConfiguration,
            kAudioDevicePropertyScopeInput,
            kAudioObjectPropertyElementMain
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
            [names addObject:d.name];
        }
    }
    if (names.count == 0) {
        [names addObject:@"Built-in Microphone (Mac)"];
    }
    return names;
}

+ (NSArray<NSString*>*)getAvailableOutputNames {
    NSMutableArray<NSString*>* names = [NSMutableArray array];
    [names addObject:@"Master Main Mix (Default)"];
    NSArray<AudioHardwareDevice*>* devs = [self scanAvailableDevices];
    for (AudioHardwareDevice* d in devs) {
        if (d.isOutput) {
            [names addObject:d.name];
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
        _testToneEnabled = NO;
        _testTonePhase = 0.0f;
        _activeInputDeviceName = @"Default Input";
        _activeOutputDeviceName = @"Default Output";

        [CoreAudioHALManager requestMicrophonePermission:nil];
        [self setupAudioUnits];
    }
    return self;
}

- (void)dealloc {
    [self stop];
    if (_inputUnit) AudioComponentInstanceDispose(_inputUnit);
    if (_outputUnit) AudioComponentInstanceDispose(_outputUnit);
}

- (void)setupAudioUnits {
    // 1. Setup Input Audio Unit (AUHAL for Microphone Capture)
    AudioComponentDescription inDesc;
    inDesc.componentType = kAudioUnitType_Output;
    inDesc.componentSubType = kAudioUnitSubType_HALOutput;
    inDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    inDesc.componentFlags = 0;
    inDesc.componentFlagsMask = 0;

    AudioComponent inComp = AudioComponentFindNext(NULL, &inDesc);
    if (inComp && AudioComponentInstanceNew(inComp, &_inputUnit) == noErr) {
        UInt32 enableIO = 1;
        AudioUnitSetProperty(_inputUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enableIO, sizeof(enableIO));
        enableIO = 0;
        AudioUnitSetProperty(_inputUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &enableIO, sizeof(enableIO));

        AudioStreamBasicDescription asbd;
        memset(&asbd, 0, sizeof(asbd));
        asbd.mSampleRate = _sampleRate;
        asbd.mFormatID = kAudioFormatLinearPCM;
        asbd.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
        asbd.mBytesPerPacket = sizeof(float);
        asbd.mFramesPerPacket = 1;
        asbd.mBytesPerFrame = sizeof(float);
        asbd.mChannelsPerFrame = 1;
        asbd.mBitsPerChannel = 32;

        AudioUnitSetProperty(_inputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &asbd, sizeof(asbd));

        AURenderCallbackStruct inCb;
        inCb.inputProc = audioInputCallback;
        inCb.inputProcRefCon = (__bridge void*)self;
        AudioUnitSetProperty(_inputUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &inCb, sizeof(inCb));

        AudioUnitInitialize(_inputUnit);
        NSLog(@"[CoreAudioHAL] Microphone Input Unit initialized successfully");
    }

    // 2. Setup Output Audio Unit (Default Output for Monitoring / Speakers)
    AudioComponentDescription outDesc;
    outDesc.componentType = kAudioUnitType_Output;
    outDesc.componentSubType = kAudioUnitSubType_DefaultOutput;
    outDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    outDesc.componentFlags = 0;
    outDesc.componentFlagsMask = 0;

    AudioComponent outComp = AudioComponentFindNext(NULL, &outDesc);
    if (outComp && AudioComponentInstanceNew(outComp, &_outputUnit) == noErr) {
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

        AudioUnitSetProperty(_outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &asbd, sizeof(asbd));

        AURenderCallbackStruct outCb;
        outCb.inputProc = audioOutputCallback;
        outCb.inputProcRefCon = (__bridge void*)self;
        AudioUnitSetProperty(_outputUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &outCb, sizeof(outCb));

        AudioUnitInitialize(_outputUnit);
        NSLog(@"[CoreAudioHAL] Audio Output Unit initialized successfully");
    }
}

- (BOOL)start {
    if (_isRunning) return YES;

    if (_inputUnit) {
        AudioOutputUnitStart(_inputUnit);
    }
    if (_outputUnit) {
        AudioOutputUnitStart(_outputUnit);
    }

    _isRunning = YES;
    NSLog(@"[CoreAudioHAL] CoreAudio HAL started at %.1f kHz", _sampleRate);
    return YES;
}

- (void)stop {
    if (!_isRunning) return;
    if (_inputUnit) AudioOutputUnitStop(_inputUnit);
    if (_outputUnit) AudioOutputUnitStop(_outputUnit);
    _isRunning = NO;
    NSLog(@"[CoreAudioHAL] CoreAudio HAL stopped");
}

- (void)toggleTestTone {
    _testToneEnabled = !_testToneEnabled;
    NSLog(@"[CoreAudioHAL] Test Tone toggled: %d", _testToneEnabled);
}

- (void)selectInputDeviceByName:(NSString*)name {
    _activeInputDeviceName = [name copy];
    NSArray<AudioHardwareDevice*>* devs = [CoreAudioHALManager scanAvailableDevices];
    for (AudioHardwareDevice* d in devs) {
        if ([d.name containsString:name] && d.isInput && _inputUnit) {
            AudioDeviceID devID = d.deviceID;
            AudioUnitSetProperty(_inputUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &devID, sizeof(devID));
            NSLog(@"[CoreAudioHAL] Selected Input Device: %@ (ID: %u)", d.name, (unsigned int)devID);
            break;
        }
    }
}

- (void)selectOutputDeviceByName:(NSString*)name {
    _activeOutputDeviceName = [name copy];
    NSArray<AudioHardwareDevice*>* devs = [CoreAudioHALManager scanAvailableDevices];
    for (AudioHardwareDevice* d in devs) {
        if ([d.name containsString:name] && d.isOutput && _outputUnit) {
            AudioDeviceID devID = d.deviceID;
            AudioUnitSetProperty(_outputUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &devID, sizeof(devID));
            NSLog(@"[CoreAudioHAL] Selected Output Device: %@ (ID: %u)", d.name, (unsigned int)devID);
            break;
        }
    }
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
