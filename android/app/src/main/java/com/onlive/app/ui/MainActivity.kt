package com.onlive.app.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.onlive.app.R
import com.onlive.app.audio.NativeAudioEngine
import kotlinx.coroutines.delay

// Pro Studio Theme Color Palette
val StudioBackground = Color(0xFF121316)
val ChannelChassis = Color(0xFF1A1C22)
val AccentCyan = Color(0xFF00D2FF)
val AccentAmber = Color(0xFFFF9900)
val AccentPurple = Color(0xFF9D00FF)
val AccentRed = Color(0xFFFF1744)
val AccentPink = Color(0xFFFF4081)
val TextMuted = Color(0xFF8E94A0)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize Core C++ DSP Audio Engine
        NativeAudioEngine.initialize(48000.0f, 256)

        setContent {
            var showSplash by remember { mutableStateOf(true) }

            LaunchedEffect(Unit) {
                delay(2200) // Display splash screen for 2.2 seconds
                showSplash = false
            }

            Box(modifier = Modifier.fillMaxSize()) {
                LiveKaraokeConsoleScreen()

                AnimatedVisibility(
                    visible = showSplash,
                    enter = fadeIn(),
                    exit = fadeOut()
                ) {
                    PandaSplashScreen(onDismiss = { showSplash = false })
                }
            }
        }
    }
}

/**
 * ========================================================
 * SPLASH SCREEN: PANDA HEADPHONE LOGO & BRANDING
 * ========================================================
 */
@Composable
fun PandaSplashScreen(onDismiss: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(Color(0xFF0A0B0E), Color(0xFF161820), Color(0xFF0A0B0E))
                )
            )
            .clickable { onDismiss() },
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.padding(24.dp)
        ) {
            // Glowing Circular Border around Panda Icon
            Box(
                modifier = Modifier
                    .size(140.dp)
                    .clip(CircleShape)
                    .border(
                        3.dp,
                        Brush.sweepGradient(
                            colors = listOf(AccentCyan, AccentAmber, AccentPurple, AccentCyan)
                        ),
                        CircleShape
                    )
                    .background(Color(0xFF14161D)),
                contentAlignment = Alignment.Center
            ) {
                Image(
                    painter = painterResource(id = R.drawable.ic_panda_logo),
                    contentDescription = "Panda QQ Logo",
                    modifier = Modifier
                        .size(125.dp)
                        .clip(CircleShape)
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            // App Title
            Text(
                text = "Panda QQ",
                fontSize = 32.sp,
                fontWeight = FontWeight.ExtraBold,
                color = Color.White,
                letterSpacing = 2.sp
            )

            // Subtitle
            Text(
                text = "LIVE KARAOKE DAW & BROADCAST SUITE",
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                color = AccentCyan,
                letterSpacing = 1.5.sp,
                modifier = Modifier.padding(top = 4.dp)
            )

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = "Studio Sound for TikTok • Zero Latency • DSP Engine",
                fontSize = 10.sp,
                color = TextMuted
            )

            Spacer(modifier = Modifier.height(36.dp))

            // Loading Indicator
            CircularProgressIndicator(
                color = AccentAmber,
                strokeWidth = 2.dp,
                modifier = Modifier.size(24.dp)
            )

            Spacer(modifier = Modifier.height(12.dp))

            Text(
                text = "Memuat Preset Studio & DSP...",
                fontSize = 10.sp,
                color = TextMuted
            )
        }

        // Version & Developer credit at bottom
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(bottom = 20.dp),
            contentAlignment = Alignment.BottomCenter
        ) {
            Text(
                text = "v1.0.0 Pro Broadcast Edition",
                fontSize = 9.sp,
                color = TextMuted.copy(alpha = 0.6f)
            )
        }
    }
}

/**
 * ========================================================
 * MAIN CONSOLE SCREEN
 * ========================================================
 */
@Composable
fun LiveKaraokeConsoleScreen() {
    val context = LocalContext.current

    var selectedPreset by remember { mutableStateOf(NativeAudioEngine.Preset.POP_STUDIO) }
    var isLiveLocked by remember { mutableStateOf(false) }
    var showDonationDialog by remember { mutableStateOf(false) }

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

    if (showDonationDialog) {
        DonationDialog(onDismiss = { showDonationDialog = false })
    }

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
                    .padding(horizontal = 8.dp, vertical = 6.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    // Panda QQ Logo & Branding
                    Text("🐼", fontSize = 18.sp)
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "Panda QQ",
                        color = Color.White,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.ExtraBold
                    )

                    Spacer(modifier = Modifier.width(8.dp))

                    // DONATION BUTTON (Pink / Red Heart Glow)
                    Button(
                        onClick = { showDonationDialog = true },
                        colors = ButtonDefaults.buttonColors(containerColor = AccentPink.copy(alpha = 0.85f)),
                        shape = RoundedCornerShape(16.dp),
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                        modifier = Modifier.height(26.dp)
                    ) {
                        Text("💖 Donasi", fontSize = 10.sp, color = Color.White, fontWeight = FontWeight.Bold)
                    }
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Button(
                        onClick = {
                            Toast.makeText(context, "Pencarian lagu karaoke aktif!", Toast.LENGTH_SHORT).show()
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = Color.Black.copy(alpha = 0.7f)),
                        shape = RoundedCornerShape(16.dp),
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                        modifier = Modifier.height(26.dp)
                    ) {
                        Text("🔍 Cari Lagu", fontSize = 9.sp, color = Color.White)
                    }

                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Key: 0", color = AccentAmber, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.width(6.dp))
                    Button(
                        onClick = { isLiveLocked = !isLiveLocked },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (isLiveLocked) AccentRed else Color.DarkGray
                        ),
                        shape = RoundedCornerShape(16.dp),
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                        modifier = Modifier.height(26.dp)
                    ) {
                        Text(if (isLiveLocked) "🔒" else "🔓 LIVE", fontSize = 9.sp, color = Color.White)
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
                NativeAudioEngine.loadPreset(NativeAudioEngine.Preset.TALK_CHITCHAT)
                isReverbActive = false
                isDelayActive = false
                isHarmoniActive = false
                isSubBoosterActive = false
            }
            PresetButton("✨ POP", selectedPreset == NativeAudioEngine.Preset.POP_STUDIO, Modifier.weight(1f)) {
                selectedPreset = NativeAudioEngine.Preset.POP_STUDIO
                NativeAudioEngine.loadPreset(NativeAudioEngine.Preset.POP_STUDIO)
                isReverbActive = true
                isDelayActive = true
                isHarmoniActive = false
                isSubBoosterActive = true
            }
            PresetButton("🎸 AKUSTIK", selectedPreset == NativeAudioEngine.Preset.ACOUSTIC_WARM, Modifier.weight(1f)) {
                selectedPreset = NativeAudioEngine.Preset.ACOUSTIC_WARM
                NativeAudioEngine.loadPreset(NativeAudioEngine.Preset.ACOUSTIC_WARM)
                isReverbActive = true
                isDelayActive = false
                isHarmoniActive = false
                isSubBoosterActive = false
            }
            PresetButton("💃 DANGDUT", selectedPreset == NativeAudioEngine.Preset.DANGDUT_MELAYU, Modifier.weight(1f)) {
                selectedPreset = NativeAudioEngine.Preset.DANGDUT_MELAYU
                NativeAudioEngine.loadPreset(NativeAudioEngine.Preset.DANGDUT_MELAYU)
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

/**
 * ========================================================
 * DIALOG DONASI: DANA, GOPAY, OVO (082116929992)
 * ========================================================
 */
@Composable
fun DonationDialog(onDismiss: () -> Unit) {
    val context = LocalContext.current
    val donationNumber = "082116929992"

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF1C1E26)),
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp)
        ) {
            Column(
                modifier = Modifier.padding(18.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // Header
                Text(
                    text = "💖 Dukung Panda QQ",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = Color.White
                )

                Text(
                    text = "Bantu aplikasi ini agar tetap gratis, bebas iklan, dan terus berkembang untuk para musisi live streaming!",
                    fontSize = 11.sp,
                    color = TextMuted,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 6.dp, bottom = 14.dp)
                )

                // Box Nomor E-Wallet
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color(0xFF121318), RoundedCornerShape(10.dp))
                        .border(1.dp, AccentAmber.copy(alpha = 0.5f), RoundedCornerShape(10.dp))
                        .padding(12.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = "NOMOR E-WALLET (DANA / GOPAY / OVO):",
                            fontSize = 9.sp,
                            color = AccentAmber,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = donationNumber,
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Black,
                            color = Color.White,
                            letterSpacing = 1.sp,
                            modifier = Modifier.padding(vertical = 4.dp)
                        )
                        Text(
                            text = "a/n Panda QQ Support",
                            fontSize = 10.sp,
                            color = TextMuted
                        )
                    }
                }

                Spacer(modifier = Modifier.height(14.dp))

                // Tombol Salin Nomor
                Button(
                    onClick = {
                        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        val clip = ClipData.newPlainText("Donasi Panda QQ", donationNumber)
                        clipboard.setPrimaryClip(clip)
                        Toast.makeText(context, "Nomor $donationNumber berhasil disalin!", Toast.LENGTH_SHORT).show()
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = AccentCyan),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("📋 Salin Nomor E-Wallet", color = Color.Black, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                }

                Spacer(modifier = Modifier.height(6.dp))

                // Tombol Direct DANA Link
                Button(
                    onClick = {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://link.dana.id/"))
                        try {
                            context.startActivity(intent)
                        } catch (e: Exception) {
                            Toast.makeText(context, "Membuka DANA...", Toast.LENGTH_SHORT).show()
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF118EEA)), // DANA Blue
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("📱 Buka Aplikasi DANA", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                }

                Spacer(modifier = Modifier.height(6.dp))

                // Tombol Konfirmasi WhatsApp
                Button(
                    onClick = {
                        val waUrl = "https://wa.me/6282116929992?text=Halo%20Admin%20Panda%20QQ%2C%20saya%20sudah%20mengirimkan%20donasi%20dukungan."
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(waUrl))
                        try {
                            context.startActivity(intent)
                        } catch (e: Exception) {
                            Toast.makeText(context, "Tidak dapat membuka WhatsApp", Toast.LENGTH_SHORT).show()
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF25D366)), // WA Green
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("💬 Konfirmasi via WhatsApp", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                }

                Spacer(modifier = Modifier.height(8.dp))

                TextButton(onClick = onDismiss) {
                    Text("Tutup", color = TextMuted, fontSize = 11.sp)
                }
            }
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
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .background(
                        if (isActive) activeColor else Color.Gray.copy(alpha = 0.4f),
                        CircleShape
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

            Row(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(vertical = 4.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
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
                            idx < 2 -> AccentRed
                            idx < 5 -> AccentAmber
                            else -> Color(0xFF00E676)
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
