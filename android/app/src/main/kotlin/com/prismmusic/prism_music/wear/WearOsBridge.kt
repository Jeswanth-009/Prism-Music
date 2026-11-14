package com.prismmusic.prism_music.wear

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native bridge for Wear OS Companion communication.
 * Enables smartwatches to control playback and receive playback updates.
 */
class WearOsBridge(private val context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "com.prismmusic/wear_os")
    private var isReceiverRegistered = false

    companion object {
        const val ACTION_PLAY = "com.prismmusic.wear.ACTION_PLAY"
        const val ACTION_PAUSE = "com.prismmusic.wear.ACTION_PAUSE"
        const val ACTION_TOGGLE_PLAY = "com.prismmusic.wear.ACTION_TOGGLE_PLAY"
        const val ACTION_NEXT = "com.prismmusic.wear.ACTION_NEXT"
        const val ACTION_PREVIOUS = "com.prismmusic.wear.ACTION_PREVIOUS"
        const val ACTION_SEEK = "com.prismmusic.wear.ACTION_SEEK"
        const val ACTION_SET_VOLUME = "com.prismmusic.wear.ACTION_SET_VOLUME"
        const val STATUS_UPDATE = "com.prismmusic.wear.STATUS_UPDATE"

        var activeBridge: WearOsBridge? = null
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            intent?.action?.let { action ->
                when (action) {
                    ACTION_PLAY -> channel.invokeMethod("play", null)
                    ACTION_PAUSE -> channel.invokeMethod("pause", null)
                    ACTION_TOGGLE_PLAY -> channel.invokeMethod("togglePlay", null)
                    ACTION_NEXT -> channel.invokeMethod("next", null)
                    ACTION_PREVIOUS -> channel.invokeMethod("previous", null)
                    ACTION_SEEK -> {
                        val pos = intent.getLongExtra("positionMs", 0L)
                        channel.invokeMethod("seek", mapOf("positionMs" to pos))
                    }
                    ACTION_SET_VOLUME -> {
                        val vol = intent.getDoubleExtra("volume", 1.0)
                        channel.invokeMethod("setVolume", mapOf("volume" to vol))
                    }
                    else -> {}
                }
            }
        }
    }

    init {
        activeBridge = this
        channel.setMethodCallHandler(this)
        registerReceiver()
    }

    fun registerReceiver() {
        if (!isReceiverRegistered) {
            val filter = IntentFilter().apply {
                addAction(ACTION_PLAY)
                addAction(ACTION_PAUSE)
                addAction(ACTION_TOGGLE_PLAY)
                addAction(ACTION_NEXT)
                addAction(ACTION_PREVIOUS)
                addAction(ACTION_SEEK)
                addAction(ACTION_SET_VOLUME)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                context.registerReceiver(receiver, filter)
            }
            isReceiverRegistered = true
        }
    }

    fun unregisterReceiver() {
        if (isReceiverRegistered) {
            try {
                context.unregisterReceiver(receiver)
            } catch (_: Exception) {}
            isReceiverRegistered = false
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isCompanionAvailable" -> {
                result.success(true)
            }
            "updatePlaybackState" -> {
                val title = call.argument<String>("title") ?: ""
                val artist = call.argument<String>("artist") ?: ""
                val durationMs = call.argument<Number>("durationMs")?.toLong() ?: 0L
                val positionMs = call.argument<Number>("positionMs")?.toLong() ?: 0L
                val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                val artworkUrl = call.argument<String>("artworkUrl") ?: ""

                // Broadcast state to Wear OS smartwatch listeners
                val broadcastIntent = Intent(STATUS_UPDATE).apply {
                    setPackage(context.packageName)
                    putExtra("title", title)
                    putExtra("artist", artist)
                    putExtra("durationMs", durationMs)
                    putExtra("positionMs", positionMs)
                    putExtra("isPlaying", isPlaying)
                    putExtra("artworkUrl", artworkUrl)
                }
                context.sendBroadcast(broadcastIntent)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }
}
