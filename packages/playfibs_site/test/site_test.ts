import handler from '../src/index';

interface SeenAssets {
  env: Env;
  seen: Request[];
}

const makeEnv = (): SeenAssets => {
  const seen: Request[] = [];
  const assets = {
    fetch: (request: Request): Promise<Response> => {
      seen.push(request);
      return Promise.resolve(
        new Response('asset-body', {
          status: 200,
          headers: { 'content-type': 'text/html; charset=utf-8' },
        }),
      );
    },
  };
  return { env: { ASSETS: assets as Fetcher } as Env, seen };
};

const ctx = {} as ExecutionContext;

type IncomingRequest = Request<unknown, IncomingRequestCfProperties>;

const incoming = (url: string, init?: RequestInit): IncomingRequest =>
  new Request(url, init) as IncomingRequest;

describe('playfibs site worker', () => {
  it('301-redirects www to the apex preserving path and query', async () => {
    const { env, seen } = makeEnv();
    const response = await handler.fetch(
      incoming('https://www.playfibs.com/privacy?a=1&b=2'),
      env,
      ctx,
    );
    expect(response.status).toBe(301);
    expect(response.headers.get('location')).toBe(
      'https://playfibs.com/privacy?a=1&b=2',
    );
    expect(seen).toHaveLength(0);
  });

  it('301-redirects the www root to the apex root', async () => {
    const { env, seen } = makeEnv();
    const response = await handler.fetch(
      incoming('https://www.playfibs.com/'),
      env,
      ctx,
    );
    expect(response.status).toBe(301);
    expect(response.headers.get('location')).toBe('https://playfibs.com/');
    expect(seen).toHaveLength(0);
  });

  it('serves apex requests from static assets untouched', async () => {
    const { env, seen } = makeEnv();
    const response = await handler.fetch(
      incoming('https://playfibs.com/some/spa/route?q=1'),
      env,
      ctx,
    );
    expect(response.status).toBe(200);
    expect(await response.text()).toBe('asset-body');
    expect(seen).toHaveLength(1);
    expect(seen[0]?.url).toBe('https://playfibs.com/some/spa/route?q=1');
  });

  it('passes non-GET apex requests through to assets', async () => {
    const { env, seen } = makeEnv();
    await handler.fetch(
      incoming('https://playfibs.com/', { method: 'HEAD' }),
      env,
      ctx,
    );
    expect(seen).toHaveLength(1);
    expect(seen[0]?.method).toBe('HEAD');
  });
});
