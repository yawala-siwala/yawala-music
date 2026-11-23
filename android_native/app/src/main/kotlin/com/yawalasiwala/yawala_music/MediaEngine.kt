package com.yawalasiwala.yawala_music

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.MediaPlayer
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.net.Uri

/// Process-wide audio engine shared by the activity and the foreground
/// service. Framework-only APIs: [MediaPlayer], [AudioAttributes] and
/// [MediaSession] - no external dependencies, so the CI-generated runner
/// compiles it unchanged.
object MediaEngine {
    private var player: MediaPlayer? = null
    private var session: MediaSession? = null
    private var focusRequest: AudioFocusRequest? = null

    @Synchronized
    fun prepare(context: Context, source: String): Boolean {
        return try {
            release()
            val player = MediaPlayer()
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            if (source.startsWith("content://")) {
                player.setDataSource(context, Uri.parse(source))
            } else {
                player.setDataSource(source)
            }
            player.prepare()
            this.player = player
            true
        } catch (error: Exception) {
            release()
            false
        }
    }

    @Synchronized
    fun play() {
        try {
            player?.start()
        } catch (_: Exception) {
        }
    }

    @Synchronized
    fun pause() {
        try {
            player?.takeIf { it.isPlaying }?.pause()
        } catch (_: Exception) {
        }
    }

    @Synchronized
    fun seek(positionMs: Int) {
        try {
            player?.seekTo(positionMs)
        } catch (_: Exception) {
        }
    }

    /// Halts playback and rewinds, keeping the media prepared so a restart
    /// does not need a fresh [prepare].
    @Synchronized
    fun stop() {
        try {
            player?.takeIf { it.isPlaying }?.pause()
        } catch (_: Exception) {
        }
        try {
            player?.seekTo(0)
        } catch (_: Exception) {
        }
    }

    @Synchronized
    fun position(): Int? {
        return try {
            player?.currentPosition
        } catch (_: Exception) {
            null
        }
    }

    @Synchronized
    fun release() {
        try {
            player?.release()
        } catch (_: Exception) {
        }
        player = null
    }

    fun activateSession(context: Context) {
        val manager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            ?: return
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(attributes)
            .setOnAudioFocusChangeListener { }
            .build()
        focusRequest = request
        try {
            manager.requestAudioFocus(request)
        } catch (_: Exception) {
        }
    }

    fun deactivateSession(context: Context) {
        try {
            val manager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            focusRequest?.let { manager?.abandonAudioFocusRequest(it) }
        } catch (_: Exception) {
        }
        focusRequest = null
        try {
            session?.isActive = false
        } catch (_: Exception) {
        }
    }

    /// Publishes now-playing metadata to the platform [MediaSession] so the
    /// system media controls / lock screen reflect the app's transport.
    fun updateMetadata(context: Context, title: String, artist: String, isPlaying: Boolean) {
        try {
            val mediaSession = session ?: MediaSession(context, "YawalaMusic").also {
                session = it
                it.isActive = true
            }
            mediaSession.setMetadata(
                MediaMetadata.Builder()
                    .putString(MediaMetadata.METADATA_KEY_TITLE, title)
                    .putString(MediaMetadata.METADATA_KEY_ARTIST, artist)
                    .build()
            )
            val position = try {
                player?.currentPosition ?: 0
            } catch (_: Exception) {
                0
            }
            mediaSession.setPlaybackState(
                PlaybackState.Builder()
                    .setState(
                        if (isPlaying) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED,
                        position.toLong(),
                        if (isPlaying) 1f else 0f
                    )
                    .setActions(
                        PlaybackState.ACTION_PLAY or
                            PlaybackState.ACTION_PAUSE or
                            PlaybackState.ACTION_SEEK_TO or
                            PlaybackState.ACTION_SKIP_TO_NEXT or
                            PlaybackState.ACTION_SKIP_TO_PREVIOUS
                    )
                    .build()
            )
        } catch (_: Exception) {
        }
    }
}
