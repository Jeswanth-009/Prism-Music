package com.prismmusic.prism_music

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.view.KeyEvent

/**
 * Internal non-exported receiver for home screen widget button actions.
 * Prevents external apps from forging media transport broadcasts.
 */
class WidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val keyCode = when (intent.action) {
            PrismAppWidgetProvider.ACTION_PREVIOUS -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
            PrismAppWidgetProvider.ACTION_PLAY_PAUSE -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            PrismAppWidgetProvider.ACTION_NEXT -> KeyEvent.KEYCODE_MEDIA_NEXT
            else -> return
        }
        try {
            val downIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                setPackage(context.packageName)
                putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
            }
            val upIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                setPackage(context.packageName)
                putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_UP, keyCode))
            }
            context.sendBroadcast(downIntent)
            context.sendBroadcast(upIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
