import type { BridgeLogger } from './bridge';

export function sanitizedError(error: unknown) {
  if (error instanceof Error) {
    return {
      name: error.name,
    };
  }
  return {
    name: typeof error,
  };
}

export function logInfo(
  logger: BridgeLogger,
  event: string,
  metadata: Record<string, unknown> = {},
) {
  logger.info(event, metadata);
}

export function logWarn(
  logger: BridgeLogger,
  event: string,
  metadata: Record<string, unknown> = {},
) {
  logger.warn(event, metadata);
}

export function logError(
  logger: BridgeLogger,
  event: string,
  error: unknown,
  metadata: Record<string, unknown> = {},
) {
  logger.error(event, {
    ...metadata,
    error: sanitizedError(error),
  });
}
