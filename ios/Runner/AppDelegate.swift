import Flutter
import UIKit

/// Yawala Music - iOS runner bootstrap.
///
/// Registers the `com.yawalasiwala/music` method channel so the Dart layer
/// can drive audio session management, lock-screen media controls
/// (MPRemoteCommandCenter / MPNowPlayingInfoCenter) and background-audio
/// lifecycle (UIBackgroundModes audio). Values below are safe-fallback stubs
/// until the real media session implementation lands.
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.yawalasiwala/music",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "activateAudioSession":
          result(["sessionId": "ios-stub", "isBackgroundAudioEnabled": false])
        case "updateMediaControls", "deactivateAudioSession":
          result(nil)
        case "startBackgroundService", "stopBackgroundService":
          result("unsupported")
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
