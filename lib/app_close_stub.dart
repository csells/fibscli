// Non-web platforms: no browser "tab close" event, so this is a no-op. The web
// implementation (app_close_web.dart) is selected via conditional import.
void onAppClose(void Function() handler) {}
