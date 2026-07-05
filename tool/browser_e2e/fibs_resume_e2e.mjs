// One-purpose live browser e2e for saved-match resume.
//
// This intentionally proves the path that can regress independently from the
// general FIBS smoke test:
//   autologin -> lobby has a resumable saved match -> click Resume ->
//   /fibs/play loads -> FIBS produces an actionable turn or final result.
//
// The script logs only sanitized probe counters and cookie type names. It never
// prints credentials, raw FIBS lines, who-list rows, chat text, or commands.
import { chromium } from 'playwright';
import { mkdirSync } from 'fs';

const BASE = process.env.BASE_URL ?? 'http://localhost:18088';
const OUT = process.env.OUT ?? 'out';
const RESUME_X = Number(process.env.RESUME_X ?? 220);
const RESUME_Y = Number(process.env.RESUME_Y ?? 416);
const FIBS_ENTRY_X = Number(process.env.FIBS_ENTRY_X ?? 935);
const FIBS_ENTRY_Y = Number(process.env.FIBS_ENTRY_Y ?? 555);
const CONNECT_X = Number(process.env.CONNECT_X ?? 550);
const CONNECT_Y = Number(process.env.CONNECT_Y ?? 595);
const LEAVE_X = Number(process.env.LEAVE_X ?? 220);
const LEAVE_Y = Number(process.env.LEAVE_Y ?? 815);
const LOGOUT_X = Number(process.env.LOGOUT_X ?? 1040);
const LOGOUT_Y = Number(process.env.LOGOUT_Y ?? 42);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

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
  ws.on('close', () => {
    proxyWebSocketClosed = true;
  });
});

const pathOf = () => new URL(page.url()).pathname;

const getProbeState = async () =>
  page.evaluate(() => {
    const probe = globalThis.__fibscliE2EState;
    return typeof probe === 'function' ? probe() : null;
  });

const compactState = (state) => ({
  path: pathOf(),
  loggedIn: state?.loggedIn,
  connected: state?.connected,
  whoListComplete: state?.whoListComplete,
  whoCount: state?.whoCount,
  botCount: state?.botCount,
  savedMatchCount: state?.savedMatchCount,
  savedMatchReadyCount: state?.savedMatchReadyCount,
  savedMatchBusyCount: state?.savedMatchBusyCount,
  savedMatchWaitingCount: state?.savedMatchWaitingCount,
  inGame: state?.inGame,
  playing: state?.playing,
  isMyTurn: state?.isMyTurn,
  canRoll: state?.canRoll,
  canMoveNow: state?.canMoveNow,
  doubleOffered: state?.doubleOffered,
  activeDice: state?.activeDice,
  isGameOver: state?.isGameOver,
  didIWin: state?.didIWin,
  cookieCount: state?.cookieCount,
  lastCookie: state?.lastCookie,
  messageCount: state?.messageCount,
});

const waitForProbe = async (label, predicate, timeoutMs = 45000) => {
  const deadline = Date.now() + timeoutMs;
  let last = null;
  while (Date.now() < deadline) {
    last = await getProbeState();
    if (last && predicate(last)) return last;
    await sleep(500);
  }
  throw new Error(`${label} not reached: ${JSON.stringify(compactState(last))}`);
};

const waitForPath = async (expected, timeoutMs = 15000) => {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (pathOf() === expected) return;
    await sleep(250);
  }
  throw new Error(`path did not become ${expected}; got ${pathOf()}`);
};

const leaveIfInGame = async () => {
  const state = await getProbeState().catch(() => null);
  if (!state?.inGame || pathOf() !== '/fibs/play') return false;
  await page.mouse.click(LEAVE_X, LEAVE_Y);
  await waitForPath('/fibs/bots', 15000).catch(() => {});
  return true;
};

const logoutIfNeeded = async () => {
  const state = await getProbeState().catch(() => null);
  if (!state?.loggedIn) return;
  await leaveIfInGame();
  if (pathOf() !== '/fibs/bots') {
    await page.goto(`${BASE}/fibs/bots`, { waitUntil: 'load' }).catch(() => {});
    await sleep(1000);
  }
  await page.mouse.click(LOGOUT_X, LOGOUT_Y);
};

let loggedOutCleanly = false;
const observations = [];
const observe = async (label) => {
  const state = await getProbeState();
  const compact = compactState(state);
  observations.push({ label, ...compact });
  console.log(`STATE_${label}:`, JSON.stringify(compact));
  return state;
};

try {
  await page.goto(`${BASE}/`, { waitUntil: 'load' });
  await page
    .waitForSelector('flt-glass-pane, flutter-view', { timeout: 30000 })
    .catch(() => {});
  await sleep(2500);
  await page.mouse.click(FIBS_ENTRY_X, FIBS_ENTRY_Y);
  const fibsPathWaitUntil = Date.now() + 15000;
  while (!pathOf().startsWith('/fibs') && Date.now() < fibsPathWaitUntil) {
    await sleep(250);
  }
  if (!pathOf().startsWith('/fibs')) {
    throw new Error(`FIBS click did not update browser path; got ${pathOf()}`);
  }
  await sleep(2500);

  let initial = await getProbeState();
  if (initial?.loggedIn !== true) {
    await page.screenshot({ path: `${OUT}/resume-00-login.png` });
    await page.mouse.click(CONNECT_X, CONNECT_Y);
    await sleep(1000);
    await page.screenshot({ path: `${OUT}/resume-00-after-connect.png` });
  }

  const lobby = await waitForProbe(
    'logged-in FIBS lobby with resumable saved match',
    (state) =>
      state.loggedIn === true &&
      state.connected === true &&
      state.whoListComplete === true &&
      state.whoCount > 0 &&
      state.botCount > 0 &&
      state.inGame === false &&
      state.savedMatchReadyCount > 0,
    60000,
  );
  console.log('STATE_LOBBY:', JSON.stringify(compactState(lobby)));
  await page.screenshot({ path: `${OUT}/resume-01-lobby.png` });

  if (!proxyWebSocketUrl) {
    throw new Error('FIBS proxy WebSocket was not opened');
  }
  if (proxyFramesReceived === 0) {
    throw new Error('FIBS proxy WebSocket opened but received no frames');
  }

  await page.mouse.click(RESUME_X, RESUME_Y);
  await sleep(1000);
  const afterResumeClick = await getProbeState();
  console.log(
    'STATE_AFTER_RESUME_CLICK:',
    JSON.stringify(compactState(afterResumeClick)),
  );
  await page.screenshot({ path: `${OUT}/resume-01-after-click.png` });
  const board = await waitForProbe(
    'resume reached FIBS play board',
    (state) => pathOf() === '/fibs/play' && state.inGame === true,
    60000,
  );
  console.log('STATE_BOARD:', JSON.stringify(compactState(board)));
  await page.screenshot({ path: `${OUT}/resume-02-board.png` });

  const startCookieCount = board.cookieCount ?? 0;
  const deadline = Date.now() + 120000;
  let last = board;
  let observedProgress = false;
  while (Date.now() < deadline) {
    await sleep(5000);
    last = await observe(`WAIT_${observations.length + 1}`);
    if (
      last.isGameOver === true ||
      last.doubleOffered === true ||
      last.canRoll === true ||
      last.canMoveNow === true ||
      (last.cookieCount ?? 0) >= startCookieCount + 3
    ) {
      observedProgress = true;
      break;
    }
  }
  await page.screenshot({ path: `${OUT}/resume-03-after-wait.png` });
  if (!observedProgress) {
    throw new Error(
      `resume board stayed non-actionable: ${JSON.stringify(
        compactState(last),
      )}`,
    );
  }

  await leaveIfInGame();
  await waitForPath('/fibs/bots', 15000);
  await page.mouse.click(LOGOUT_X, LOGOUT_Y);
  const closeWaitUntil = Date.now() + 10000;
  while (!proxyWebSocketClosed && Date.now() < closeWaitUntil) {
    await sleep(500);
  }
  const finalState = await waitForProbe(
    'final logged-out',
    (state) =>
      state.loggedIn === false &&
      state.connected === false &&
      state.whoCount === 0 &&
      state.inGame === false,
    10000,
  );
  console.log('STATE_FINAL:', JSON.stringify(compactState(finalState)));
  console.log(`PROXY_WS: ${proxyWebSocketUrl}`);
  console.log(
    `PROXY_FRAMES: sent=${proxyFramesSent} received=${proxyFramesReceived}`,
  );
  console.log(`PROXY_CLOSED_AFTER_LOGOUT: ${proxyWebSocketClosed}`);
  console.log('PAGE_ERRORS:', JSON.stringify(errors));
  if (!proxyWebSocketClosed) {
    throw new Error('FIBS proxy WebSocket did not close after logout');
  }
  if (errors.length !== 0) {
    throw new Error(`browser errors: ${JSON.stringify(errors)}`);
  }
  loggedOutCleanly = true;
} catch (error) {
  const state = await getProbeState().catch(() => null);
  console.log('STATE_FAILURE:', JSON.stringify(compactState(state)));
  console.log(`PROXY_WS: ${proxyWebSocketUrl || '(none)'}`);
  console.log(
    `PROXY_FRAMES: sent=${proxyFramesSent} received=${proxyFramesReceived}`,
  );
  console.log(`PROXY_CLOSED: ${proxyWebSocketClosed}`);
  console.log('PAGE_ERRORS:', JSON.stringify(errors));
  throw error;
} finally {
  if (!loggedOutCleanly) {
    await logoutIfNeeded().catch(() => {});
  }
  await ctx.close();
  await browser.close();
}
