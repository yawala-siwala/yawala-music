package com.yawalasiwala.yawala_music

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Native host for Yawala Music: MediaStore library indexing, real
/// MediaPlayer playback, audio focus and the media session, all exposed
/// over the `com.yawalasiwala/music` channel.
class MainActivity : FlutterActivity() {
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listLibrary" -> result.success(indexAudioLibrary())
                    "requestLibraryAccess" -> requestAudioPermission(result)
                    "prepare" -> result.success(
                        MediaEngine.prepare(this, call.argument<String>("source") ?: "")
                    )
                    "play" -> {
                        MediaEngine.play()
                        result.success(null)
                    }
                    "pause" -> {
                        MediaEngine.pause()
                        result.success(null)
                    }
                    "seek" -> {
                        MediaEngine.seek(call.argument<Int>("positionMs") ?: 0)
                        result.success(null)
                    }
                    "stop" -> {
                        MediaEngine.stop()
                        result.success(null)
                    }
                    "position" -> result.success(MediaEngine.position())
                    "release" -> {
                        MediaEngine.release()
                        result.success(null)
                    }
                    "activateAudioSession" -> {
                        MediaEngine.activateSession(this)
                        result.success(
                            mapOf(
                                "sessionId" to "android-audio-session",
                                "isBackgroundAudioEnabled" to true
                            )
                        )
                    }
                    "deactivateAudioSession" -> {
                        MediaEngine.deactivateSession(this)
                        result.success(null)
                    }
                    "updateMediaControls" -> {
                        MediaEngine.updateMetadata(
                            this,
                            call.argument<String>("title") ?: "Unknown title",
                            call.argument<String>("artist") ?: "Unknown artist",
                            call.argument<Boolean>("isPlaying") == true
                        )
                        result.success(null)
                    }
                    "startBackgroundService" -> {
                        try {
                            startForegroundService(
                                Intent(this, MediaPlaybackService::class.java)
                            )
                            result.success("running")
                        } catch (error: Exception) {
                            result.success("stopped")
                        }
                    }
                    "stopBackgroundService" -> {
                        try {
                            stopService(Intent(this, MediaPlaybackService::class.java))
                        } catch (_: Exception) {
                        }
                        result.success("stopped")
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun hasAudioPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= 33) {
            checkSelfPermission(Manifest.permission.READ_MEDIA_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) ==
                PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestAudioPermission(result: MethodChannel.Result) {
        if (hasAudioPermission()) {
            result.success(true)
            return
        }
        val permission =
            if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_AUDIO
            else Manifest.permission.READ_EXTERNAL_STORAGE
        pendingPermissionResult = result
        try {
            requestPermissions(arrayOf(permission), PERMISSION_REQUEST_CODE)
        } catch (error: Exception) {
            pendingPermissionResult = null
            result.success(false)
        }
    }

    /// Queries [MediaStore.Audio.Media] for the device's real audio
    /// library. Returns an empty list when read access is missing - a clean,
    /// empty fallback rather than synthetic demo tracks.
    private fun indexAudioLibrary(): List<Map<String, Any>> {
        if (!hasAudioPermission()) {
            return emptyList()
        }
        val tracks = mutableListOf<Map<String, Any>>()
        return try {
            val collection =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
                } else {
                    @Suppress("DEPRECATION")
                    MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                }
            val projection = arrayOf(
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.TITLE,
                MediaStore.Audio.Media.ARTIST,
                MediaStore.Audio.Media.ALBUM,
                MediaStore.Audio.Media.DURATION
            )
            val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
            contentResolver.query(
                collection,
                projection,
                selection,
                null,
                "${MediaStore.Audio.Media.TITLE} ASC"
            )?.use { cursor ->
                val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val titleColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                val artistColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
                val albumColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
                val durationColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
                while (cursor.moveToNext()) {
                    val duration = cursor.getLong(durationColumn)
                    if (duration <= 0) {
                        continue
                    }
                    val id = cursor.getLong(idColumn)
                    tracks.add(
                        mapOf(
                            "id" to "media-$id",
                            "title" to (cursor.getString(titleColumn) ?: "Unknown title"),
                            "artist" to (cursor.getString(artistColumn) ?: "Unknown artist"),
                            "album" to (cursor.getString(albumColumn) ?: "Unknown album"),
                            "durationMs" to duration,
                            "filePath" to "content://media/external/audio/media/$id"
                        )
                    )
                }
            }
            tracks
        } catch (error: Exception) {
            emptyList()
        }
    }

    companion object {
        private const val CHANNEL = "com.yawalasiwala/music"
        private const val PERMISSION_REQUEST_CODE = 4041
    }
}
