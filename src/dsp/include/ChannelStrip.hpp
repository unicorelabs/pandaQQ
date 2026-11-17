#pragma once

#include <atomic>
#include <cmath>
#include <algorithm>

namespace OnLive::DSP {

/**
 * @brief Channel Strip state and signal routing.
 * Stores lock-free atomic parameters for thread-safe UI communication.
 */
class ChannelStrip {
public:
    ChannelStrip(const char* name = "Channel") : m_name(name) {
        m_faderGain.store(1.0f); // 0 dB
        m_pan.store(0.0f);       // Center
        m_isMuted.store(false);
        m_isSolo.store(false);

        for (auto& send : m_sendLevels) {
            send.store(0.0f);
        }

        m_peakMeterDb.store(-96.0f);
        m_peakHoldDb.store(-96.0f);
    }

    void setVolumeDb(float volumeDb) noexcept {
        const float linear = (volumeDb <= -60.0f) ? 0.0f : std::pow(10.0f, volumeDb / 20.0f);
        m_faderGain.store(linear, std::memory_order_relaxed);
    }

    float getVolumeDb() const noexcept {
        const float linear = m_faderGain.load(std::memory_order_relaxed);
        return (linear <= 1e-4f) ? -96.0f : 20.0f * std::log10(linear);
    }

    void setPan(float pan) noexcept {
        m_pan.store(std::clamp(pan, -1.0f, 1.0f), std::memory_order_relaxed);
    }

    float getPan() const noexcept {
        return m_pan.load(std::memory_order_relaxed);
    }

    void setMute(bool mute) noexcept {
        m_isMuted.store(mute, std::memory_order_relaxed);
    }

    bool isMuted() const noexcept {
        return m_isMuted.load(std::memory_order_relaxed);
    }

    void setSolo(bool solo) noexcept {
        m_isSolo.store(solo, std::memory_order_relaxed);
    }

    bool isSolo() const noexcept {
        return m_isSolo.load(std::memory_order_relaxed);
    }

    void setSendLevel(size_t index, float level) noexcept {
        if (index < 4) {
            m_sendLevels[index].store(std::clamp(level, 0.0f, 1.5f), std::memory_order_relaxed);
        }
    }

    float getSendLevel(size_t index) const noexcept {
        return (index < 4) ? m_sendLevels[index].load(std::memory_order_relaxed) : 0.0f;
    }

    // Process mono buffer to stereo with volume and pan laws
    void process(const float* monoIn, float* stereoOutL, float* stereoOutR, size_t numFrames) noexcept {
        const bool muted = m_isMuted.load(std::memory_order_relaxed);
        const float gain = muted ? 0.0f : m_faderGain.load(std::memory_order_relaxed);
        const float pan = m_pan.load(std::memory_order_relaxed);

        // Constant power pan law (3dB center dip)
        const float panAngle = (pan + 1.0f) * 0.5f * (3.14159265f * 0.5f);
        const float gainL = gain * std::cos(panAngle) * 1.4142f;
        const float gainR = gain * std::sin(panAngle) * 1.4142f;

        float maxPeak = 0.0f;

        for (size_t i = 0; i < numFrames; ++i) {
            const float s = monoIn[i];
            const float sAbs = std::abs(s);
            if (sAbs > maxPeak) maxPeak = sAbs;

            stereoOutL[i] += s * gainL;
            stereoOutR[i] += s * gainR;
        }

        // Update meter
        const float currentPeakDb = (maxPeak > 1e-5f) ? 20.0f * std::log10(maxPeak * gain) : -96.0f;
        m_peakMeterDb.store(currentPeakDb, std::memory_order_relaxed);

        float currentHold = m_peakHoldDb.load(std::memory_order_relaxed);
        if (currentPeakDb > currentHold) {
            m_peakHoldDb.store(currentPeakDb, std::memory_order_relaxed);
        }
    }

    float getPeakMeterDb() const noexcept {
        return m_peakMeterDb.load(std::memory_order_relaxed);
    }

    float getPeakHoldDb() const noexcept {
        return m_peakHoldDb.load(std::memory_order_relaxed);
    }

    void decayPeakHold(float decayAmountDb) noexcept {
        float hold = m_peakHoldDb.load(std::memory_order_relaxed);
        hold = std::max(-96.0f, hold - decayAmountDb);
        m_peakHoldDb.store(hold, std::memory_order_relaxed);
    }

    const char* getName() const noexcept { return m_name; }

private:
    const char* m_name;
    std::atomic<float> m_faderGain;
    std::atomic<float> m_pan;
    std::atomic<bool> m_isMuted;
    std::atomic<bool> m_isSolo;
    std::array<std::atomic<float>, 4> m_sendLevels; // Reverb, Delay, Harm, Chorus

    std::atomic<float> m_peakMeterDb;
    std::atomic<float> m_peakHoldDb;
};

} // namespace OnLive::DSP
