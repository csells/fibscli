import { describe, expect, test } from 'vitest';

import { handleRequest } from '../src/bridge';
import {
  FakeTimers,
  decode,
  flushAsync,
  makeTestHarness,
} from './test_support';

function websocketRequest(url = 'https://proxy.example.com/fibs') {
  return new Request(url, {
    headers: {
      Origin: 'https://play.example.com',
      Upgrade: 'websocket',
    },
  });
}

describe('websocket to FIBS TCP bridge', () => {
  test('accepts a WebSocket and always connects only to fibs.com:4321', async () => {
    const h = makeTestHarness({ allowedOrigins: 'https://play.example.com' });

    const response = await handleRequest(
      websocketRequest('https://proxy.example.com/fibs?host=evil.test&port=25'),
      h.env,
      h.deps,
    );
    await flushAsync();

    expect(response.status).toBe(101);
    expect(h.server.accepted).toBe(true);
    expect(h.tcpConnect).toHaveBeenCalledWith({
      hostname: 'fibs.com',
      port: 4321,
    });
  });

  test('forwards text and binary browser messages to FIBS as bytes', async () => {
    const h = makeTestHarness();
    await handleRequest(websocketRequest(), h.env, h.deps);
    await flushAsync();

    h.server.dispatchMessage('who\n');
    h.server.dispatchMessage(new Uint8Array([1, 2, 3]));
    await flushAsync();

    expect(h.tcp.written.map((chunk) => [...chunk])).toEqual([
      [...new TextEncoder().encode('who\n')],
      [1, 2, 3],
    ]);
  });

  test('forwards FIBS bytes back to the browser as binary messages', async () => {
    const h = makeTestHarness();
    await handleRequest(websocketRequest(), h.env, h.deps);
    await flushAsync();

    h.tcp.push('login: ');
    await flushAsync();

    expect(h.server.sent).toHaveLength(1);
    expect(h.server.sent[0]).toBeInstanceOf(Uint8Array);
    expect(decode(h.server.sent[0])).toBe('login: ');
  });

  test('closes the TCP socket when the browser closes', async () => {
    const h = makeTestHarness();
    await handleRequest(websocketRequest(), h.env, h.deps);
    await flushAsync();

    h.server.dispatchClose(1000, 'done');
    await flushAsync();

    expect(h.tcp.closeCalls).toBe(1);
    expect(JSON.stringify(h.analytics.points)).toContain('session_close');
    expect(JSON.stringify(h.analytics.points)).toContain('browser');
  });

  test('ignores TCP read errors after the browser already closed', async () => {
    const h = makeTestHarness();
    await handleRequest(websocketRequest(), h.env, h.deps);
    await flushAsync();

    h.server.dispatchClose(1000, 'done');
    await flushAsync();
    h.tcp.error();
    await flushAsync();

    expect(JSON.stringify(h.analytics.points)).not.toContain('bridge_error');
    expect(JSON.stringify(h.logs)).not.toContain('bridge_error');
  });

  test('observes TCP closed rejections during intentional browser teardown', async () => {
    const h = makeTestHarness();
    await handleRequest(websocketRequest(), h.env, h.deps);
    await flushAsync();

    h.server.dispatchClose(1000, 'done');
    h.tcp.rejectClosedPromise();
    await flushAsync();

    expect(JSON.stringify(h.analytics.points)).not.toContain('bridge_error');
    expect(JSON.stringify(h.logs)).not.toContain('bridge_error');
  });

  test('closes the WebSocket when FIBS closes', async () => {
    const h = makeTestHarness();
    await handleRequest(websocketRequest(), h.env, h.deps);
    await flushAsync();

    h.tcp.end();
    await flushAsync();

    expect(h.server.closeCode).toBe(1000);
    expect(JSON.stringify(h.analytics.points)).toContain('fibs');
  });

  test('uses a stricter idle timeout before the browser sends data', async () => {
    const timers = new FakeTimers();
    const h = makeTestHarness({ idleTimeoutMs: 1000, timers });
    Object.assign(h.deps, { preClientIdleTimeoutMs: 100 });

    await handleRequest(websocketRequest(), h.env, h.deps);
    await flushAsync();

    timers.advanceBy(99);
    await flushAsync();
    expect(h.server.closeCode).toBeUndefined();

    timers.advanceBy(1);
    await flushAsync();

    expect(h.server.closeCode).toBe(1001);
    expect(h.server.closeReason).toBe('idle_timeout');
    expect(h.tcp.closeCalls).toBe(1);
    expect(JSON.stringify(h.analytics.points)).toContain('limit_hit');
  });

  test('rejects oversized browser messages before writing to FIBS', async () => {
    const h = makeTestHarness();
    await handleRequest(websocketRequest(), h.env, h.deps);
    await flushAsync();

    h.server.dispatchMessage(new Uint8Array(8 * 1024 + 1));
    await flushAsync();

    expect(h.tcp.written).toHaveLength(0);
    expect(h.server.closeCode).toBe(1009);
    expect(h.server.closeReason).toBe('oversize');
    expect(JSON.stringify(h.analytics.points)).toContain('limit_hit');
    expect(JSON.stringify(h.analytics.points)).toContain('oversize');
  });

  test('resets the normal idle timeout after FIBS traffic follows browser data', async () => {
    const timers = new FakeTimers();
    const h = makeTestHarness({ idleTimeoutMs: 1000, timers });
    Object.assign(h.deps, { preClientIdleTimeoutMs: 100 });
    await handleRequest(websocketRequest(), h.env, h.deps);
    await flushAsync();

    h.server.dispatchMessage('login test password\n');
    await flushAsync();
    timers.advanceBy(900);
    h.tcp.push('login accepted\n');
    await flushAsync();
    timers.advanceBy(100);
    await flushAsync();

    expect(h.server.closeCode).toBeUndefined();

    timers.advanceBy(900);
    await flushAsync();

    expect(h.server.closeCode).toBe(1001);
    expect(h.server.closeReason).toBe('idle_timeout');
  });

  test('closes the WebSocket when the FIBS stream errors', async () => {
    const h = makeTestHarness();
    await handleRequest(websocketRequest(), h.env, h.deps);
    await flushAsync();

    h.tcp.error();
    await flushAsync();

    expect(h.server.closeCode).toBe(1011);
    expect(h.server.closeReason).toBe('bridge_error');
    expect(JSON.stringify(h.analytics.points)).toContain('bridge_error');
  });

  test('closes the WebSocket and emits tcp_connect_failed when FIBS cannot connect', async () => {
    const h = makeTestHarness();
    h.tcpConnect.mockRejectedValueOnce(new Error('connect refused'));

    await handleRequest(websocketRequest(), h.env, h.deps);
    await flushAsync();

    expect(h.server.closeCode).toBe(1011);
    expect(h.server.closeReason).toBe('tcp_connect_failed');
    expect(JSON.stringify(h.analytics.points)).toContain('tcp_connect_failed');
  });
});
