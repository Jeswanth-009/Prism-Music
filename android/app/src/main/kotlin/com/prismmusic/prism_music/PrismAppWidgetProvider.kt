package com.prismmusic.prism_music

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.KeyEvent
import android.widget.RemoteViews

class PrismAppWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_PLAY_PAUSE = "com.prismmusic.prism_music.ACTION_PLAY_PAUSE"
        const val ACTION_NEXT = "com.prismmusic.prism_music.ACTION_NEXT"

        private var lastTitle: String = "Prism Music"
        private var lastArtist: String = "No song playing"
        private var lastIsPlaying: Boolean = false

        fun updateWidget(
            context: Context,
            title: String,
            artist: String,
            isPlaying: Boolean
        ) {
            lastTitle = title.ifEmpty { "Prism Music" }
            lastArtist = artist.ifEmpty { "No song playing" }
            lastIsPlaying = isPlaying

            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, PrismAppWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)

            for (widgetId in allWidgetIds) {
                val views = buildRemoteViews(context, lastTitle, lastArtist, lastIsPlaying)
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        }

        private fun buildRemoteViews(
            context: Context,
            title: String,
            artist: String,
            isPlaying: Boolean
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.prism_playback_widget)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_artist, artist)

            val playPauseIcon = if (isPlaying) {
                android.R.drawable.ic_media_pause
            } else {
                android.R.drawable.ic_media_play
            }
            views.setImageViewResource(R.id.widget_btn_play_pause, playPauseIcon)

            // Open app on widget tap
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingLaunch = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingLaunch)

            // Play/Pause intent
            val playPauseIntent = Intent(context, PrismAppWidgetProvider::class.java).apply {
                action = ACTION_PLAY_PAUSE
            }
            val pendingPlayPause = PendingIntent.getBroadcast(
                context,
                1,
                playPauseIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_play_pause, pendingPlayPause)

            // Next intent
            val nextIntent = Intent(context, PrismAppWidgetProvider::class.java).apply {
                action = ACTION_NEXT
            }
            val pendingNext = PendingIntent.getBroadcast(
                context,
                2,
                nextIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_next, pendingNext)

            return views
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            val views = buildRemoteViews(context, lastTitle, lastArtist, lastIsPlaying)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_PLAY_PAUSE -> {
                sendMediaKeyEvent(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
            }
            ACTION_NEXT -> {
                sendMediaKeyEvent(context, KeyEvent.KEYCODE_MEDIA_NEXT)
            }
        }
    }

    private fun sendMediaKeyEvent(context: Context, keyCode: Int) {
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
