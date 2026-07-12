const apexHost = 'playfibs.com';

export default {
  fetch(request, env, _ctx) {
    const url = new URL(request.url);
    if (url.hostname === `www.${apexHost}`) {
      url.hostname = apexHost;
      return Promise.resolve(Response.redirect(url.toString(), 301));
    }
    return env.ASSETS.fetch(request);
  },
} satisfies ExportedHandler<Env>;
