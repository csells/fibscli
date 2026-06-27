import 'dart:async';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:web_socket_channel/io.dart';

import 'cookie_monster.dart';
// import 'package:web_socket_channel/status.dart' as wsStatus;

enum _LoginState {
  prelogin,
  sentcred,
  postlogin,
}

/// Handles the WebSocket connection to the FIBS server.
///
/// Manages the login process and incoming/outgoing messages.
/// Parses incoming raw message strings into CookieMessage objects.
class FibsConnection {
  /// Handles the WebSocket connection to the FIBS server.
  ///
  /// Manages the login process and incoming/outgoing messages.
  /// Parses incoming raw message strings into CookieMessage objects.
  FibsConnection(this._proxy, this._port);

  static const _fibsVersion = '1008';
  final String _proxy;
  final int _port;
  final _streamController = StreamController<CookieMessage>();
  IOWebSocketChannel? _channel;
  final _monster = CookieMonster();
  Completer<FibsCookie>? _loginCompleter;
  _LoginState? _loginState;

  /// Whether the WebSocket connection is currently open.
  bool get connected => _channel != null;

  /// Stream of parsed CookieMessage objects received from the server.
  Stream<CookieMessage> get stream => _streamController.stream;

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

    _channel = IOWebSocketChannel.connect('ws://$_proxy:$_port');

    _channel!.stream.listen(
      (dynamic bytes) {
        final message = String.fromCharCodes(bytes as Uint8List);
        dev.log('stream.message: $message');
        final cms = _receive(message).toList();

        switch (_loginState) {
          case _LoginState.prelogin:
            // wait for login prompt
            final expecting = <FibsCookie>[FibsCookie.FIBS_LoginPrompt];
            final found =
                cms.map((cm) => cm.cookie).where(expecting.contains).toList();
            if (found.isEmpty) return; // wait for next batch

            // send credentials
            send('login flutter-fibs $_fibsVersion $user $pass');
            _loginState = _LoginState.sentcred;

          case _LoginState.sentcred:
            // wait for login prompt
            final expecting = <FibsCookie>[
              FibsCookie.CLIP_WELCOME,
              FibsCookie.FIBS_FailedLogin,
              FibsCookie.FIBS_LoginPrompt
            ];
            final found =
                cms.map((cm) => cm.cookie).where(expecting.contains).toList();
            if (found.isEmpty) return; // wait for next batch

            // complete the login
            final cookie = found.single;
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
        close();
      },
      onError: (error) {
        dev.log('stream.onError: $error');
        close();
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

  Iterable<CookieMessage> _receive(String message) sync* {
    dev.log('RECEIVE: $message');

    final lines = message.split('\n');
    for (final line in lines) {
      final cm = _monster.eatCookie(line.replaceAll('\r', ''));
      _streamController.add(cm);
      yield cm;
    }
  }

  /// Closes the WebSocket connection to the FIBS server.
  Future<void> close() async {
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
      await _streamController.close();
    }
  }
}
