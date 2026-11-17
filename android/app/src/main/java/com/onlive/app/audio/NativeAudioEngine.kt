package com.onlive.app.audio

/**
 * Kotlin JNI Bridge to the high-performance C++20 Core Audio Engine.
 */
object NativeAudioEngine {
    init {
        System.loadLibrary("onlive_audio_jni")
    }

    enum class Preset(val rawValue: Int) {
        TALK_CHITCHAT(0),
        POP_STUDIO(1),
        BALLAD(2),
        ACOUSTIC_WARM(3),
        DANGDUT_MELAYU(4),
        MODERN_RNB(5)
    }

    external fun nativeInit(sampleRate: Float, maxFrames: Int)
    external fun nativeLoadPreset(presetOrdinal: Int)
    external fun nativeSetChannelVolume(channelIdx: Int, volumeDb: Float)
    external fun nativeSetChannelMute(channelIdx: Int, mute: Boolean)
    external fun nativeSetChannelSolo(channelIdx: Int, solo: Boolean)
    external fun nativeGetChannelMeterDb(channelIdx: Int): Float
    external fun nativeSetVocalFxMacro(intensity: Float)
    external fun nativeSetAutoCarve(enabled: Boolean)
    external fun nativeSetReverbEnabled(enabled: Boolean)
    external fun nativeSetDelayEnabled(enabled: Boolean)
    external fun nativeSetHarmonizerEnabled(enabled: Boolean)
    external fun nativeSetSubBoosterEnabled(enabled: Boolean)

    fun initialize(sampleRate: Float = 48000.0f, maxFrames: Int = 256) {
        nativeInit(sampleRate, maxFrames)
    }

    fun loadPreset(preset: Preset) {
        nativeLoadPreset(preset.rawValue)
    }
}

