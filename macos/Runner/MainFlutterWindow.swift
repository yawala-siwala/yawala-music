import Cocoa
import FlutterMacOS

/// Yawala Music - macOS runner bootstrap.
class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    registerNativeBindingStubs(with: flutterViewController)
    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  /// Registers the `com.yawalasiwala/music` method channel with safe-fallback
  /// responses until the real SystemMediaTransportControls-style (SMTC /
  /// now-playing) integration lands on macOS.
  private func registerNativeBindingStubs(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.yawalasiwala/music",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "activateAudioSession":
        result(["sessionId": "macos-stub", "isBackgroundAudioEnabled": false])
      case "updateMediaControls", "deactivateAudioSession":
        result(nil)
      case "startBackgroundService", "stopBackgroundService":
        result("unsupported")
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
