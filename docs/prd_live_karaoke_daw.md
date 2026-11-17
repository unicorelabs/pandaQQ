# PRODUCT REQUIREMENTS DOCUMENT (PRD)
## Project: Live Karaoke Mobile DAW & Broadcast Suite
**Version:** 1.0.0  
**Status:** Approved for Development  
**Product Category:** Pro-Audio Mobile Workstation & Live Streaming Utility  

---

## 1. Executive Summary & Objective

The objective of this application is to turn an Android smartphone (and subsequently iOS/macOS/Windows) into a professional, zero-latency digital audio workstation (DAW) and live karaoke console. It allows live performers on TikTok, YouTube Live, and Instagram to sing with studio-grade vocal dynamic processing, automated backing-track carving, and rich studio effects within a single intuitive interface.

---

## 2. Target Users & Personas

1. **The TikTok Live Singer / Creator (Beginner to Intermediate)**: Wants to sing karaoke directly from YouTube, wants their voice to sound like a studio album immediately without learning complex audio engineering terms.
2. **The Professional Busker / Musician (Advanced)**: Needs precision control over 31-band EQ, fine-tuned compression, manual delay tap-tempo, custom key-locked harmonizer, and separate headphone cue mixes.

---

## 3. Core Hardware & Operating Topography (2-Phone Paradigm)

```
[ Microphone ] ──► [ Audio Interface / Soundcard ] ◄──► [ HP 1: App (YouTube + DAW Engine) ]
                           │
                           ├──► [ HP 2: TikTok Live App (Camera + Chat) ]
                           └──► [ Wired IEM Earphones (Zero Latency Monitoring) ]
```
- **Phone 1 (Host App)**: Runs YouTube player, processes DSP Audio Engine, manages live mixer controls. Connected to Soundcard via USB OTG.
- **Phone 2 (Broadcast Client)**: Runs official TikTok application for video streaming and live chat reading. Receives pure stereo mix from Soundcard Broadcast Out.

---

## 4. Detailed Feature Specifications

### 4.1 Screen Layout & Partitioning (Phone 1 - Android Optimized)
- **Top Section (38% Screen Height)**: 
  - Embedded YouTube Player with Video & Lyrics (Standard 16:9 aspect ratio, ~220 dp).
  - Quick Search bar with overlay modal (anti-push layout when virtual keyboard pops up).
  - Digital Pitch Shift / Key Transpose buttons (`-3` to `+3` semitones) and `[🔒 LIVE LOCK]`.
- **Middle Section (12% Screen Height)**:
  - 1-Tap Ready-to-Use Factory Preset Bar: `[🎤 SAPA]` | `[✨ POP/BALLAD]` | `[🎸 AKUSTIK]` | `[💃 DANGDUT]` | `[🔥 RnB]`.
- **Bottom Section (50% Screen Height - Live Fader Console)**:
  - **4 Main Persistent Faders (Drag-and-Drop Reorderable)**:
    1. **`[VOKAL]`**: Input volume mic dengan 24-segment LED meter, Mute (tap), Solo (long press).
    2. **`[EFEK VOKAL]`**: Macro fader Reverb & Delay siap pakai, tombol Auto-Tune.
    3. **`[MUSIK]`**: Volume YouTube dengan Auto-Carve dynamic sidechain switch.
    4. **`[MASTER]`**: Output broadcast level ke TikTok dengan True-Peak Limiter dan Master VU meter.
  - **Drag-and-Drop Ergonomics**: Pengguna dapat menahan (*long-press*) header fader strip dan menggesernya secara horizontal ke kiri/kanan (sangat ergonomis untuk penyanyi kidal vs tangan kanan).
  - **Swipe-Up Pro Drawer**: Usap dari bawah ke atas untuk mengakses 4/7/31-Band EQ, Pro-Q dynamic matrix, dan Modular Insert Rack.

### 4.2 Channel Strip Controls & Safety Mechanism
Every audio channel (Vocal, Music, SFX, Master) contains:
1. **Vertical Fader**: Smooth logarithmic volume taper (-inf to +6 dB).
2. **Integrated 24-Segment LED dBFS Meter**:
   - Green: -inf to -12 dBFS (Safe Signal).
   - Yellow/Amber: -12 to -2 dBFS (Nominal Broadcast Sweet Spot).
   - Red: -2 to 0 dBFS (Overload Warning).
   - Peak Hold Indicator: Retains maximum peak level indicator bar for 2.0 seconds.
3. **MUTE Button**:
   - Single Tap activation.
   - Visual State: Pulsing bright red LED indicator.
4. **SOLO Button (Safety Guard)**:
   - **Long-Press Activation (0.8s hold required)** to prevent accidental live stream drops.
   - Dual-logic routing: Operates in **CUE/PFL Mode** (only isolates audio inside performer's IEM headphones, leaving live stream audience intact).
   - Visual State: Glowing amber gold LED indicator.
5. **PAN Potentiometer**:
   - Center-detented rotary knob with numeric display (`L100` ... `C` ... `R100`).

### 4.3 Default Insert Rack vs. Pro Expansion
- **Factory Default Insert Chain (Always present on fresh launch)**:
  1. *Adaptive Noise Gate*: Suppresses ambient fan and AC noise.
  2. *De-Esser*: Tames 6-8kHz vocal sibilance.
  3. *Pro-Q Style Dynamic EQ*: Shapes fundamental tone.
  4. *Opto Vocal Compressor*: Transparent gain leveling with active Gain Reduction (GR) meter.
  5. *Peak Limiter*: Prevents digital clipping.
- **Pro User Insert Rack Features**:
  - Ability to add additional inserts (`[+ Add Plugin Slot]`).
  - Drag-and-drop to reorder signal chain (e.g., placing Compressor before EQ).
  - Module bypass toggle on every insert.
  - Real-time DSP CPU Load Meter (`0% - 100%`) in the top navigation.

### 4.4 EQ Modes (4 Selectable Options)
1. **4-Band Semi-Parametric**: Low Shelf, Low-Mid, High-Mid, High Shelf.
2. **7-Band Graphic**: Fixed stage frequencies (63Hz, 160Hz, 400Hz, 1kHz, 2.5kHz, 6.3kHz, 16kHz).
3. **31-Band ISO 1/3-Octave Graphic EQ**:
   - Supports **Finger-Draw Curve Gesture**: User drags a finger across the screen and all 31 sliders interpolate to match the curve.
   - 3-bank quick zoom: Low (20-160Hz), Mid (200-2.5kHz), High (3.15k-20kHz).
4. **Pro-Q Style Dynamic Sidechain Node**:
   - Band frequency linking between Vocal and Music.
   - "Vocal Pocket Carve": Music automatically attenuates 1.5 - 3.5kHz only when vocal singing is detected.

### 4.5 Send FX Matrix (4 Core Buses)
1. **Reverb Engine**: Hall, Plate, Room, Church algorithms; Decay (0.5s - 10s), Pre-delay (0 - 150ms), High/Low Cut filters.
2. **Delay Engine**: Digital Clean, Tape Echo, Ping-Pong; Tap-Tempo sync, Note divisions (1/4, 1/8, Dotted), Feedback, Damping.
3. **Intelligent Harmonizer**: Monophonic pitch tracking with PSOLA synthesis; Scale/Key lock (Major/Minor C through B); Interval selection (+3rd, -3rd, +5th, Octave Up/Down); Humanize Detune.
4. **Dimension Chorus**: Modulation Rate, Depth, Stereo Spread Width (0 - 200%).

### 4.6 1-Tap Quick Presets & User Preset Vault
- Factory 1-Tap Presets: `[🎤 TALK / SAPA]`, `[✨ BALLAD]`, `[🎸 ACOUSTIC]`, `[🔥 RnB]`, `[💃 DANGDUT]`.
- User Preset Management: `[💾 Save Current Mix]`, rename, overwrite, and export to backup file / QR code.

---

## 5. Non-Functional Requirements

- **Audio Round-Trip Latency**: Must remain $< 15 \text{ ms}$ (Android) and $< 7 \text{ ms}$ (iOS/macOS).
- **UI Render Performance**: Solid 60 FPS under continuous audio meter updates.
- **Safety Mechanism**: "Live Lock Mode" toggle to disable accidental touch manipulation during live broadcasting.
