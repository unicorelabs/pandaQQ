#pragma once

#include "AudioBuffer.hpp"
#include "RingBuffer.hpp"
#include "ChannelStrip.hpp"
#include "BiquadFilter.hpp"
#include "NoiseGate.hpp"
#include "Compressor.hpp"
#include "DeEsser.hpp"
#include "SubHarmonic.hpp"
#include "DynamicSidechain.hpp"
#include "Reverb.hpp"
#include "Delay.hpp"
#include "Harmonizer.hpp"
#include "Chorus.hpp"
#include "TruePeakLimiter.hpp"
#include <memory>
#include <array>

namespace OnLive::DSP {

enum class FactoryPreset {
    TalkChitChat,
    PopStudio,
    Ballad,
    AcousticWarm,
    DangdutMelayu,
    ModernRnB
};

/**
 * @brief Master Real-time Audio Engine for Live Karaoke DAW.
 * Runs on Android (Oboe), iOS/macOS (CoreAudio), and Windows (WASAPI).
 */
class AudioEngine {
public:
    AudioEngine();
    ~AudioEngine() = default;

    void initialize(float sampleRate = 48000.0f, size_t maxFrames = 256);

    /**
     * @brief Real-time Audio Render Callback (Called by OS high-priority audio thread).
     * Strictly ZERO memory allocation and ZERO blocking locks.
     */
    void processAudio(const float* micInput, const float* musicInputL, const float* musicInputR,
                      float* broadcastOutL, float* broadcastOutR,
                      float* monitorOutL, float* monitorOutR,
                      size_t numFrames) noexcept;

    // Factory Presets
    void loadFactoryPreset(FactoryPreset preset) noexcept;

    // Channel Accessors
    ChannelStrip& getVocalChannel() noexcept { return m_vocalChannel; }
    ChannelStrip& getFxChannel() noexcept { return m_fxChannel; }
    ChannelStrip& getMusicChannel() noexcept { return m_musicChannel; }
    ChannelStrip& getMasterChannel() noexcept { return m_masterChannel; }

    // Sub-engine Accessors for Pro Drawer
    NoiseGate& getNoiseGate() noexcept { return m_noiseGate; }
    DeEsser& getDeEsser() noexcept { return m_deEsser; }
    Compressor& getVocalCompressor() noexcept { return m_vocalCompressor; }
    SubHarmonic& getSubHarmonic() noexcept { return m_subHarmonic; }
    DynamicSidechain& getDynamicSidechain() noexcept { return m_dynamicSidechain; }
    Compressor& getMusicDucker() noexcept { return m_musicDucker; }
    Reverb& getReverb() noexcept { return m_reverb; }
    Delay& getDelay() noexcept { return m_delay; }
    Harmonizer& getHarmonizer() noexcept { return m_harmonizer; }
    Chorus& getChorus() noexcept { return m_chorus; }
    TruePeakLimiter& getMasterLimiter() noexcept { return m_masterLimiter; }

    // Vocal EQ (4-Band / 7-Band Peaking array)
    static constexpr size_t NUM_EQ_BANDS = 7;
    BiquadFilter& getVocalEqBand(size_t index) noexcept { return m_vocalEq[index % NUM_EQ_BANDS]; }

    // Macro FX Control
    void setVocalFxMacro(float intensity) noexcept; // 0.0 to 1.0 (Controls Reverb + Delay together)

    // Sidechain & Carve Toggles
    void setAutoCarveEnabled(bool enabled) noexcept { m_dynamicSidechain.setEnabled(enabled); }
    bool isAutoCarveEnabled() const noexcept { return m_dynamicSidechain.isEnabled(); }

    void setAutoDuckerEnabled(bool enabled) noexcept { m_musicDucker.setEnabled(enabled); }
    bool isAutoDuckerEnabled() const noexcept { return m_musicDucker.isEnabled(); }

    float getSampleRate() const noexcept { return m_sampleRate; }

private:
    float m_sampleRate{48000.0f};

    // 4 Main Channels
    ChannelStrip m_vocalChannel{"Vokal"};
    ChannelStrip m_fxChannel{"Efek Vokal"};
    ChannelStrip m_musicChannel{"Musik"};
    ChannelStrip m_masterChannel{"Master"};

    // Vocal Insert Rack
    NoiseGate m_noiseGate;
    DeEsser m_deEsser;
    std::array<BiquadFilter, NUM_EQ_BANDS> m_vocalEq;
    Compressor m_vocalCompressor;
    BiquadFilter m_vocalHighPassSafety;

    // Music Processing
    SubHarmonic m_subHarmonic;
    DynamicSidechain m_dynamicSidechain;
    Compressor m_musicDucker; // Wideband ducking when singing

    // 4 Parallel Send FX
    Reverb m_reverb;
    Delay m_delay;
    Harmonizer m_harmonizer;
    Chorus m_chorus;

    // Master Finalizer
    TruePeakLimiter m_masterLimiter;

    // Pre-allocated scratch buffers (ZERO allocation on audio thread)
    alignas(64) std::array<float, 1024> m_scratchVocalDry;
    alignas(64) std::array<float, 1024> m_scratchMusicMono;
    alignas(64) std::array<float, 1024> m_scratchFxL;
    alignas(64) std::array<float, 1024> m_scratchFxR;
    alignas(64) std::array<float, 1024> m_scratchSumL;
    alignas(64) std::array<float, 1024> m_scratchSumR;
};

} // namespace OnLive::DSP
