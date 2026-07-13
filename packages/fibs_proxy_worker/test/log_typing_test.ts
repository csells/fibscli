// The privacy invariant the bridge exists to protect is "never log a payload".
// Code review alone cannot hold that line, so the TYPE holds it: log metadata
// accepts counts, flags, and closed-set category names -- not arbitrary values.
// A raw frame, a chunk of TCP bytes, or a decoded FIBS line is a compile error,
// and `npm run check` (tsc, gated in CI) is what fails.
//
// These are compile-time assertions: each `@ts-expect-error` FAILS the build if
// the line it guards ever becomes legal.
import { describe, expect, test } from 'vitest';

import { logInfo, logWarn } from '../src/logging';

const logger = { info() {}, warn() {}, error() {} };

describe('log metadata typing', () => {
  test('counts, flags, and category names are loggable', () => {
    logInfo(logger, 'session_close', {
      browserToFibsBytes: 42,
      closeSide: 'browser',
      route: '/fibs',
      clientDataSent: true,
    });
    logWarn(logger, 'session_reject', { reason: 'bad_origin', status: 403 });
    expect(true).toBe(true);
  });

  test('a raw frame cannot be logged', () => {
    const frame = new Uint8Array([1, 2, 3]);
    // @ts-expect-error raw bytes are not a loggable value
    logInfo(logger, 'browser_message', { data: frame });

    const decodedFibsLine = { line: 'login flutter-fibs 1008 chris secret' };
    // @ts-expect-error an object payload is not a loggable value
    logWarn(logger, 'fibs_line', { payload: decodedFibsLine });

    // @ts-expect-error a raw ArrayBuffer is not a loggable value
    logInfo(logger, 'tcp_chunk', { chunk: new ArrayBuffer(8) });
    expect(true).toBe(true);
  });
});
