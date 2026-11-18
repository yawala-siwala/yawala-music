#include "yawala_native_stub.h"

#include <flutter_linux/flutter_linux.h>

static const gchar kMusicChannelName[] = "com.yawalasiwala/music";

// Resolves every music method to a safe fallback so the Dart gateway always
// receives a well-formed response on Linux.
static void music_method_call_cb(FlMethodChannel* channel,
                                 FlMethodCall* method_call,
                                 gpointer user_data) {
  const gchar* method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (g_strcmp0(method, "activateAudioSession") == 0) {
    g_autoptr(FlValue) value = fl_value_new_map();
    fl_value_set_string_take(value, "sessionId",
                             fl_value_new_string("linux-stub"));
    fl_value_set_string_take(value, "isBackgroundAudioEnabled",
                             fl_value_new_bool(FALSE));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(value));
  } else if (g_strcmp0(method, "updateMediaControls") == 0 ||
             g_strcmp0(method, "deactivateAudioSession") == 0) {
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_null()));
  } else if (g_strcmp0(method, "startBackgroundService") == 0 ||
             g_strcmp0(method, "stopBackgroundService") == 0) {
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_string("unsupported")));
  } else {
    response =
        FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  fl_method_call_respond(method_call, response, &error);
}

void yawala_register_music_stub(FlView* view) {
  // Keep the channel alive for the process lifetime; re-registration is a
  // no-op so hot restarts stay safe.
  static FlMethodChannel* channel = nullptr;
  if (channel != nullptr) {
    return;
  }
  channel = fl_method_channel_new(fl_view_get_binary_messenger(view),
                                  kMusicChannelName,
                                  FL_METHOD_CODEC(fl_standard_method_codec_new()));
  fl_method_channel_set_method_call_handler(channel, music_method_call_cb,
                                            nullptr, nullptr);
}
