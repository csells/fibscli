import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:test/test.dart';

void main() {
  // The proxy URL a deployment points at: plain ws:// for the local dev bridge,
  // wss:// when served behind an HTTPS origin.
  test('an insecure connection targets a ws:// proxy URL', () {
    final conn = FibsConnection('localhost', 8080);
    expect(conn.url, Uri.parse('ws://localhost:8080'));
  });

  test('a secure connection targets a wss:// proxy URL', () {
    final conn = FibsConnection('proxy.example.com', 443, secure: true);
    expect(conn.url, Uri.parse('wss://proxy.example.com:443'));
  });

  test('a secure connection can target the hosted Worker bridge path', () {
    final conn = FibsConnection(
      'proxy.playfibs.com',
      443,
      secure: true,
      path: '/fibs',
    );
    expect(conn.url, Uri.parse('wss://proxy.playfibs.com:443/fibs'));
  });
}
