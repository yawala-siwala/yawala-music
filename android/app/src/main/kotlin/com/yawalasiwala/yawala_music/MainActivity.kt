package com.yawalasiwala.yawala_music

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Yawala Music - Android runner bootstrap.
 *
 * Registers the `com.yawalasiwala/music` method channel so the Dart layer can
 * drive audio session management, lock-screen media controls and the
 * background playback service (Android foreground service). Values below are
 * safe-fallback stubs until the real MediaSession integration lands; the Dart
 * [NativeChannelGateway] degrades every call the same way, so nothing crashes
 * on any Android version.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "activateAudioSession" -> result.success(
                        mapOf(
                            "sessionId" to "android-stub",
                            "isBackgroundAudioEnabled" to false,
                        ),
                    )
                    "updateMediaControls", "deactivateAudioSession" ->
                        result.success(null)
                    "startBackgroundService", "stopBackgroundService" ->
                        result.success("unsupported")
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val CHANNEL = "com.yawalasiwala/music"
    }
}
