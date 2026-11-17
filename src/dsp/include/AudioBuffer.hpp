#pragma once

#include <cstddef>
#include <algorithm>
#include <cstring>

namespace OnLive::DSP {

/**
 * @brief Fixed-capacity, multi-channel float audio buffer.
 * Pre-allocated to guarantee ZERO dynamic allocations on the real-time audio thread.
 */
template <size_t MaxChannels = 2, size_t MaxFrames = 1024>
class AudioBuffer {
public:
    AudioBuffer() : m_numChannels(MaxChannels), m_numFrames(0) {
        clear();
    }

    void setSize(size_t channels, size_t frames) {
        m_numChannels = std::min(channels, MaxChannels);
        m_numFrames = std::min(frames, MaxFrames);
    }

    size_t getNumChannels() const noexcept { return m_numChannels; }
    size_t getNumFrames() const noexcept { return m_numFrames; }

    float* getWritePointer(size_t channel) noexcept {
        return m_data[channel];
    }

    const float* getReadPointer(size_t channel) const noexcept {
        return m_data[channel];
    }

    void clear() noexcept {
        for (size_t c = 0; c < MaxChannels; ++c) {
            std::memset(m_data[c], 0, sizeof(float) * MaxFrames);
        }
    }

    void copyFrom(const AudioBuffer& source) noexcept {
        m_numChannels = source.m_numChannels;
        m_numFrames = source.m_numFrames;
        for (size_t c = 0; c < m_numChannels; ++c) {
            std::memcpy(m_data[c], source.m_data[c], sizeof(float) * m_numFrames);
        }
    }

    void addFrom(const AudioBuffer& source, float gain = 1.0f) noexcept {
        size_t channels = std::min(m_numChannels, source.m_numChannels);
        size_t frames = std::min(m_numFrames, source.m_numFrames);
        for (size_t c = 0; c < channels; ++c) {
            const float* src = source.getReadPointer(c);
            float* dst = getWritePointer(c);
            for (size_t i = 0; i < frames; ++i) {
                dst[i] += src[i] * gain;
            }
        }
    }

    void applyGain(float gain) noexcept {
        for (size_t c = 0; c < m_numChannels; ++c) {
            float* dst = getWritePointer(c);
            for (size_t i = 0; i < m_numFrames; ++i) {
                dst[i] *= gain;
            }
        }
    }

private:
    alignas(64) float m_data[MaxChannels][MaxFrames];
    size_t m_numChannels;
    size_t m_numFrames;
};

} // namespace OnLive::DSP

