package com.prismmusic.prism_music

import android.media.audiofx.BassBoost
import android.media.audiofx.PresetReverb
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.prismmusic/audio_effects"
    private var bassBoost: BassBoost? = null
    private var reverbPreset: PresetReverb? = null
    private var audioSessionId: Int = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> {
                        audioSessionId = call.argument<Int>("audioSessionId") ?: 0
                        result.success(null)
                    }
                    "setBassBoost" -> {
                        val level = call.argument<Double>("level") ?: 0.5
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        setBassBoost(level, enabled)
                        result.success(null)
                    }
                    "setReverb" -> {
                        val preset = call.argument<String>("preset") ?: "NONE"
                        setReverb(preset)
                        result.success(null)
                    }
                    "release" -> {
                        releaseEffects()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun setBassBoost(level: Double, enabled: Boolean) {
        try {
            if (!enabled) {
                bassBoost?.enabled = false
                bassBoost?.release()
                bassBoost = null
                return
            }

            if (bassBoost == null && audioSessionId != 0) {
                bassBoost = BassBoost(0, audioSessionId)
            }

            // Convert 0.0-1.0 range to 0-1000 range for Android BassBoost API
            val strength = (level * 1000.0).toInt().toShort()
            bassBoost?.enabled = false
            bassBoost?.setStrength(strength)
            bassBoost?.enabled = true
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun setReverb(preset: String) {
        try {
            if (preset == "NONE") {
                reverbPreset?.enabled = false
                reverbPreset?.release()
                reverbPreset = null
                return
            }

            if (reverbPreset == null && audioSessionId != 0) {
                reverbPreset = PresetReverb(1, audioSessionId)
            }

            val presetValue: Short = when (preset) {
                "SMALLROOM" -> PresetReverb.PRESET_SMALLROOM
                "MEDIUMROOM" -> PresetReverb.PRESET_MEDIUMROOM
                "LARGEROOM" -> PresetReverb.PRESET_LARGEROOM
                "MEDIUMHALL" -> PresetReverb.PRESET_MEDIUMHALL
                "LARGEHALL" -> PresetReverb.PRESET_LARGEHALL
                "PLATE" -> PresetReverb.PRESET_PLATE
                else -> PresetReverb.PRESET_NONE
            }

            reverbPreset?.enabled = false
            reverbPreset?.preset = presetValue
            reverbPreset?.enabled = true
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun releaseEffects() {
        try {
            bassBoost?.enabled = false
            bassBoost?.release()
            bassBoost = null

            reverbPreset?.enabled = false
            reverbPreset?.release()
            reverbPreset = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        releaseEffects()
        super.onDestroy()
    }
}
