import { describe, expect, test } from 'vitest';

import { handleRequest } from '../src/bridge';
import { allMetricText, makeTestHarness } from './test_support';

describe('request handling', () => {
  test('health check is plain HTTP and does not open a FIBS connection', async () => {
    const h = makeTestHarness();

    const response = await handleRequest(
      new Request('https://proxy.example.com/healthz'),
      h.env,
      h.deps,
    );

    expect(response.status).toBe(200);
    expect(await response.text()).toBe('ok');
    expect(h.tcpConnect).not.toHaveBeenCalled();
    expect(allMetricText(h.analytics)).toContain('bridge_request');
  });

  test('bridge route rejects non-WebSocket requests', async () => {
    const h = makeTestHarness();

    const response = await handleRequest(
      new Request('https://proxy.example.com/fibs'),
      h.env,
      h.deps,
    );

    expect(response.status).toBe(426);
    expect(h.tcpConnect).not.toHaveBeenCalled();
    expect(allMetricText(h.analytics)).toContain('not_websocket');
  });

  test('unknown paths are not alternate proxy targets', async () => {
    const h = makeTestHarness();

    const response = await handleRequest(
      new Request('https://proxy.example.com/proxy?host=evil.test&port=25'),
      h.env,
      h.deps,
    );

    expect(response.status).toBe(404);
    expect(h.tcpConnect).not.toHaveBeenCalled();
    expect(allMetricText(h.analytics)).toContain('unknown_path');
  });

  test('origin allowlist rejects untrusted browser origins', async () => {
    const h = makeTestHarness({ allowedOrigins: 'https://play.example.com' });

    const response = await handleRequest(
      new Request('https://proxy.example.com/fibs', {
        headers: {
          Origin: 'https://attacker.example.com',
          Upgrade: 'websocket',
        },
      }),
      h.env,
      h.deps,
    );

    expect(response.status).toBe(403);
    expect(h.tcpConnect).not.toHaveBeenCalled();
    expect(allMetricText(h.analytics)).toContain('bad_origin');
  });

  test('records Cloudflare request location metadata when available', async () => {
    const h = makeTestHarness();
    const request = new Request('https://proxy.example.com/fibs', {
      headers: { Upgrade: 'websocket' },
    });
    Object.defineProperty(request, 'cf', {
      value: { colo: 'SJC', country: 'US' },
    });

    await handleRequest(request, h.env, h.deps);

    expect(allMetricText(h.analytics)).toContain('SJC');
    expect(allMetricText(h.analytics)).toContain('US');
  });
});
