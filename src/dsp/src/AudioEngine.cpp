#include "AudioEngine.hpp"
#include <cstring>

namespace OnLive::DSP {

AudioEngine::AudioEngine() {
    initialize(48000.0f, 256);
}

void AudioEngine::initialize(float sampleRate, [[maybe_unused]] size_t maxFrames) {
    m_sampleRate = sampleRate;

    // 1. Initialize Vocal Insert Rack
    m_vocalHighPassSafety.setParameters(FilterType::HighPass, 85.0f, 0.707f, 0.0f, sampleRate);
    m_noiseGate.setParameters(-46.0f, 6.0f, 2.0f, 60.0f, sampleRate);
    m_deEsser.setParameters(6500.0f, -24.0f, 4.0f, sampleRate);

    // 7-Band Musical Stage EQ
    // 63Hz, 160Hz, 400Hz, 1kHz, 2.5kHz, 6.3kHz, 16kHz
    constexpr float eqFreqs[NUM_EQ_BANDS] = { 63.0f, 160.0f, 400.0f, 1000.0f, 2500.0f, 6300.0f, 16000.0f };
    for (size_t i = 0; i < NUM_EQ_BANDS; ++i) {
        m_vocalEq[i].setParameters(FilterType::Peaking, eqFreqs[i], 1.2f, 0.0f, sampleRate);
    }

    m_vocalCompressor.setParameters(-18.0f, 3.2f, 5.0f, 90.0f, 4.0f, sampleRate);
    m_vocalCompressor.setMakeupGainDb(2.5f);

    // 2. Initialize Music Processing
    m_subHarmonic.setParameters(85.0f, 0.35f, sampleRate);
    m_dynamicSidechain.setParameters(2200.0f, 1.2f, -5.0f, -28.0f, sampleRate);
    m_musicDucker.setParameters(-22.0f, 2.0f, 15.0f, 200.0f, 6.0f, sampleRate);
    m_musicDucker.setMakeupGainDb(0.0f);

    // 3. Initialize Send FX
    m_reverb.setParameters(2.5f, 35.0f, 0.4f, 120.0f, 6500.0f, sampleRate);
    m_delay.setParameters(DelayMode::PingPong, 280.0f, 0.40f, 0.6f, 3500.0f, sampleRate);
    m_harmonizer.setParameters(HarmonyInterval::ThirdAbove, 0.0f, sampleRate);
    m_chorus.setParameters(0.8f, 0.4f, 1.2f, sampleRate);

    // 4. Initialize Master Limiter
    m_masterLimiter.setCeilingDb(-1.0f, sampleRate);

    // Set Default Faders
    m_vocalChannel.setVolumeDb(0.0f);
    m_fxChannel.setVolumeDb(-6.0f);
    m_musicChannel.setVolumeDb(-3.0f);
    m_masterChannel.setVolumeDb(0.0f);

    // Load Factory Default: Pop Studio
    loadFactoryPreset(FactoryPreset::PopStudio);
}

void AudioEngine::loadFactoryPreset(FactoryPreset preset) noexcept {
    switch (preset) {
        case FactoryPreset::PopStudio:
            m_noiseGate.setEnabled(true);
            m_deEsser.setEnabled(true);
            m_vocalEq[1].setDynamicGainDb(1.0f);  // Body 160Hz
            m_vocalEq[2].setDynamicGainDb(-1.5f); // Mud cut 400Hz
            m_vocalEq[4].setDynamicGainDb(2.0f);  // Presence 2.5kHz
            m_vocalEq[5].setDynamicGainDb(2.5f);  // Air 6.3kHz
            m_vocalCompressor.setParameters(-18.0f, 3.5f, 5.0f, 90.0f, 4.0f, m_sampleRate);
            m_reverb.setParameters(2.2f, 30.0f, 0.45f, 120.0f, 6500.0f, m_sampleRate);
            m_delay.setParameters(DelayMode::PingPong, 260.0f, 0.35f, 0.6f, 3500.0f, m_sampleRate);
            m_vocalChannel.setSendLevel(0, 0.50f); // Reverb
            m_vocalChannel.setSendLevel(1, 0.25f); // Delay
            m_vocalChannel.setSendLevel(2, 0.0f);  // Harm
            m_vocalChannel.setSendLevel(3, 0.15f); // Chorus
            m_dynamicSidechain.setEnabled(true);
            m_subHarmonic.setEnabled(true);
            break;

        case FactoryPreset::Ballad:
            m_noiseGate.setEnabled(true);
            m_deEsser.setEnabled(true);
            m_vocalEq[1].setDynamicGainDb(2.0f);  // Warm body
            m_vocalEq[4].setDynamicGainDb(1.5f);
            m_vocalCompressor.setParameters(-16.0f, 3.0f, 8.0f, 120.0f, 6.0f, m_sampleRate);
            m_reverb.setParameters(3.5f, 45.0f, 0.35f, 100.0f, 6000.0f, m_sampleRate);
            m_delay.setParameters(DelayMode::PingPong, 380.0f, 0.45f, 0.7f, 3000.0f, m_sampleRate);
            m_vocalChannel.setSendLevel(0, 0.65f); // Lush Reverb
            m_vocalChannel.setSendLevel(1, 0.40f); // Sing delay
            m_vocalChannel.setSendLevel(2, 0.0f);
            m_vocalChannel.setSendLevel(3, 0.10f);
            m_dynamicSidechain.setEnabled(true);
            m_subHarmonic.setEnabled(true);
            break;

        case FactoryPreset::AcousticWarm:
            m_noiseGate.setEnabled(true);
            m_deEsser.setEnabled(true);
            m_vocalEq[1].setDynamicGainDb(1.0f);
            m_vocalEq[2].setDynamicGainDb(-2.0f);
            m_vocalEq[4].setDynamicGainDb(2.0f);
            m_vocalCompressor.setParameters(-14.0f, 2.5f, 10.0f, 100.0f, 4.0f, m_sampleRate);
            m_reverb.setParameters(1.6f, 20.0f, 0.55f, 150.0f, 5500.0f, m_sampleRate); // Short plate
            m_vocalChannel.setSendLevel(0, 0.35f);
            m_vocalChannel.setSendLevel(1, 0.0f);  // No delay
            m_vocalChannel.setSendLevel(2, 0.0f);
            m_vocalChannel.setSendLevel(3, 0.0f);
            m_dynamicSidechain.setEnabled(true);
            m_subHarmonic.setEnabled(false);
            break;

        case FactoryPreset::DangdutMelayu:
            m_noiseGate.setEnabled(true);
            m_deEsser.setEnabled(true);
            m_vocalEq[3].setDynamicGainDb(1.5f);
            m_vocalEq[4].setDynamicGainDb(3.0f);  // Crisp presence
            m_vocalCompressor.setParameters(-20.0f, 4.0f, 3.0f, 60.0f, 3.0f, m_sampleRate);
            m_reverb.setParameters(2.0f, 25.0f, 0.40f, 140.0f, 7000.0f, m_sampleRate);
            m_delay.setParameters(DelayMode::PingPong, 220.0f, 0.50f, 0.5f, 4000.0f, m_sampleRate); // Fast energetic echo
            m_vocalChannel.setSendLevel(0, 0.45f);
            m_vocalChannel.setSendLevel(1, 0.50f); // High Echo
            m_vocalChannel.setSendLevel(2, 0.0f);
            m_vocalChannel.setSendLevel(3, 0.0f);
            m_dynamicSidechain.setEnabled(true);
            m_subHarmonic.setEnabled(true);
            break;

        case FactoryPreset::ModernRnB:
            m_noiseGate.setEnabled(true);
            m_deEsser.setEnabled(true);
            m_vocalEq[1].setDynamicGainDb(1.5f);
            m_vocalEq[4].setDynamicGainDb(2.5f);
            m_vocalEq[5].setDynamicGainDb(3.0f);
            m_vocalCompressor.setParameters(-22.0f, 4.5f, 2.0f, 50.0f, 4.0f, m_sampleRate);
            m_reverb.setParameters(1.8f, 20.0f, 0.40f, 130.0f, 6500.0f, m_sampleRate);
            m_delay.setParameters(DelayMode::PingPong, 240.0f, 0.30f, 0.6f, 3500.0f, m_sampleRate);
            m_vocalChannel.setSendLevel(0, 0.40f);
            m_vocalChannel.setSendLevel(1, 0.25f);
            m_vocalChannel.setSendLevel(2, 0.20f); // Harmony blend
            m_vocalChannel.setSendLevel(3, 0.35f); // Wide chorus
            m_dynamicSidechain.setEnabled(true);
            m_subHarmonic.setEnabled(true);
            break;

        case FactoryPreset::TalkChitChat:
            m_noiseGate.setEnabled(true);
            m_deEsser.setEnabled(true);
            m_vocalCompressor.setParameters(-16.0f, 2.5f, 10.0f, 100.0f, 4.0f, m_sampleRate);
            // Mute all effects for crystal clear speaking
            m_vocalChannel.setSendLevel(0, 0.0f);
            m_vocalChannel.setSendLevel(1, 0.0f);
            m_vocalChannel.setSendLevel(2, 0.0f);
            m_vocalChannel.setSendLevel(3, 0.0f);
            m_dynamicSidechain.setEnabled(false);
            m_subHarmonic.setEnabled(false);
            break;
    }
}

void AudioEngine::setVocalFxMacro(float intensity) noexcept {
    const float clamped = std::clamp(intensity, 0.0f, 1.0f);
    m_vocalChannel.setSendLevel(0, clamped * 0.70f); // Reverb scale
    m_vocalChannel.setSendLevel(1, clamped * 0.45f); // Delay scale
}

void AudioEngine::processAudio(const float* micInput, const float* musicInputL, const float* musicInputR,
                               float* broadcastOutL, float* broadcastOutR,
                               float* monitorOutL, float* monitorOutR,
                               size_t numFrames) noexcept {
    const size_t frames = std::min(numFrames, size_t(1024));

    // Clear scratch summing buffers
    std::memset(m_scratchSumL.data(), 0, sizeof(float) * frames);
    std::memset(m_scratchSumR.data(), 0, sizeof(float) * frames);
    std::memset(m_scratchFxL.data(), 0, sizeof(float) * frames);
    std::memset(m_scratchFxR.data(), 0, sizeof(float) * frames);

    // ========================================================
    // 1. VOCAL INSERT RACK PROCESSING
    // ========================================================
    for (size_t i = 0; i < frames; ++i) {
        float sample = micInput[i];

        // 1a. High Pass Filter (cut sub rumble < 85Hz)
        sample = m_vocalHighPassSafety.processSample(sample);

        // 1b. Adaptive Noise Gate
        sample = m_noiseGate.processSample(sample);

        // 1c. Split-band De-Esser
        sample = m_deEsser.processSample(sample);

        // 1d. 7-Band Musical Parametric EQ
        for (size_t b = 0; b < NUM_EQ_BANDS; ++b) {
            sample = m_vocalEq[b].processSample(sample);
        }

        // 1e. Vocal Studio Compressor
        sample = m_vocalCompressor.processSample(sample);

        m_scratchVocalDry[i] = sample;
    }

    // ========================================================
    // 2. PARALLEL SEND FX PROCESSING
    // ========================================================
    const float sendReverb = m_vocalChannel.getSendLevel(0);
    const float sendDelay  = m_vocalChannel.getSendLevel(1);
    const float sendHarm   = m_vocalChannel.getSendLevel(2);
    const float sendChorus = m_vocalChannel.getSendLevel(3);

    if (sendReverb > 0.001f) {
        m_reverb.processStereo(m_scratchVocalDry.data(), m_scratchFxL.data(), m_scratchFxR.data(), frames, sendReverb);
    }
    if (sendDelay > 0.001f) {
        m_delay.processStereo(m_scratchVocalDry.data(), m_scratchFxL.data(), m_scratchFxR.data(), frames, sendDelay);
    }
    if (sendHarm > 0.001f) {
        m_harmonizer.processStereo(m_scratchVocalDry.data(), m_scratchFxL.data(), m_scratchFxR.data(), frames, sendHarm);
    }
    if (sendChorus > 0.001f) {
        m_chorus.processStereo(m_scratchVocalDry.data(), m_scratchFxL.data(), m_scratchFxR.data(), frames, sendChorus);
    }

    // Apply FX Return Channel Fader
    m_fxChannel.process(m_scratchFxL.data(), m_scratchSumL.data(), m_scratchSumR.data(), frames);

    // ========================================================
    // 3. MUSIC PROCESSING (YOUTUBE)
    // ========================================================
    for (size_t i = 0; i < frames; ++i) {
        // Average stereo to mono for conditioning
        float musicSample = (musicInputL[i] + musicInputR[i]) * 0.5f;

        // 3a. Sub-Harmonic Bass Generator
        musicSample = m_subHarmonic.processSample(musicSample);

        m_scratchMusicMono[i] = musicSample;
    }

    // 3b. Dynamic Vocal Pocket Carver (Ducks 1.5-3.5kHz only when vocal is active)
    m_dynamicSidechain.processBuffer(m_scratchMusicMono.data(), m_scratchVocalDry.data(), frames);

    // 3c. Wideband Sidechain Ducker (Ducks entire music during vocal speech)
    m_musicDucker.processBufferSidechained(m_scratchMusicMono.data(), m_scratchVocalDry.data(), frames);

    // Apply Music Channel Fader
    m_musicChannel.process(m_scratchMusicMono.data(), m_scratchSumL.data(), m_scratchSumR.data(), frames);

    // ========================================================
    // 4. ADD VOCAL DRY CHANNEL TO SUM
    // ========================================================
    m_vocalChannel.process(m_scratchVocalDry.data(), m_scratchSumL.data(), m_scratchSumR.data(), frames);

    // ========================================================
    // 5. MASTER SUMMING & TRUE-PEAK LIMITER
    // ========================================================
    const float masterGain = m_masterChannel.isMuted() ? 0.0f : std::pow(10.0f, m_masterChannel.getVolumeDb() / 20.0f);

    for (size_t i = 0; i < frames; ++i) {
        m_scratchSumL[i] *= masterGain;
        m_scratchSumR[i] *= masterGain;
    }

    // True-Peak Brickwall Limiter (-1.0 dBTP Ceiling)
    m_masterLimiter.processStereo(m_scratchSumL.data(), m_scratchSumR.data(), frames);

    // Feed Broadcast Out (to HP 2 / TikTok) and Monitor Out (to In-Ear Headphones)
    for (size_t i = 0; i < frames; ++i) {
        broadcastOutL[i] = m_scratchSumL[i];
        broadcastOutR[i] = m_scratchSumR[i];
        monitorOutL[i] = m_scratchSumL[i];
        monitorOutR[i] = m_scratchSumR[i];
    }

    // Decay peak hold indicators
    m_vocalChannel.decayPeakHold(0.2f);
    m_fxChannel.decayPeakHold(0.2f);
    m_musicChannel.decayPeakHold(0.2f);
    m_masterChannel.decayPeakHold(0.2f);
}

} // namespace OnLive::DSP
