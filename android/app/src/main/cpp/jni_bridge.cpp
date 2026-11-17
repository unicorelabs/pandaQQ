#include <jni.h>
#include "AudioEngine.hpp"
#include <memory>

static std::unique_ptr<OnLive::DSP::AudioEngine> g_audioEngine;

extern "C" {

JNIEXPORT void JNICALL
Java_com_onlive_app_audio_NativeAudioEngine_nativeInit(JNIEnv* env, jobject thiz, jfloat sampleRate, jint maxFrames) {
    (void)env;
    (void)thiz;
    g_audioEngine = std::make_unique<OnLive::DSP::AudioEngine>();
    g_audioEngine->initialize(sampleRate, static_cast<size_t>(maxFrames));
}

JNIEXPORT void JNICALL
Java_com_onlive_app_audio_NativeAudioEngine_nativeLoadPreset(JNIEnv* env, jobject thiz, jint presetOrdinal) {
    (void)env;
    (void)thiz;
    if (g_audioEngine) {
        g_audioEngine->loadFactoryPreset(static_cast<OnLive::DSP::FactoryPreset>(presetOrdinal));
    }
}

JNIEXPORT void JNICALL
Java_com_onlive_app_audio_NativeAudioEngine_nativeSetChannelVolume(JNIEnv* env, jobject thiz, jint channelIdx, jfloat volumeDb) {
    (void)env;
    (void)thiz;
    if (!g_audioEngine) return;
    switch (channelIdx) {
        case 0: g_audioEngine->getVocalChannel().setVolumeDb(volumeDb); break;
        case 1: g_audioEngine->getFxChannel().setVolumeDb(volumeDb); break;
        case 2: g_audioEngine->getMusicChannel().setVolumeDb(volumeDb); break;
        case 3: g_audioEngine->getMasterChannel().setVolumeDb(volumeDb); break;
        default: break;
    }
}

JNIEXPORT void JNICALL
Java_com_onlive_app_audio_NativeAudioEngine_nativeSetChannelMute(JNIEnv* env, jobject thiz, jint channelIdx, jboolean mute) {
    (void)env;
    (void)thiz;
    if (!g_audioEngine) return;
    switch (channelIdx) {
        case 0: g_audioEngine->getVocalChannel().setMute(mute); break;
        case 1: g_audioEngine->getFxChannel().setMute(mute); break;
        case 2: g_audioEngine->getMusicChannel().setMute(mute); break;
        case 3: g_audioEngine->getMasterChannel().setMute(mute); break;
        default: break;
    }
}

JNIEXPORT void JNICALL
Java_com_onlive_app_audio_NativeAudioEngine_nativeSetChannelSolo(JNIEnv* env, jobject thiz, jint channelIdx, jboolean solo) {
    (void)env;
    (void)thiz;
    if (!g_audioEngine) return;
    switch (channelIdx) {
        case 0: g_audioEngine->getVocalChannel().setSolo(solo); break;
        case 1: g_audioEngine->getFxChannel().setSolo(solo); break;
        case 2: g_audioEngine->getMusicChannel().setSolo(solo); break;
        case 3: g_audioEngine->getMasterChannel().setSolo(solo); break;
        default: break;
    }
}

JNIEXPORT jfloat JNICALL
Java_com_onlive_app_audio_NativeAudioEngine_nativeGetChannelMeterDb(JNIEnv* env, jobject thiz, jint channelIdx) {
    (void)env;
    (void)thiz;
    if (!g_audioEngine) return -96.0f;
    switch (channelIdx) {
        case 0: return g_audioEngine->getVocalChannel().getPeakMeterDb();
        case 1: return g_audioEngine->getFxChannel().getPeakMeterDb();
        case 2: return g_audioEngine->getMusicChannel().getPeakMeterDb();
        case 3: return g_audioEngine->getMasterChannel().getPeakMeterDb();
        default: return -96.0f;
    }
}

JNIEXPORT void JNICALL
Java_com_onlive_app_audio_NativeAudioEngine_nativeSetVocalFxMacro(JNIEnv* env, jobject thiz, jfloat intensity) {
    (void)env;
    (void)thiz;
    if (g_audioEngine) {
        g_audioEngine->setVocalFxMacro(intensity);
    }
}

JNIEXPORT void JNICALL
Java_com_onlive_app_audio_NativeAudioEngine_nativeSetAutoCarve(JNIEnv* env, jobject thiz, jboolean enabled) {
    (void)env;
    (void)thiz;
    if (g_audioEngine) {
        g_audioEngine->setAutoCarveEnabled(enabled);
    }
}

} // extern "C"
