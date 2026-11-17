# OnLive - Mobile Karaoke DAW & Live Streaming Engine

A high-performance, studio-grade digital audio workstation (DAW) and live karaoke console designed for live streaming on TikTok, YouTube Live, and Instagram using a **2-Phone + Soundcard OTG** setup.

---

## 🚀 Key Features

- **Split Screen Mobile Layout**:
  - **Top Section**: 16:9 YouTube Karaoke Player with Lyrics & Quick Key Transpose.
  - **Middle Section**: 1-Tap Factory Presets (`Pop Studio`, `Ballad`, `Acoustic`, `Dangdut`, `RnB`, `Sapa`).
  - **Bottom Section**: 4 Draggable Channel Faders (`Vocal`, `FX Macro`, `Music`, `Master`) with integrated 24-Segment LED dBFS Meters.
  - **Pro Drawer**: Swipe-up modal unlocking 4/7/31-Band Graphic EQ (*Finger-Draw Curve*), Pro-Q Dynamic Sidechain, and Modular Insert Rack.
- **Vocal Insert Rack**:
  - High-Pass Filter (85 Hz)
  - Adaptive Noise Gate
  - Split-Band De-Esser (5.5 - 8.5 kHz)
  - 7-Band Parametric Stage EQ
  - Studio Opto/VCA Vocal Compressor
  - Broadcast True-Peak Limiter (-1.0 dBTP)
- **Music Conditioning Engine**:
  - Sub-Harmonic Bass Generator (MaxxBass style)
  - Dynamic Vocal Pocket Carver (Dips 1.5 - 3.5 kHz only when vocal singing is detected)
  - Wideband Sidechain Ducker (Smoothly ducks music by 2-3 dB during speech)
- **4-Bus Parallel FX Matrix**:
  - Damped Algorithmic Reverb (Pre-Delay & Low-Cut)
  - Ping-Pong / Tap-Tempo Delay
  - Scale/Key-Locked Intelligent Harmonizer
  - Multi-Tap Dimension Stereo Chorus

---

## 📁 Repository Structure

```
OnLive/
├── CMakeLists.txt                 # Master CMake build configuration
├── README.md
├── docs/                          # Architecture Blueprints & PRD
│   ├── technical_blueprint_architecture.md
│   ├── prd_live_karaoke_daw.md
│   └── agent_hard_rules_and_ui_ux_spec.md
├── src/
│   ├── dsp/                       # Core C++20 Real-Time Audio Engine
│   │   ├── include/               # Header definitions (Zero dynamic allocations)
│   │   └── src/                   # Implementation files
│   └── tests/                     # Verification test suite
│       └── test_dsp_engine.cpp
└── android/                       # Phase 1: Android Platform
    ├── app/
    │   ├── src/main/
    │   │   ├── AndroidManifest.xml
    │   │   ├── cpp/               # JNI C++ Bridge to Core DSP
    │   │   └── java/com/onlive/app/
    │   │       ├── audio/NativeAudioEngine.kt
    │   │       └── ui/MainActivity.kt
    └── ...
```

---

## 🛠️ Building & Verifying the Core Audio Engine

### Prerequisites
- Clang / GCC with C++20 support
- CMake 3.20+
- Ninja build system

### Build and Run Tests
```bash
cmake -B build -G Ninja
cmake --build build
./build/test_dsp_engine
```

---

## 📜 Documentation & Guidelines
- [Technical Blueprint Architecture](docs/technical_blueprint_architecture.md)
- [Product Requirements Document (PRD)](docs/prd_live_karaoke_daw.md)
- [Agent Hard-Rules & UI/UX Design System Specification](docs/agent_hard_rules_and_ui_ux_spec.md)

