import 'dart:async';
import 'dart:io';

import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:test/test.dart';

String _text(dynamic data) =>
    data is String ? data : String.fromCharCodes(data as List<int>);

void main() {
  test('createAccount validates username and password before connecting', () {
    final conn = FibsConnection('127.0.0.1', 1);

    expect(
      () => conn.createAccount('bad-name', 'hunter2'),
      throwsA(isA<FibsAccountCreationException>()),
    );
    expect(
      () => conn.createAccount('', 'hunter2'),
      throwsA(isA<FibsAccountCreationException>()),
    );
    expect(
      () => conn.createAccount('good_name', 'abc'),
      throwsA(isA<FibsAccountCreationException>()),
    );
  });

  test('createAccount reports a taken username', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    late final StreamSubscription<HttpRequest> requests;

    requests = server.listen((request) async {
      final ws = await WebSocketTransformer.upgrade(request);
      ws.add('login: ');
      ws.listen((dynamic data) {
        final command = _text(data).trim();
        if (command == 'guest') {
          ws.add('Please register before using this server:\n> ');
        } else if (command == 'name used_name') {
          ws.add(
            "** Please use another name. 'used_name' is already used by "
            'someone else.\n> ',
          );
          unawaited(ws.close());
        }
      });
    });

    final conn = FibsConnection('127.0.0.1', server.port);
    addTearDown(() async {
      await conn.close();
      await requests.cancel();
      await server.close(force: true);
    });

    await expectLater(
      conn.createAccount('used_name', 'hunter2'),
      throwsA(isA<FibsAccountCreationException>()),
    );
  });

  test(
    'login completes with timeout when the socket closes during handshake',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      late final StreamSubscription<HttpRequest> requests;

      requests = server.listen((request) async {
        final ws = await WebSocketTransformer.upgrade(request);
        await ws.close();
      });

      final conn = FibsConnection('127.0.0.1', server.port);
      addTearDown(() async {
        await conn.close();
        await requests.cancel();
        await server.close(force: true);
      });

      await expectLater(
        conn.login('joe', 'hunter2'),
        completion(FibsCookie.FIBS_Timeout),
      );
    },
  );
}
