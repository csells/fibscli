import { vi } from 'vitest';

import type {
  AnalyticsDataPoint,
  BridgeDependencies,
  BridgeEnvironment,
  TcpSocket,
} from '../src/bridge';

export class FakeWebSocket {
  accepted = false;
  closeCode?: number;
  closeReason?: string;
  sent: unknown[] = [];

  private listeners = new Map<string, Array<(event: any) => void>>();

  accept() {
    this.accepted = true;
  }

  send(message: unknown) {
    this.sent.push(message);
  }

  close(code?: number, reason?: string) {
    this.closeCode = code;
    this.closeReason = reason;
    this.dispatch('close', { code, reason });
  }

  addEventListener(event: string, listener: (event: any) => void) {
    const listeners = this.listeners.get(event) ?? [];
    listeners.push(listener);
    this.listeners.set(event, listeners);
  }

  dispatchMessage(data: unknown) {
    this.dispatch('message', { data });
  }

  dispatchClose(code = 1000, reason = 'test close') {
    this.dispatch('close', { code, reason });
  }

  dispatchError(error = new Error('socket error')) {
    this.dispatch('error', { error });
  }

  private dispatch(event: string, payload: any) {
    for (const listener of this.listeners.get(event) ?? []) {
      listener(payload);
    }
  }
}

export class FakeTcpSocket implements TcpSocket {
  readonly written: Uint8Array[] = [];
  private readableController!: ReadableStreamDefaultController<Uint8Array>;
  private resolveClosed!: () => void;
  private rejectClosed!: (error: unknown) => void;

  readonly opened = Promise.resolve({});
  readonly closed = new Promise<void>((resolve, reject) => {
    this.resolveClosed = resolve;
    this.rejectClosed = reject;
  });

  closeCalls = 0;

  readonly readable = new ReadableStream<Uint8Array>({
    start: (controller) => {
      this.readableController = controller;
    },
  });

  readonly writable = new WritableStream<Uint8Array>({
    write: (chunk) => {
      this.written.push(new Uint8Array(chunk));
    },
  });

  push(data: string | Uint8Array) {
    this.readableController.enqueue(
      typeof data === 'string' ? new TextEncoder().encode(data) : data,
    );
  }

  end() {
    this.readableController.close();
  }

  error(error = new Error('tcp read failed')) {
    this.readableController.error(error);
  }

  rejectClosedPromise(error = new Error('tcp closed failed')) {
    this.rejectClosed(error);
  }

  async close() {
    this.closeCalls += 1;
    this.resolveClosed();
  }
}

export class FakeAnalytics {
  points: AnalyticsDataPoint[] = [];

  writeDataPoint(point: AnalyticsDataPoint) {
    this.points.push(point);
  }
}

export class FakeTimers {
  private nowMs = 0;
  private nextHandle = 1;
  private readonly timers = new Map<
    number,
    { callback: () => void; dueAt: number }
  >();

  setTimeout(callback: () => void, delayMs: number) {
    const handle = this.nextHandle;
    this.nextHandle += 1;
    this.timers.set(handle, { callback, dueAt: this.nowMs + delayMs });
    return handle as ReturnType<typeof setTimeout>;
  }

  clearTimeout(handle: ReturnType<typeof setTimeout>) {
    this.timers.delete(handle as number);
  }

  advanceBy(ms: number) {
    this.nowMs += ms;
    const dueTimers = [...this.timers.entries()]
      .filter(([, timer]) => timer.dueAt <= this.nowMs)
      .sort((a, b) => a[1].dueAt - b[1].dueAt);

    for (const [handle, timer] of dueTimers) {
      if (!this.timers.delete(handle)) continue;
      timer.callback();
    }
  }
}

export function makeTestHarness(
  options: {
    allowedOrigins?: string;
    idleTimeoutMs?: number;
    timers?: FakeTimers;
  } = {},
) {
  const client = new FakeWebSocket();
  const server = new FakeWebSocket();
  const tcp = new FakeTcpSocket();
  const analytics = new FakeAnalytics();
  const logs: unknown[] = [];
  const tcpConnect = vi.fn(async () => tcp);

  const env: BridgeEnvironment = {
    ENVIRONMENT: 'test',
    VERSION: 'unit',
    ALLOWED_ORIGINS: options.allowedOrigins ?? '',
    FIBS_PROXY_ANALYTICS: analytics,
  };

  const deps: BridgeDependencies<{
    status: number;
    text(): Promise<string>;
    webSocket: FakeWebSocket;
  }> = {
      connectTcp: tcpConnect,
      createWebSocketPair: () => ({ client, server }),
      createWebSocketResponse: (webSocket) => ({
        status: 101,
        text: async () => '',
        webSocket: webSocket as FakeWebSocket,
      }),
      logger: {
        info: (...args: unknown[]) => logs.push(['info', ...args]),
        warn: (...args: unknown[]) => logs.push(['warn', ...args]),
        error: (...args: unknown[]) => logs.push(['error', ...args]),
      },
      now: () => Date.now(),
      waitUntil: (promise) => {
        promise.catch(() => undefined);
      },
      idleTimeoutMs: options.idleTimeoutMs,
      setTimeout: options.timers
        ? (callback, delayMs) => options.timers!.setTimeout(callback, delayMs)
        : undefined,
      clearTimeout: options.timers
        ? (handle) => options.timers!.clearTimeout(handle)
        : undefined,
    };

  return { analytics, client, deps, env, logs, server, tcp, tcpConnect };
}

export async function flushAsync() {
  await new Promise((resolve) => setTimeout(resolve, 0));
}

export function decode(data: unknown) {
  if (data instanceof Uint8Array) return new TextDecoder().decode(data);
  if (data instanceof ArrayBuffer) return new TextDecoder().decode(data);
  return String(data);
}

export function allMetricText(analytics: FakeAnalytics) {
  return JSON.stringify(analytics.points);
}
