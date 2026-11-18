// windows/runner/yawala_native_stub.h - Safe-fallback response table for the
// Yawala Music method channel on the Windows runner.
//
// The Dart-side NativeChannelGateway already degrades every invocation to a
// safe fallback; this table lets the generated Windows runner answer with
// identical payloads once flutter_window.cpp registers a
// flutter::MethodChannel backed by yawala_stub::responseFor().
#pragma once

#include <string>

namespace yawala_stub {

inline const char* kMusicChannelName = "com.yawalasiwala/music";

/// Returns the stubbed JSON payload for [method] (StandardMethodCodec
/// encoding) on the music channel.
inline std::string responseFor(const std::string& method) {
  if (method == "activateAudioSession") {
    return "{\"sessionId\":\"windows-stub\",\"isBackgroundAudioEnabled\":false}";
  }
  if (method == "startBackgroundService" ||
      method == "stopBackgroundService") {
    return "\"unsupported\"";
  }
  return "null";
}

}  // namespace yawala_stub
