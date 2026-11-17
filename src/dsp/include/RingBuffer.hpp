#pragma once

#include <atomic>
#include <cstddef>
#include <array>
#include <optional>

namespace OnLive::DSP {

/**
 * @brief Lock-Free Single-Producer Single-Consumer (SPSC) Ring Buffer.
 * Used for completely non-blocking, real-time safe communication between UI and Audio Threads.
 */
template <typename T, size_t Capacity = 1024>
class SpscRingBuffer {
    static_assert((Capacity & (Capacity - 1)) == 0, "Capacity must be a power of 2 for fast masking");
public:
    SpscRingBuffer() : m_head(0), m_tail(0) {}

    bool push(const T& item) noexcept {
        const size_t currentTail = m_tail.load(std::memory_order_relaxed);
        const size_t currentHead = m_head.load(std::memory_order_acquire);

        if ((currentTail - currentHead) >= Capacity) {
            return false; // Buffer full
        }

        m_buffer[currentTail & (Capacity - 1)] = item;
        m_tail.store(currentTail + 1, std::memory_order_release);
        return true;
    }

    std::optional<T> pop() noexcept {
        const size_t currentHead = m_head.load(std::memory_order_relaxed);
        const size_t currentTail = m_tail.load(std::memory_order_acquire);

        if (currentHead == currentTail) {
            return std::nullopt; // Buffer empty
        }

        T item = m_buffer[currentHead & (Capacity - 1)];
        m_head.store(currentHead + 1, std::memory_order_release);
        return item;
    }

    bool isEmpty() const noexcept {
        return m_head.load(std::memory_order_relaxed) == m_tail.load(std::memory_order_relaxed);
    }

    size_t size() const noexcept {
        const size_t head = m_head.load(std::memory_order_relaxed);
        const size_t tail = m_tail.load(std::memory_order_relaxed);
        return (tail >= head) ? (tail - head) : 0;
    }

private:
    std::array<T, Capacity> m_buffer;
    alignas(64) std::atomic<size_t> m_head;
    alignas(64) std::atomic<size_t> m_tail;
};

} // namespace OnLive::DSP
