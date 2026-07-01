import { connect } from 'cloudflare:sockets';

import { handleRequest, type TcpSocket } from './bridge';

export default {
  fetch(request, env, ctx) {
    return handleRequest(request, env, {
      connectTcp: (address) => connect(address) as TcpSocket,
      createWebSocketPair: () => {
        const pair = new WebSocketPair();
        const [client, server] = Object.values(pair) as [
          WebSocket,
          WebSocket,
        ];
        return { client, server };
      },
      createWebSocketResponse: (webSocket) =>
        new Response(null, {
          status: 101,
          webSocket: webSocket as WebSocket,
        } as ResponseInit & { webSocket: WebSocket }),
      logger: console,
      now: () => Date.now(),
      waitUntil: (promise) => ctx.waitUntil(promise),
      setTimeout: (callback, delayMs) => setTimeout(callback, delayMs),
      clearTimeout: (handle) => clearTimeout(handle),
    });
  },
} satisfies ExportedHandler<Env>;

interface Env {
  ENVIRONMENT?: string;
  VERSION?: string;
  ALLOWED_ORIGINS?: string;
  FIBS_PROXY_ANALYTICS?: {
    writeDataPoint(point: {
      blobs: string[];
      doubles: number[];
      indexes: string[];
    }): void;
  };
}
