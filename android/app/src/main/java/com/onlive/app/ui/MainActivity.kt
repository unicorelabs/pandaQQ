package com.onlive.app.ui

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.onlive.app.audio.NativeAudioEngine

// Pro Studio Theme Color Palette
val StudioBackground = Color(0xFF121316)
val ChannelChassis = Color(0xFF1A1C22)
val AccentCyan = Color(0xFF00D2FF)
val AccentAmber = Color(0xFFFF9900)
val AccentPurple = Color(0xFF9D00FF)
val AccentRed = Color(0xFFFF1744)
val TextMuted = Color(0xFF8E94A0)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize Core C++ DSP Audio Engine
        NativeAudioEngine.initialize(48000.0f, 256)

        setContent {
            LiveKaraokeConsoleScreen()
        }
    }
}

@Composable
fun LiveKaraokeConsoleScreen() {
    var selectedPreset by remember { mutableStateOf(NativeAudioEngine.Preset.POP_STUDIO) }
    var isLiveLocked by remember { mutableStateOf(false) }

    // Channel volumes (in dB)
    var vocalVol by remember { mutableStateOf(0.0f) }
    var fxVol by remember { mutableStateOf(-6.0f) }
    var musicVol by remember { mutableStateOf(-3.0f) }
    var masterVol by remember { mutableStateOf(0.0f) }

    // Active Toggles
    var isAutoCarveActive by remember { mutableStateOf(true) }
    var isAutoTuneActive by remember { mutableStateOf(false) }

    // Quick Send FX & Booster Toggles
    var isReverbActive by remember { mutableStateOf(true) }
    var isDelayActive by remember { mutableStateOf(true) }
    var isHarmoniActive by remember { mutableStateOf(false) }
    var isSubBoosterActive by remember { mutableStateOf(true) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(StudioBackground)
    ) {
        // ========================================================
        // 1. TOP SECTION: YOUTUBE KARAOKE PLAYER (16:9 Aspect Ratio)
        // ========================================================
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(230.dp)
                .background(Color.Black),
            contentAlignment = Alignment.Center
        ) {
            // YouTube IFrame Player Placeholder
            Text(
                text = "▶ LAYAR YOUTUBE KARAOKE (LIRIK & VIDEO)",
                color = Color.White.copy(alpha = 0.6f),
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold
            )

            // Header Bar Floating Controls
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.TopCenter)
                    .padding(8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Button(
                    onClick = { /* Search Overlay Modal */ },
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Black.copy(alpha = 0.7f)),
                    shape = RoundedCornerShape(20.dp),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)
                ) {
                    Text("🔍 Cari Lagu Minus-One...", fontSize = 11.sp, color = Color.White)
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Key: 0", color = AccentAmber, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.width(8.dp))
                    Button(
                        onClick = { isLiveLocked = !isLiveLocked },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (isLiveLocked) AccentRed else Color.DarkGray
                        ),
                        shape = RoundedCornerShape(20.dp),
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp)
                    ) {
                        Text(if (isLiveLocked) "🔒 LOCKED" else "🔓 LIVE", fontSize = 10.sp, color = Color.White)
                    }
                }
            }
        }

        // ========================================================
        // 2. MIDDLE SECTION: 1-TAP FACTORY PRESETS
        // ========================================================
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            PresetButton("🎤 SAPA", selectedPreset == NativeAudioEngine.Preset.TALK_CHITCHAT, Modifier.weight(1f)) {
                selectedPreset = NativeAudioEngine.Preset.TALK_CHITCHAT
                NativeAudioEngine.loadPreset(it)
                isReverbActive = false
                isDelayActive = false
                isHarmoniActive = false
                isSubBoosterActive = false
            }
            PresetButton("✨ POP", selectedPreset == NativeAudioEngine.Preset.POP_STUDIO, Modifier.weight(1f)) {
                selectedPreset = NativeAudioEngine.Preset.POP_STUDIO
                NativeAudioEngine.loadPreset(it)
                isReverbActive = true
                isDelayActive = true
                isHarmoniActive = false
                isSubBoosterActive = true
            }
            PresetButton("🎸 AKUSTIK", selectedPreset == NativeAudioEngine.Preset.ACOUSTIC_WARM, Modifier.weight(1f)) {
                selectedPreset = NativeAudioEngine.Preset.ACOUSTIC_WARM
                NativeAudioEngine.loadPreset(it)
                isReverbActive = true
                isDelayActive = false
                isHarmoniActive = false
                isSubBoosterActive = false
            }
            PresetButton("💃 DANGDUT", selectedPreset == NativeAudioEngine.Preset.DANGDUT_MELAYU, Modifier.weight(1f)) {
                selectedPreset = NativeAudioEngine.Preset.DANGDUT_MELAYU
                NativeAudioEngine.loadPreset(it)
                isReverbActive = true
                isDelayActive = true
                isHarmoniActive = false
                isSubBoosterActive = true
            }
        }

        // ========================================================
        // 2B. QUICK FX SWITCH STRIP (TOMBOL CEPAT PENGAKTIF EFEK)
        // ========================================================
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 2.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            QuickFxPill(
                title = "✨ REVERB",
                isActive = isReverbActive,
                activeColor = AccentCyan,
                modifier = Modifier.weight(1f)
            ) {
                isReverbActive = !isReverbActive
                NativeAudioEngine.nativeSetReverbEnabled(isReverbActive)
            }

            QuickFxPill(
                title = "🔁 DELAY",
                isActive = isDelayActive,
                activeColor = Color(0xFF00E676),
                modifier = Modifier.weight(1f)
            ) {
                isDelayActive = !isDelayActive
                NativeAudioEngine.nativeSetDelayEnabled(isDelayActive)
            }

            QuickFxPill(
                title = "👥 HARMONI",
                isActive = isHarmoniActive,
                activeColor = AccentPurple,
                modifier = Modifier.weight(1f)
            ) {
                isHarmoniActive = !isHarmoniActive
                NativeAudioEngine.nativeSetHarmonizerEnabled(isHarmoniActive)
            }

            QuickFxPill(
                title = "🔊 SUB BASS",
                isActive = isSubBoosterActive,
                activeColor = AccentAmber,
                modifier = Modifier.weight(1f)
            ) {
                isSubBoosterActive = !isSubBoosterActive
                NativeAudioEngine.nativeSetSubBoosterEnabled(isSubBoosterActive)
            }
        }

        // ========================================================
        // 3. BOTTOM SECTION: 4 MAIN FADERS (DRAG-AND-DROP REORDERABLE)
        // ========================================================
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .padding(horizontal = 6.dp, vertical = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            // Channel 1: Vocal
            ChannelFaderStrip(
                title = "VOKAL",
                accentColor = AccentCyan,
                volumeDb = vocalVol,
                onVolumeChange = {
                    if (!isLiveLocked) {
                        vocalVol = it
                        NativeAudioEngine.nativeSetChannelVolume(0, it)
                    }
                },
                subButtonText = "MUTE",
                modifier = Modifier.weight(1f)
            )

            // Channel 2: FX Macro
            ChannelFaderStrip(
                title = "EFEK",
                accentColor = AccentPurple,
                volumeDb = fxVol,
                onVolumeChange = {
                    if (!isLiveLocked) {
                        fxVol = it
                        NativeAudioEngine.nativeSetChannelVolume(1, it)
                    }
                },
                subButtonText = if (isAutoTuneActive) "TUNE: ON" else "TUNE",
                subButtonActive = isAutoTuneActive,
                onSubButtonClick = { isAutoTuneActive = !isAutoTuneActive },
                modifier = Modifier.weight(1f)
            )

            // Channel 3: Music (YouTube)
            ChannelFaderStrip(
                title = "MUSIK",
                accentColor = AccentAmber,
                volumeDb = musicVol,
                onVolumeChange = {
                    if (!isLiveLocked) {
                        musicVol = it
                        NativeAudioEngine.nativeSetChannelVolume(2, it)
                    }
                },
                subButtonText = if (isAutoCarveActive) "CARVE: ON" else "CARVE",
                subButtonActive = isAutoCarveActive,
                onSubButtonClick = {
                    isAutoCarveActive = !isAutoCarveActive
                    NativeAudioEngine.nativeSetAutoCarve(isAutoCarveActive)
                },
                modifier = Modifier.weight(1f)
            )

            // Channel 4: Master Broadcast Out
            ChannelFaderStrip(
                title = "MASTER",
                accentColor = AccentRed,
                isMaster = true,
                volumeDb = masterVol,
                onVolumeChange = {
                    if (!isLiveLocked) {
                        masterVol = it
                        NativeAudioEngine.nativeSetChannelVolume(3, it)
                    }
                },
                subButtonText = "LIMITER",
                subButtonActive = true,
                modifier = Modifier.weight(1f)
            )
        }

        // Drawer Handle Banner (Swipe Up to Open Pro Studio)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color(0xFF1E2129))
                .padding(vertical = 4.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                "▲ USAP KE ATAS UNTUK BUKA STUDIO PRO (EQ 31-BAND & RACK INSERT)",
                color = TextMuted,
                fontSize = 10.sp,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

@Composable
fun QuickFxPill(
    title: String,
    isActive: Boolean,
    activeColor: Color,
    modifier: Modifier,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        colors = ButtonDefaults.buttonColors(
            containerColor = if (isActive) activeColor.copy(alpha = 0.25f) else ChannelChassis
        ),
        shape = RoundedCornerShape(6.dp),
        border = androidx.compose.foundation.BorderStroke(
            1.dp,
            if (isActive) activeColor else Color.DarkGray
        ),
        contentPadding = PaddingValues(horizontal = 2.dp, vertical = 4.dp),
        modifier = modifier.height(28.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            // Illuminated LED Dot
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .background(
                        if (isActive) activeColor else Color.Gray.copy(alpha = 0.4f),
                        androidx.compose.foundation.shape.CircleShape
                    )
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = title,
                color = if (isActive) Color.White else TextMuted,
                fontSize = 9.sp,
                fontWeight = if (isActive) FontWeight.Bold else FontWeight.Normal
            )
        }
    }
}

@Composable
fun PresetButton(title: String, isSelected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        colors = ButtonDefaults.buttonColors(
            containerColor = if (isSelected) AccentCyan else ChannelChassis
        ),
        shape = RoundedCornerShape(8.dp),
        contentPadding = PaddingValues(horizontal = 4.dp, vertical = 6.dp),
        modifier = modifier
    ) {
        Text(
            text = title,
            color = if (isSelected) Color.Black else Color.White,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
fun ChannelFaderStrip(
    title: String,
    accentColor: Color,
    volumeDb: Float,
    onVolumeChange: (Float) -> Unit,
    subButtonText: String,
    subButtonActive: Boolean = false,
    onSubButtonClick: () -> Unit = {},
    isMaster: Boolean = false,
    modifier: Modifier
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = ChannelChassis),
        shape = RoundedCornerShape(8.dp),
        modifier = modifier.fillMaxHeight()
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 4.dp, vertical = 6.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Channel Header Label
            Text(
                text = title,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                color = if (isMaster) AccentRed else accentColor
            )

            Text(
                text = "${String.format("%.1f", volumeDb)} dB",
                fontSize = 10.sp,
                color = TextMuted
            )

            // Fader & Integrated 24-Segment LED Meter
            Row(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(vertical = 4.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Vertical Touch Fader Slider Track
                Box(
                    modifier = Modifier
                        .width(28.dp)
                        .fillMaxHeight()
                        .background(Color.Black.copy(alpha = 0.5f), RoundedCornerShape(14.dp))
                        .pointerInput(Unit) {
                            detectDragGestures { change, dragAmount ->
                                change.consume()
                                val deltaDb = -dragAmount.y * 0.2f
                                val newDb = (volumeDb + deltaDb).coerceIn(-48.0f, 6.0f)
                                onVolumeChange(newDb)
                            }
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(0.9f)
                            .height(24.dp)
                            .background(
                                if (isMaster) Color.White else accentColor,
                                RoundedCornerShape(6.dp)
                            )
                    )
                }

                Spacer(modifier = Modifier.width(4.dp))

                // Integrated 24-Segment LED Meter
                Column(
                    modifier = Modifier
                        .width(8.dp)
                        .fillMaxHeight()
                        .background(Color.Black, RoundedCornerShape(4.dp))
                        .padding(1.dp),
                    verticalArrangement = Arrangement.SpaceBetween
                ) {
                    repeat(12) { idx ->
                        val segColor = when {
                            idx < 2 -> AccentRed       // Overload
                            idx < 5 -> AccentAmber     // Sweet Spot
                            else -> Color(0xFF00E676) // Safe Green
                        }
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(3.dp)
                                .background(segColor, RoundedCornerShape(1.dp))
                        )
                    }
                }
            }

            // Quick Toggle Button at bottom
            Button(
                onClick = onSubButtonClick,
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (subButtonActive) accentColor else Color.Black.copy(alpha = 0.4f)
                ),
                shape = RoundedCornerShape(6.dp),
                contentPadding = PaddingValues(0.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(24.dp)
            ) {
                Text(
                    text = subButtonText,
                    fontSize = 9.sp,
                    color = if (subButtonActive) Color.Black else Color.White,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

