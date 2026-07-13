// The Analytics Engine schema is positional: a value written to the wrong blob
// or double slot is not a type error, and a containment check ("does the JSON
// mention 'session_close'?") would not notice. These tests pin the COLUMNS --
// the exact slot each dimension and metric lands in -- so reordering the schema
// fails loudly instead of silently corrupting every query in docs/analytics.md.
import { describe, expect, test } from 'vitest';

import { handleRequest } from '../src/bridge';
import {
  BLOB_COLUMNS,
  DOUBLE_COLUMNS,
  flushAsync,
  makeTestHarness,
  metricByType,
} from './test_support';

function websocketRequest(url = 'https://proxy.example.com/fibs') {
  return new Request(url, {
    headers: {
      Origin: 'https://play.example.com',
      Upgrade: 'websocket',
    },
  });
}

describe('analytics schema', () => {
  test('every blob and double column is named exactly once', () => {
    expect(new Set(BLOB_COLUMNS).size).toBe(BLOB_COLUMNS.length);
    expect(new Set(DOUBLE_COLUMNS).size).toBe(DOUBLE_COLUMNS.length);
  });

  test('a rejection lands its reason, route, and result in their own columns', async () => {
    const h = makeTestHarness();
    const response = await handleRequest(
      new Request('https://proxy.example.com/nope'),
      h.env,
      h.deps,
    );
    expect(response.status).toBe(404);
    await flushAsync();

    const reject = metricByType(h.analytics, 'session_reject');
    expect(reject.blobs.type).toBe('session_reject');
    expect(reject.blobs.route).toBe('unknown');
    expect(reject.blobs.rejectReason).toBe('unknown_path');
    expect(reject.doubles.rejectedCount).toBe(1);
    // A rejection has no session, so the session columns stay empty/zero.
    expect(reject.blobs.closeSide).toBe('');
    expect(reject.doubles.browserToFibsBytes).toBe(0);
  });

  test('session_close carries its aggregates in the right double columns', async () => {
    const h = makeTestHarness({ allowedOrigins: 'https://play.example.com' });
    await handleRequest(websocketRequest(), h.env, h.deps);
    await flushAsync();

    h.server.dispatchMessage('who\n'); // 4 bytes browser -> FIBS
    await flushAsync();
    h.tcp.push(new Uint8Array([1, 2, 3])); // 3 bytes FIBS -> browser
    await flushAsync();
    h.server.dispatchClose(1000, 'done');
    await flushAsync();

    const close = metricByType(h.analytics, 'session_close');
    expect(close.blobs.type).toBe('session_close');
    expect(close.blobs.closeSide).toBe('browser');
    expect(close.doubles.browserToFibsBytes).toBe(4);
    expect(close.doubles.fibsToBrowserBytes).toBe(3);
    expect(close.doubles.browserToFibsMessages).toBe(1);
    expect(close.doubles.fibsToBrowserMessages).toBe(1);
    expect(close.doubles.closeCount).toBe(1);
    // The reject columns belong to a rejection, not a closed session.
    expect(close.blobs.rejectReason).toBe('');
    expect(close.doubles.rejectedCount).toBe(0);
  });
});
