import 'dart:js_interop';

import 'package:web/web.dart' as web;

// Web: fire [handler] when the tab/app is closing. We listen on both
// `pagehide` (fires on tab close / bfcache, the most reliable) and
// `beforeunload`. This is BEST-EFFORT only: the browser may tear the socket
// down before an outgoing message flushes, so don't rely on it for anything
// other than a courtesy "bye" to FIBS (a dropped connection ends the session
// anyway).
void onAppClose(void Function() handler) {
  final cb = ((web.Event _) => handler()).toJS;
  web.window.addEventListener('pagehide', cb);
  web.window.addEventListener('beforeunload', cb);
}
