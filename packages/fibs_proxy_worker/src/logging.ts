import type { BridgeLogger } from './bridge';

/**
 * What may appear in a log line: a count, a flag, or a name from a closed set
 * (a route, a reject reason, a close side/reason, an error class).
 *
 * Deliberately NOT `unknown`. The bridge's core promise is that no payload is
 * ever logged, and this type is what enforces it: a raw frame, a TCP chunk, or
 * a decoded FIBS line is a compile error (`npm run check`, gated in CI), not
 * something a reviewer has to catch. Widen it only with a value that is
 * provably not user content.
 */
export type LogValue = number | boolean | LogName | undefined;

/**
 * A name from a closed set: a category the bridge itself chooses, never a value
 * derived from a payload, a header, or a URL.
 */
export type LogName =
  | RouteName
  | RejectReason
  | CloseSide
  | CloseReason
  | HttpMethod
  | ErrorName;

export type RouteName = '/' | '/fibs' | '/healthz' | '/analytics' | 'unknown';

export type RejectReason =
  | 'not_websocket'
  | 'bad_method'
  | 'bad_origin'
  | 'unknown_path'
  | 'oversize'
  | 'bad_json'
  | 'bad_event';

export type CloseSide = 'browser' | 'fibs' | 'worker' | 'timeout' | 'error';

export type CloseReason =
  | 'browser_close'
  | 'tcp_eof'
  | 'idle_timeout'
  | 'oversize'
  | 'websocket_error'
  | 'browser_to_fibs_error'
  | 'bridge_error'
  | 'tcp_connect_failed';

/**
 * The methods the bridge distinguishes. Anything else is rejected as
 * `bad_method` and logged as `other`, so an exotic method token from the wire
 * never reaches the log.
 */
type HttpMethod = 'GET' | 'POST' | 'OPTIONS' | 'other';

/**
 * An error's CLASS name (`TypeError`, `Error`, …). Never its message, which can
 * quote the payload that caused it -- hence the brand: an error name can only
 * come from {@link sanitizedError}.
 */
export type ErrorName = string & { readonly __errorName: unique symbol };

/** The metadata a log line may carry. */
export type LogMetadata = Record<string, LogValue>;

/** Reduce a request method to one the bridge distinguishes. */
export function loggableMethod(method: string): HttpMethod {
  switch (method) {
    case 'GET':
    case 'POST':
    case 'OPTIONS':
      return method;
    default:
      return 'other';
  }
}

/** The error's class name only -- the message is dropped, never trusted. */
export function sanitizedError(error: unknown): { name: ErrorName } {
  const name = error instanceof Error ? error.name : typeof error;
  return { name: name as ErrorName };
}

export function logInfo(
  logger: BridgeLogger,
  event: string,
  metadata: LogMetadata = {},
) {
  logger.info(event, metadata);
}

export function logWarn(
  logger: BridgeLogger,
  event: string,
  metadata: LogMetadata = {},
) {
  logger.warn(event, metadata);
}

export function logError(
  logger: BridgeLogger,
  event: string,
  error: unknown,
  metadata: LogMetadata = {},
) {
  logger.error(event, {
    ...metadata,
    errorName: sanitizedError(error).name,
  });
}
