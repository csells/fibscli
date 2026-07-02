// Browser e2e for the served Flutter web app, driven by Playwright (its own
// Chromium — no extension needed). Single clean pass, ONE FIBS login:
//
//   / -> /local -> /computer -> click FIBS from / -> app autologins (creds
//   baked in via --dart-define) -> /fibs/bots renders -> logout -> /fibs/login
//
// FIBS etiquette (AGENTS.md): one login per run, log out cleanly. Iterate on
// selectors/coordinates offline; a live run should be a single pass.
//
// Prereqs (see run.sh, which automates them):
//   * web build with creds: flutter build web --release \
//       --dart-define=fibs_uname=$U --dart-define=fibs_pword=$P
//   * hosted proxy: wss://proxy.playfibs.com/fibs
//   * serve build/web, e.g. (cd build/web && python3 -m http.server 8088)
//
//   BASE_URL=http://localhost:8088 OUT=tool/browser_e2e/out node fibs_e2e.mjs
//
// Credentials live only in the build (via .env -> dart-define); this script
// never sees or types them.
import { chromium } from 'playwright';
import { createHash } from 'crypto';
import { mkdirSync, readFileSync, statSync } from 'fs';

const BASE = process.env.BASE_URL ?? 'http://localhost:8088';
const OUT = process.env.OUT ?? 'out';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const sha256 = (path) =>
  createHash('sha256').update(readFileSync(path)).digest('hex');
const shotPath = (name) => `${OUT}/${name}.png`;
const getProbeState = async () =>
  page.evaluate(() => {
    const probe = globalThis.__fibscliE2EState;
    return typeof probe === 'function' ? probe() : null;
  });
const pathOf = () => new URL(page.url()).pathname;

mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext({
  viewport: { width: 1100, height: 850 },
  recordVideo: { dir: `${OUT}/video`, size: { width: 1100, height: 850 } },
});
const page = await ctx.newPage();
const errors = [];
let proxyWebSocketUrl = '';
let proxyFramesReceived = 0;
let proxyFramesSent = 0;
let proxyWebSocketClosed = false;
let proxyTextBuffer = '';
let whoInfoLines = 0;
let whoEndSeen = false;
let knownBotLineSeen = false;
const knownBotNames = new Set([
  'MonteCarlo',
  'BlunderBot',
  'GammonBot',
  'octopus',
  'pubeval',
  'PureTD',
  'wildbg',
]);
const botClients = new Set([
  'ParlorBot',
  'Computer_player',
  'bot_1p_matches_only',
]);
page.on('pageerror', (e) => errors.push(e.message));
page.on('console', (msg) => {
  if (msg.type() === 'error') errors.push(msg.text());
});
page.on('websocket', (ws) => {
  if (!ws.url().includes('proxy.playfibs.com/fibs')) return;
  proxyWebSocketUrl = ws.url();
  ws.on('framesent', () => {
    proxyFramesSent += 1;
  });
  ws.on('framereceived', () => {
    proxyFramesReceived += 1;
  });
  ws.on('framereceived', (frame) => {
    proxyTextBuffer += String(frame.payload ?? '');
    const lines = proxyTextBuffer.split(/\r?\n/);
    proxyTextBuffer = lines.pop() ?? '';
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed === '6') {
        whoEndSeen = true;
        continue;
      }
      if (!trimmed.startsWith('5 ')) continue;
      whoInfoLines += 1;
      const fields = trimmed.split(/\s+/);
      const name = fields[1] ?? '';
      const client = fields[11] ?? '';
      if (knownBotNames.has(name) || botClients.has(client)) {
        knownBotLineSeen = true;
      }
    }
  });
  ws.on('close', () => {
    proxyWebSocketClosed = true;
  });
});

const waitForProbe = async (label, predicate, timeoutMs = 45000) => {
  const deadline = Date.now() + timeoutMs;
  let last = null;
  while (Date.now() < deadline) {
    last = await getProbeState();
    if (last && predicate(last)) return last;
    await sleep(500);
  }
  throw new Error(`${label} probe state not reached: ${JSON.stringify(last)}`);
};

const assertPath = (expected) => {
  const actual = pathOf();
  if (actual !== expected) {
    throw new Error(`expected browser path ${expected}, got ${actual}`);
  }
};

const waitForPath = async (expected, timeoutMs = 15000) => {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (pathOf() === expected) return;
    await sleep(250);
  }
  throw new Error(`path did not become ${expected}; got ${pathOf()}`);
};

const screenshotHash = async (path) => {
  await page.screenshot({ path });
  return sha256(path);
};

const waitForScreenshotChange = async (
  label,
  baselineHash,
  path,
  timeoutMs = 15000,
) => {
  const deadline = Date.now() + timeoutMs;
  let lastHash = '';
  while (Date.now() < deadline) {
    lastHash = await screenshotHash(path);
    if (lastHash !== baselineHash && statSync(path).size > 20000) {
      return lastHash;
    }
    await sleep(500);
  }
  throw new Error(`${label} screenshot did not change from baseline`);
};

try {
  await page.goto(`${BASE}/`, { waitUntil: 'load' });
  await page
    .waitForSelector('flt-glass-pane, flutter-view', { timeout: 30000 })
    .catch(() => {});
  await sleep(4000);
  assertPath('/');
  const landingPath = shotPath('01-landing');
  const localGamePath = shotPath('02-local-game');
  const aiGamePath = shotPath('03-ai-game');
  const botListPath = shotPath('04-botlist');
  const loggedOutPath = shotPath('05-loggedout');
  const landingHash = await screenshotHash(landingPath);
  const initialState = await waitForProbe(
    'initial logged-out',
    (state) =>
      state.loggedIn === false &&
      state.connected === false &&
      state.whoCount === 0 &&
      state.inGame === false,
    10000,
  );

  // Local hot-seat route: direct URL load, not imperative in-app navigation.
  await page.goto(`${BASE}/local`, { waitUntil: 'load' });
  await page
    .waitForSelector('flt-glass-pane, flutter-view', { timeout: 30000 })
    .catch(() => {});
  await sleep(2500);
  assertPath('/local');
  const localGameHash = await waitForScreenshotChange(
    'local game',
    landingHash,
    localGamePath,
  );

  // AI route: direct URL with engine + level query parameters.
  await page.goto(`${BASE}/computer?engine=Gary%20Gammon&level=3`, {
    waitUntil: 'load',
  });
  await page
    .waitForSelector('flt-glass-pane, flutter-view', { timeout: 30000 })
    .catch(() => {});
  await sleep(4000);
  assertPath('/computer');
  const aiGameHash = await waitForScreenshotChange(
    'AI game',
    localGameHash,
    aiGamePath,
    25000,
  );
  if (aiGameHash === landingHash) {
    throw new Error('AI game screenshot matched landing page');
  }

  // FIBS route: real in-app navigation from the landing page, so the test
  // proves the browser address bar follows a user click.
  await page.goto(`${BASE}/`, { waitUntil: 'load' });
  await page
    .waitForSelector('flt-glass-pane, flutter-view', { timeout: 30000 })
    .catch(() => {});
  await sleep(2500);
  assertPath('/');
  await page.mouse.click(935, 555);
  const fibsPathWaitUntil = Date.now() + 15000;
  while (!pathOf().startsWith('/fibs') && Date.now() < fibsPathWaitUntil) {
    await sleep(250);
  }
  if (!pathOf().startsWith('/fibs')) {
    throw new Error(`FIBS click did not update browser path; got ${pathOf()}`);
  }
  const waitUntil = Date.now() + 45000;
  while (
    (!whoEndSeen || !knownBotLineSeen) &&
    Date.now() < waitUntil
  ) {
    await sleep(500);
  }
  await sleep(9000); // connect + who-list populate
  const lobbyState = await waitForProbe('FIBS lobby', (state) => {
    return (
      state.loggedIn === true &&
      state.connected === true &&
      state.autoLoginTried === true &&
      state.hasUser === true &&
      state.whoListComplete === true &&
      state.whoCount > 0 &&
      state.whoInfoCookieCount > 0 &&
      state.botCount > 0 &&
      state.availableBotCount + state.watchableBotCount > 0 &&
      state.inGame === false
    );
  });
  await waitForPath('/fibs/bots');
  await page.screenshot({ path: botListPath });

  if (!proxyWebSocketUrl) {
    throw new Error('FIBS proxy WebSocket was not opened');
  }
  if (proxyFramesReceived === 0) {
    throw new Error('FIBS proxy WebSocket opened but received no frames');
  }
  if (!whoEndSeen) {
    throw new Error(
      `FIBS who-list did not finish: whoInfoLines=${whoInfoLines}`,
    );
  }
  if (!knownBotLineSeen) {
    throw new Error(
      `FIBS who-list had no known bot rows: whoInfoLines=${whoInfoLines}`,
    );
  }
  if (sha256(landingPath) === sha256(botListPath)) {
    throw new Error('FIBS screen screenshot did not change from landing page');
  }

  // good citizen: log out cleanly (Logout is top-right on the bot list)
  await page.mouse.click(1040, 42);
  const closeWaitUntil = Date.now() + 10000;
  while (!proxyWebSocketClosed && Date.now() < closeWaitUntil) {
    await sleep(500);
  }
  await sleep(1500);
  const finalState = await waitForProbe(
    'final logged-out',
    (state) =>
      state.loggedIn === false &&
      state.connected === false &&
      state.whoCount === 0 &&
      state.availableBotCount === 0 &&
      state.watchableBotCount === 0 &&
      state.inGame === false,
    10000,
  );
  await waitForPath('/fibs/login');
  await page.screenshot({ path: loggedOutPath });

  if (!proxyWebSocketClosed) {
    throw new Error('FIBS proxy WebSocket did not close after logout');
  }
  if (sha256(botListPath) === sha256(loggedOutPath)) {
    throw new Error('Logout screenshot did not change from bot list');
  }

  if (errors.length !== 0) {
    throw new Error(`browser errors: ${JSON.stringify(errors)}`);
  }
  console.log(`PROXY_WS: ${proxyWebSocketUrl}`);
  console.log(
    `PROXY_FRAMES: sent=${proxyFramesSent} received=${proxyFramesReceived}`,
  );
  console.log(
    `FIBS_WHO: lines=${whoInfoLines} end=${whoEndSeen} bot=${knownBotLineSeen}`,
  );
  console.log('LOCAL_GAME_SCREEN:', JSON.stringify({ changed: true }));
  console.log('AI_GAME_SCREEN:', JSON.stringify({ changed: true }));
  console.log('APP_STATE_INITIAL:', JSON.stringify(initialState));
  console.log('APP_STATE_LOBBY:', JSON.stringify(lobbyState));
  console.log('APP_STATE_FINAL:', JSON.stringify(finalState));
  console.log(`PROXY_CLOSED_AFTER_LOGOUT: ${proxyWebSocketClosed}`);
  console.log('PAGE_ERRORS:', JSON.stringify(errors));
  console.log(`screenshots + video in ${OUT}/`);
} finally {
  await ctx.close(); // flush video
  await browser.close();
}
