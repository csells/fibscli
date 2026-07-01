import { describe, expect, test } from 'vitest';

import { handleRequest } from '../src/bridge';
import { allMetricText, flushAsync, makeTestHarness } from './test_support';

describe('privacy-safe telemetry', () => {
  test('does not log or emit raw FIBS credentials or frame payloads', async () => {
    const h = makeTestHarness();
    await handleRequest(
      new Request('https://proxy.example.com/fibs', {
        headers: { Upgrade: 'websocket' },
      }),
      h.env,
      h.deps,
    );
    await flushAsync();

    h.server.dispatchMessage('login flutter-fibs 1008 chris super-secret\n');
    h.tcp.push('13 chris@example.com who-list row\n');
    h.server.dispatchClose(1000, 'done');
    await flushAsync();

    const telemetry = `${JSON.stringify(h.logs)} ${allMetricText(h.analytics)}`;

    expect(telemetry).toContain('session_close');
    expect(telemetry).not.toContain('super-secret');
    expect(telemetry).not.toContain('chris@example.com');
    expect(telemetry).not.toContain('login flutter-fibs');
    expect(telemetry).not.toContain('who-list row');
  });

  test('analytics write failures do not break the bridge', async () => {
    const h = makeTestHarness();
    h.analytics.writeDataPoint = () => {
      throw new Error('analytics unavailable');
    };

    const response = await handleRequest(
      new Request('https://proxy.example.com/fibs', {
        headers: { Upgrade: 'websocket' },
      }),
      h.env,
      h.deps,
    );
    await flushAsync();

    expect(response.status).toBe(101);
    expect(h.tcpConnect).toHaveBeenCalledOnce();
    expect(JSON.stringify(h.logs)).toContain('analytics_error');
  });
});
