export const FIBS_TARGET = {
  hostname: 'fibs.com',
  port: 4321,
} as const;

export const BRIDGE_PATHS = new Set(['/', '/fibs']);
export const HEALTH_PATH = '/healthz';
