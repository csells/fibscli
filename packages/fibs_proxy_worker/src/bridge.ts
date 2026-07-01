import {
  BRIDGE_PATHS,
  FIBS_TARGET,
  HEALTH_PATH,
} from './config';
import {
  DEFAULT_IDLE_TIMEOUT_MS,
  DEFAULT_PRE_CLIENT_IDLE_TIMEOUT_MS,
  MAX_MESSAGE_BYTES,
} from './limits';
import { logError, logInfo, logWarn, sanitizedError } from './logging';

export interface AnalyticsDataPoint {
  blobs: string[];
  doubles: number[];
  indexes: string[];
}

export interface AnalyticsEngineDataset {
  writeDataPoint(point: AnalyticsDataPoint): void;
}

export interface BridgeEnvironment {
  ENVIRONMENT?: string;
  VERSION?: string;
  ALLOWED_ORIGINS?: string;
  FIBS_PROXY_ANALYTICS?: AnalyticsEngineDataset;
}

export interface BridgeLogger {
  info(...args: unknown[]): void;
  warn(...args: unknown[]): void;
  error(...args: unknown[]): void;
}

export interface TcpSocket {
  readable: ReadableStream<Uint8Array>;
  writable: WritableStream<Uint8Array>;
  opened?: Promise<unknown>;
  closed?: Promise<unknown>;
  close(): Promise<void> | void;
}

export interface WebSocketLike {
  accept(options?: unknown): void;
  addEventListener(type: string, listener: (event: any) => void): void;
  close(code?: number, reason?: string): void;
  send(message: string | ArrayBuffer | ArrayBufferView): void;
}

export interface BridgeResponseLike {
  status: number;
  text(): Promise<string>;
}

export interface BridgeDependencies<R extends BridgeResponseLike = Response> {
  connectTcp(
    address: typeof FIBS_TARGET,
  ): Promise<TcpSocket> | TcpSocket;
  createWebSocketPair(): {
    client: WebSocketLike;
    server: WebSocketLike;
  };
  createWebSocketResponse(webSocket: WebSocketLike): R;
  logger: BridgeLogger;
  now(): number;
  waitUntil?(promise: Promise<void>): void;
  setTimeout?(
    callback: () => void,
    delayMs: number,
  ): ReturnType<typeof setTimeout>;
  clearTimeout?(handle: ReturnType<typeof setTimeout>): void;
  idleTimeoutMs?: number;
  preClientIdleTimeoutMs?: number;
}

type RouteName = '/' | '/fibs' | '/healthz' | 'unknown';

interface MetricEvent {
  type: string;
  route: RouteName;
  result?: string;
  rejectReason?: string;
  closeSide?: string;
  closeReason?: string;
  originCategory?: string;
  colo?: string;
  country?: string;
  clientKind?: string;
  requestCount?: number;
  acceptedCount?: number;
  rejectedCount?: number;
  tcpConnectMs?: number;
  firstByteMs?: number;
  durationMs?: number;
  browserToFibsMessages?: number;
  fibsToBrowserMessages?: number;
  browserToFibsBytes?: number;
  fibsToBrowserBytes?: number;
  closeCount?: number;
  errorCount?: number;
  idleTimeoutCount?: number;
  oversizeCount?: number;
}

interface RequestContext {
  originCategory: string;
  route: RouteName;
  colo: string;
  country: string;
}

interface SessionStats {
  startedAt: number;
  firstFibsByteAt?: number;
  browserToFibsMessages: number;
  fibsToBrowserMessages: number;
  browserToFibsBytes: number;
  fibsToBrowserBytes: number;
  closeCount: number;
  errorCount: number;
  idleTimeoutCount: number;
  oversizeCount: number;
}

export async function handleRequest<
  R extends BridgeResponseLike = Response,
>(
  request: Request,
  env: BridgeEnvironment,
  deps: BridgeDependencies<R>,
): Promise<Response | R> {
  const url = new URL(request.url);
  const route = routeName(url.pathname);
  const originCategory = categorizeOrigin(request, env);
  const context: RequestContext = {
    ...requestLocation(request),
    originCategory,
    route,
  };

  if (route === '/healthz') {
    emitMetric(env, deps, {
      ...context,
      type: 'bridge_request',
      result: 'health',
      requestCount: 1,
    });
    return new Response('ok', { status: 200 });
  }

  if (!BRIDGE_PATHS.has(url.pathname)) {
    return reject(request, env, deps, {
      status: 404,
      context,
      reason: 'unknown_path',
    });
  }

  if (request.method !== 'GET') {
    return reject(request, env, deps, {
      status: 405,
      context,
      reason: 'bad_method',
    });
  }

  if (request.headers.get('Upgrade')?.toLowerCase() !== 'websocket') {
    return reject(request, env, deps, {
      status: 426,
      context,
      reason: 'not_websocket',
    });
  }

  if (originCategory === 'rejected') {
    return reject(request, env, deps, {
      status: 403,
      context,
      reason: 'bad_origin',
    });
  }

  emitMetric(env, deps, {
    ...context,
    type: 'bridge_request',
    result: 'accepted',
    requestCount: 1,
    acceptedCount: 1,
  });

  const pair = deps.createWebSocketPair();
  pair.server.accept({ allowHalfOpen: true });
  const session = bridgeSession(pair.server, env, deps, context);
  deps.waitUntil?.(session);

  return deps.createWebSocketResponse(pair.client);
}

function reject<R extends BridgeResponseLike>(
  request: Request,
  env: BridgeEnvironment,
  deps: BridgeDependencies<R>,
  options: {
    context: RequestContext;
    reason: string;
    status: number;
  },
) {
  emitMetric(env, deps, {
    ...options.context,
    type: 'bridge_request',
    result: 'rejected',
    rejectReason: options.reason,
    requestCount: 1,
    rejectedCount: 1,
  });
  emitMetric(env, deps, {
    ...options.context,
    type: 'session_reject',
    result: 'rejected',
    rejectReason: options.reason,
    rejectedCount: 1,
  });
  logWarn(deps.logger, 'session_reject', {
    method: request.method,
    reason: options.reason,
    route: options.context.route,
    status: options.status,
  });
  return new Response(options.reason, {
    headers: options.status === 426 ? { Upgrade: 'websocket' } : undefined,
    status: options.status,
  });
}

async function bridgeSession<R extends BridgeResponseLike>(
  webSocket: WebSocketLike,
  env: BridgeEnvironment,
  deps: BridgeDependencies<R>,
  context: RequestContext,
) {
  const stats: SessionStats = {
    startedAt: deps.now(),
    browserToFibsMessages: 0,
    fibsToBrowserMessages: 0,
    browserToFibsBytes: 0,
    fibsToBrowserBytes: 0,
    closeCount: 0,
    errorCount: 0,
    idleTimeoutCount: 0,
    oversizeCount: 0,
  };

  emitMetric(env, deps, {
    ...context,
    type: 'session_start',
    result: 'accepted',
    acceptedCount: 1,
  });
  logInfo(deps.logger, 'session_start', {
    route: context.route,
  });

  let socket: TcpSocket | undefined;
  let socketClosed: Promise<unknown> | undefined;
  let reader: ReadableStreamDefaultReader<Uint8Array> | undefined;
  let writer: WritableStreamDefaultWriter<Uint8Array> | undefined;
  let closed = false;
  let clientDataSent = false;
  let idleTimer: ReturnType<typeof setTimeout> | undefined;

  const resetIdleTimer = () => {
    if (!deps.setTimeout) return;
    if (idleTimer !== undefined) deps.clearTimeout?.(idleTimer);
    const delayMs = clientDataSent
      ? (deps.idleTimeoutMs ?? DEFAULT_IDLE_TIMEOUT_MS)
      : (deps.preClientIdleTimeoutMs ?? DEFAULT_PRE_CLIENT_IDLE_TIMEOUT_MS);
    idleTimer = deps.setTimeout(() => {
      stats.idleTimeoutCount += 1;
      emitMetric(env, deps, {
        ...context,
        type: 'limit_hit',
        result: 'rejected',
        closeSide: 'timeout',
        closeReason: 'idle_timeout',
        idleTimeoutCount: 1,
      });
      void finish('timeout', 'idle_timeout', 1001);
    }, delayMs);
  };

  const clearIdleTimer = () => {
    if (idleTimer !== undefined) deps.clearTimeout?.(idleTimer);
    idleTimer = undefined;
  };

  const finish = async (
    closeSide: string,
    closeReason: string,
    code = 1000,
  ) => {
    if (closed) return;
    closed = true;
    clearIdleTimer();
    stats.closeCount += 1;

    emitMetric(env, deps, {
      ...context,
      type: 'session_close',
      result: 'closed',
      closeSide,
      closeReason,
      closeCount: stats.closeCount,
      errorCount: stats.errorCount,
      idleTimeoutCount: stats.idleTimeoutCount,
      oversizeCount: stats.oversizeCount,
      durationMs: deps.now() - stats.startedAt,
      firstByteMs: stats.firstFibsByteAt
        ? stats.firstFibsByteAt - stats.startedAt
        : 0,
      browserToFibsMessages: stats.browserToFibsMessages,
      fibsToBrowserMessages: stats.fibsToBrowserMessages,
      browserToFibsBytes: stats.browserToFibsBytes,
      fibsToBrowserBytes: stats.fibsToBrowserBytes,
    });
    logInfo(deps.logger, 'session_close', {
      browserToFibsBytes: stats.browserToFibsBytes,
      browserToFibsMessages: stats.browserToFibsMessages,
      closeReason,
      closeSide,
      fibsToBrowserBytes: stats.fibsToBrowserBytes,
      fibsToBrowserMessages: stats.fibsToBrowserMessages,
    });

    try {
      writer?.releaseLock();
    } catch {
      // ignore release failures during teardown
    }
    try {
      await reader?.cancel();
    } catch {
      // ignore read-cancel failures during teardown
    }
    try {
      await socket?.close();
      await socketClosed;
    } catch (error) {
      logError(deps.logger, 'tcp_close_error', error);
    }
    try {
      webSocket.close(code, closeReason);
    } catch (error) {
      logError(deps.logger, 'websocket_close_error', error);
    }
  };

  try {
    resetIdleTimer();
    const connectStartedAt = deps.now();
    socket = await deps.connectTcp(FIBS_TARGET);
    socketClosed = socket.closed?.catch(() => undefined);
    await socket.opened;
    reader = socket.readable.getReader();
    reader.closed.catch(() => undefined);
    writer = socket.writable.getWriter();
    writer.closed.catch(() => undefined);
    emitMetric(env, deps, {
      ...context,
      type: 'tcp_connected',
      result: 'accepted',
      tcpConnectMs: deps.now() - connectStartedAt,
    });

    webSocket.addEventListener('message', (event) => {
      void handleBrowserMessage(event.data);
    });
    webSocket.addEventListener('close', () => {
      void finish('browser', 'browser_close');
    });
    webSocket.addEventListener('error', (event) => {
      stats.errorCount += 1;
      logError(deps.logger, 'websocket_error', event.error);
      void finish('browser', 'websocket_error', 1011);
    });

    await forwardFibsToBrowser(reader, webSocket, deps, stats, () => {
      if (clientDataSent) resetIdleTimer();
    });
    await finish('fibs', 'tcp_eof');
  } catch (error) {
    if (closed) return;
    stats.errorCount += 1;
    emitMetric(env, deps, {
      ...context,
      type: socket ? 'bridge_error' : 'tcp_connect_failed',
      result: 'error',
      closeSide: 'error',
      closeReason: socket ? 'bridge_error' : 'tcp_connect_failed',
      errorCount: 1,
    });
    logError(deps.logger, socket ? 'bridge_error' : 'tcp_connect_failed', error);
    await finish('error', socket ? 'bridge_error' : 'tcp_connect_failed', 1011);
  }

  async function handleBrowserMessage(data: unknown) {
    if (closed || writer === undefined) return;
    try {
      const bytes = await messageToBytes(data);
      if (bytes.byteLength > MAX_MESSAGE_BYTES) {
        stats.oversizeCount += 1;
        emitMetric(env, deps, {
          ...context,
          type: 'limit_hit',
          result: 'rejected',
          closeSide: 'worker',
          closeReason: 'oversize',
          oversizeCount: 1,
        });
        await finish('worker', 'oversize', 1009);
        return;
      }

      stats.browserToFibsMessages += 1;
      stats.browserToFibsBytes += bytes.byteLength;
      await writer.write(bytes);
      clientDataSent = true;
      resetIdleTimer();
    } catch (error) {
      stats.errorCount += 1;
      logError(deps.logger, 'browser_to_fibs_error', error);
      await finish('error', 'browser_to_fibs_error', 1011);
    }
  }
}

async function forwardFibsToBrowser<R extends BridgeResponseLike>(
  reader: ReadableStreamDefaultReader<Uint8Array>,
  webSocket: WebSocketLike,
  deps: BridgeDependencies<R>,
  stats: SessionStats,
  onChunk: () => void,
) {
  while (true) {
    const result = await reader.read();
    if (result.done) return;
    const chunk = result.value;
    if (stats.firstFibsByteAt === undefined) {
      stats.firstFibsByteAt = deps.now();
    }
    stats.fibsToBrowserMessages += 1;
    stats.fibsToBrowserBytes += chunk.byteLength;
    webSocket.send(chunk);
    onChunk();
  }
}

async function messageToBytes(data: unknown) {
  if (typeof data === 'string') {
    return new TextEncoder().encode(data);
  }
  if (data instanceof Uint8Array) {
    return data;
  }
  if (data instanceof ArrayBuffer) {
    return new Uint8Array(data);
  }
  if (ArrayBuffer.isView(data)) {
    return new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
  }
  if (data instanceof Blob) {
    return new Uint8Array(await data.arrayBuffer());
  }
  return new TextEncoder().encode(String(data));
}

function emitMetric<R extends BridgeResponseLike>(
  env: BridgeEnvironment,
  deps: BridgeDependencies<R>,
  event: MetricEvent,
) {
  try {
    env.FIBS_PROXY_ANALYTICS?.writeDataPoint({
      blobs: [
        event.type,
        env.ENVIRONMENT ?? 'unknown',
        env.VERSION ?? 'unknown',
        event.route,
        event.result ?? '',
        event.rejectReason ?? '',
        event.closeSide ?? '',
        event.closeReason ?? '',
        event.colo ?? '',
        event.country ?? '',
        event.originCategory ?? '',
        event.clientKind ?? 'unknown',
      ],
      doubles: [
        event.requestCount ?? 0,
        event.acceptedCount ?? 0,
        event.rejectedCount ?? 0,
        event.tcpConnectMs ?? 0,
        event.firstByteMs ?? 0,
        event.durationMs ?? 0,
        event.browserToFibsMessages ?? 0,
        event.fibsToBrowserMessages ?? 0,
        event.browserToFibsBytes ?? 0,
        event.fibsToBrowserBytes ?? 0,
        event.closeCount ?? 0,
        event.errorCount ?? 0,
        event.idleTimeoutCount ?? 0,
        event.oversizeCount ?? 0,
      ],
      indexes: [event.type],
    });
  } catch (error) {
    logWarn(deps.logger, 'analytics_error', sanitizedError(error));
  }
}

function routeName(pathname: string): RouteName {
  if (pathname === '/') return '/';
  if (pathname === '/fibs') return '/fibs';
  if (pathname === HEALTH_PATH) return '/healthz';
  return 'unknown';
}

function categorizeOrigin(request: Request, env: BridgeEnvironment) {
  const allowed = (env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  const origin = request.headers.get('Origin');

  if (allowed.length === 0) return origin ? 'allowed' : 'missing';
  if (origin === null) return 'missing';
  return allowed.includes(origin) ? 'allowed' : 'rejected';
}

function requestLocation(request: Request) {
  const cf = (request as Request & {
    cf?: { colo?: unknown; country?: unknown };
  }).cf;

  return {
    colo: typeof cf?.colo === 'string' ? cf.colo : '',
    country: typeof cf?.country === 'string' ? cf.country : '',
  };
}
