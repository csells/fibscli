import 'dart:async';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:meta/meta.dart';

// The cross-platform entry point: WebSocketChannel.connect picks the dart:io or
// dart:html implementation via conditional compilation, so the same code runs
// on native (desktop/mobile) and on the web.
import 'package:web_socket_channel/web_socket_channel.dart';

import 'cookie_monster.dart';

enum _LoginState { prelogin, sentcred, postlogin }

/// Handles the WebSocket connection to the FIBS server.
///
/// Manages the login process and incoming/outgoing messages.
/// Parses incoming raw message strings into CookieMessage objects.
class FibsConnection {
  /// Handles the WebSocket connection to the FIBS server.
  ///
  /// Manages the login process and incoming/outgoing messages.
  /// Parses incoming raw message strings into CookieMessage objects.
  FibsConnection(this._proxy, this._port, {this.secure = false, this.path = ''})
    : assert(path == '' || path.startsWith('/'));

  static const _fibsVersion = '1008';
  final String _proxy;
  final int _port;

  /// Whether to reach the proxy over TLS (`wss://`). A production deployment
  /// behind an HTTPS origin needs this; the local dev bridge uses plain `ws://`.
  final bool secure;

  /// Optional WebSocket path on the proxy host.
  final String path;

  /// The websocket URL of the proxy bridge. `wss://` when [secure].
  Uri get url => Uri(
    scheme: secure ? 'wss' : 'ws',
    host: _proxy,
    port: _port,
    path: path.isEmpty ? null : path,
  );
  final _streamController = StreamController<CookieMessage>();
  WebSocketChannel? _channel;
  final _monster = CookieMonster();
  // Carries an incomplete trailing line between websocket frames. FIBS lines
  // can be split across frames (TCP boundaries / a slow server), so we must
  // only parse complete, newline-terminated lines and buffer the remainder.
  String _residual = '';
  Completer<FibsCookie>? _loginCompleter;
  _LoginState? _loginState;

  /// Whether the WebSocket connection is currently open.
  bool get connected => _channel != null;

  /// Stream of parsed CookieMessage objects received from the server.
  Stream<CookieMessage> get stream => _streamController.stream;

  /// The login outcome for a batch of parsed [cookies], chosen by precedence
  /// (welcome > failed-login > re-prompt), or null if none is present yet. A
  /// single failed-login frame can carry several of these (bogus "** ..." lines
  /// plus a re-`login:` prompt), so we must pick by precedence and NEVER use
  /// `.single` (which would throw and hang the login until its timeout).
  @visibleForTesting
  static FibsCookie? loginOutcome(Iterable<FibsCookie> cookies) {
    const precedence = <FibsCookie>[
      FibsCookie.CLIP_WELCOME,
      FibsCookie.FIBS_FailedLogin,
      FibsCookie.FIBS_LoginPrompt,
    ];
    final present = cookies.toSet();
    for (final cookie in precedence) {
      if (present.contains(cookie)) return cookie;
    }
    return null;
  }

  /// Parse one raw websocket frame into cookies (drives the residual-line
  /// buffering across frames). Exposed so the frame-splitting logic can be
  /// tested without a live socket; [asState] optionally forces the parser's
  /// starting message state.
  @visibleForTesting
  List<CookieMessage> receiveFrame(
    String frame, {
    CookieMonsterState? asState,
  }) {
    if (asState != null) _monster.messageState = asState;
    return _receive(frame);
  }

  /// Logs in to the FIBS server with the given username and password.
  ///
  /// Sends the login credentials and handles the login prompt and response.
  /// Returns a Future that completes with the login result cookie.
  ///
  /// Parameters:
  ///
  /// user - The username
  /// pass - The password
  ///
  /// Returns: A Future containing the login result cookie
  Future<FibsCookie> login(String user, String pass) {
    assert(!connected);

    _residual = ''; // start with a clean line buffer
    _channel = WebSocketChannel.connect(url);

    _channel!.stream.listen(
      (dynamic frame) {
        // native delivers binary frames as bytes; the web may deliver a String
        // or a ByteBuffer, so decode whatever the platform hands us
        final message = _decodeFrame(frame);
        dev.log('stream.message: $message');
        final cms = _receive(message);
        // broadcast every parsed cookie to external subscribers, then drive the
        // login handshake off the same batch
        cms.forEach(_streamController.add);

        switch (_loginState) {
          case _LoginState.prelogin:
            // wait for login prompt
            final expecting = <FibsCookie>[FibsCookie.FIBS_LoginPrompt];
            final found = cms
                .map((cm) => cm.cookie)
                .where(expecting.contains)
                .toList();
            if (found.isEmpty) return; // wait for next batch

            // send credentials
            send('login flutter-fibs $_fibsVersion $user $pass');
            _loginState = _LoginState.sentcred;

          case _LoginState.sentcred:
            final cookie = loginOutcome(cms.map((cm) => cm.cookie));
            if (cookie == null) return; // no outcome yet; wait for next batch

            // complete the login
            _loginCompleter!.complete(cookie);
            _loginCompleter = null;
            _loginState = _LoginState.postlogin;

          case _LoginState.postlogin:
          case null:
            break;
        }
      },
      onDone: () {
        dev.log('stream.onDone');
        // fire-and-forget teardown; close() captures-and-nulls up front so a
        // concurrent onError close can't double-close
        unawaited(close());
      },
      onError: (error) {
        dev.log('stream.onError: $error');
        unawaited(close());
      },
      cancelOnError: false,
    );

    _loginState = _LoginState.prelogin;
    _loginCompleter = Completer<FibsCookie>();
    return _loginCompleter!.future;
  }

  /// Sends a message to the FIBS server over the WebSocket connection.
  ///
  /// The message should not contain any newline characters, as this method
  /// will append the newline before sending.
  ///
  /// Parameters:
  ///
  /// s - The message string to send
  void send(String s) {
    assert(connected);
    assert(!s.endsWith('\n'));
    dev.log('SEND: $s');
    _channel!.sink.add('$s\n');
  }

  // Normalize a websocket frame to text. Native (dart:io) yields Uint8List for
  // binary frames; the web (dart:html) may yield a String or a ByteBuffer.
  static String _decodeFrame(dynamic frame) {
    if (frame is String) return frame;
    if (frame is Uint8List) return String.fromCharCodes(frame);
    if (frame is ByteBuffer) return String.fromCharCodes(frame.asUint8List());
    if (frame is List<int>) return String.fromCharCodes(frame);
    return frame.toString();
  }

  // Parse a decoded frame into cookies. Pure: it updates the line-residual and
  // the cookie monster's state, but does NOT broadcast -- the caller does that
  // in one explicit loop, so "parse" and "broadcast" aren't entangled in a lazy
  // generator (which would silently change how many times we broadcast if a
  // caller ever consumed the result lazily).
  List<CookieMessage> _receive(String message) {
    dev.log('RECEIVE: $message');

    // Prepend any partial line from the previous frame, then split on newlines.
    // Every part but the last is a complete, newline-terminated line; the last
    // is the (possibly incomplete) trailing segment.
    final parts = (_residual + message).split('\n');
    final last = parts.removeLast();
    final cms = [
      for (final line in parts) _monster.eatCookie(line.replaceAll('\r', '')),
    ];

    // Decide the trailing segment by the state AFTER those complete lines, not
    // the state at the start of the frame -- a frame can cross the MOTD_END ->
    // RUN transition, after which an incomplete who-list/board line must be
    // held for the next frame. During login the prompt ("login: ") has no
    // trailing newline and must be processed immediately.
    if (_monster.messageState == CookieMonsterState.FIBS_RUN_STATE) {
      _residual = last; // buffer the incomplete trailing line
    } else {
      _residual = '';
      if (last.isNotEmpty) {
        cms.add(_monster.eatCookie(last.replaceAll('\r', '')));
      }
    }
    return cms;
  }

  /// Closes the WebSocket connection to the FIBS server.
  Future<void> close() async {
    // Capture-and-null BEFORE the first await so a concurrent close() (onDone
    // and onError can both fire) can't pass the guard during the async gap.
    final channel = _channel;
    if (channel == null) return;
    _channel = null;
    await channel.sink.close();
    await _streamController.close();
  }
}
