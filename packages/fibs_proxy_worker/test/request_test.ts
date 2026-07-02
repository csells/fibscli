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

  test('empty origin allowlist rejects browser origins', async () => {
    const h = makeTestHarness();

    const response = await handleRequest(
      new Request('https://proxy.example.com/fibs', {
        headers: {
          Origin: 'https://play.example.com',
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

  test('accepts app analytics events through the Analytics Engine binding', async () => {
    const h = makeTestHarness({ allowedOrigins: 'https://play.example.com' });

    const response = await handleRequest(
      new Request('https://proxy.example.com/analytics', {
        body: JSON.stringify({
          event: 'app_fibs_lobby_ready',
          platform: 'web',
          screen: 'fibs_lobby',
          environment: 'e2e',
          version: 'unit',
          whoInfoCount: 10,
          availableBotCount: 2,
          watchableBotCount: 1,
          savedMatchCount: 0,
          messageCount: 0,
        }),
        headers: {
          'content-type': 'application/json',
          Origin: 'https://play.example.com',
        },
        method: 'POST',
      }),
      h.env,
      h.deps,
    );

    expect(response.status).toBe(204);
    expect(h.tcpConnect).not.toHaveBeenCalled();
    expect(allMetricText(h.analytics)).toContain('app_fibs_lobby_ready');
    expect(allMetricText(h.analytics)).toContain('fibs_lobby');
    expect(allMetricText(h.analytics)).not.toContain('BlunderBot');
  });

  test('app analytics preflight uses the origin allowlist', async () => {
    const h = makeTestHarness({ allowedOrigins: 'https://play.example.com' });

    const allowed = await handleRequest(
      new Request('https://proxy.example.com/analytics', {
        headers: { Origin: 'https://play.example.com' },
        method: 'OPTIONS',
      }),
      h.env,
      h.deps,
    );
    const rejected = await handleRequest(
      new Request('https://proxy.example.com/analytics', {
        headers: { Origin: 'https://attacker.example.com' },
        method: 'OPTIONS',
      }),
      h.env,
      h.deps,
    );

    expect(allowed.status).toBe(204);
    expect((allowed as Response).headers.get('access-control-allow-origin')).toBe(
      'https://play.example.com',
    );
    expect(rejected.status).toBe(403);
  });

  test('app analytics rejects non-app events and untrusted origins', async () => {
    const h = makeTestHarness({ allowedOrigins: 'https://play.example.com' });

    const badEvent = await handleRequest(
      new Request('https://proxy.example.com/analytics', {
        body: JSON.stringify({ event: 'raw_fibs_payload', user: 'joe' }),
        headers: {
          'content-type': 'application/json',
          Origin: 'https://play.example.com',
        },
        method: 'POST',
      }),
      h.env,
      h.deps,
    );
    const badOrigin = await handleRequest(
      new Request('https://proxy.example.com/analytics', {
        body: JSON.stringify({ event: 'app_start' }),
        headers: {
          'content-type': 'application/json',
          Origin: 'https://attacker.example.com',
        },
        method: 'POST',
      }),
      h.env,
      h.deps,
    );

    expect(badEvent.status).toBe(400);
    expect(badOrigin.status).toBe(403);
    expect(allMetricText(h.analytics)).toContain('app_analytics_reject');
    expect(allMetricText(h.analytics)).not.toContain('joe');
  });
});
