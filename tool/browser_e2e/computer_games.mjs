import { chromium, firefox } from 'playwright';
import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const base = process.env.BASE_URL ?? 'http://localhost:9090';
const out =
  process.env.OUT ?? fileURLToPath(new URL('./out/computer', import.meta.url));
const games = Number(process.env.GAMES ?? 3);
mkdirSync(out, { recursive: true });
const browser = process.env.CAMOUFOX_OPTIONS
  ? await firefox.launch(
      JSON.parse(readFileSync(process.env.CAMOUFOX_OPTIONS, 'utf8')),
    )
  : await chromium.launch({
      args: process.env.DEBUG_PORT
        ? [`--remote-debugging-port=${process.env.DEBUG_PORT}`]
        : [],
      headless: process.env.HEADED !== '1',
      ...(process.env.CHROME_BINARY
        ? { executablePath: process.env.CHROME_BINARY }
        : {}),
    });
const context = await browser
  .newContext({
    viewport: { width: 1200, height: 1000 },
    recordVideo: { dir: `${out}/video`, size: { width: 1200, height: 1000 } },
  })
  .catch(async (error) => {
    await browser.close();
    throw error;
  });
const page = await context.newPage().catch(async (error) => {
  await browser.close();
  throw error;
});
const failures = [];
const network = [];
page.on('request', (request) => {
  const u = new URL(request.url());
  network.push({
    host: u.hostname,
    path: u.hostname.includes('cloudflare')
      ? '/challenge-or-telemetry'
      : u.pathname,
  });
});
page.on('console', (message) => {
  if (message.type() === 'error')
    console.error('Console:', message.text().slice(0, 300));
});
const calls = [];
page.on('pageerror', (e) => {
  failures.push(e.message);
  console.error('Browser error:', e.message);
});
page.on('requestfailed', (request) => {
  const u = new URL(request.url());
  console.error('Request failed:', u.hostname, request.failure()?.errorText);
});
page.on('response', async (response) => {
  const url = new URL(response.url());
  if (!url.pathname.startsWith('/v1/')) return;
  if (
    !url.hostname.includes('gnubg-service') &&
    url.hostname !== 'api.gammon.guru'
  )
    return;
  const call = {
    path: url.pathname,
    status: response.status(),
    id: url.searchParams.get('id'),
    level: url.searchParams.get('level'),
  };
  calls.push(call);
  if (url.pathname === '/v1/play/move' && response.status() === 200) {
    const body = await response.json();
    call.play = body.play;
    call.hops = body.hops;
  }
  if (response.status() >= 400)
    failures.push(`${call.path} HTTP ${call.status}`);
});
const snapshot = () =>
  process.env.CAMOUFOX_OPTIONS
    ? page.evaluate('mw:globalThis.__computerE2EState?.()')
    : page.evaluate(() => globalThis.__computerE2EState?.());
async function waitForState(predicate, timeout, label) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    if (predicate(await snapshot())) return;
    await page.waitForTimeout(100);
  }
  throw new Error(label);
}
const shot = (name) => page.screenshot({ path: `${out}/${name}.png` });
const click = async (point) => {
  await page.mouse.click(point[0], point[1]);
  await page.waitForTimeout(100);
};
async function clickText(text) {
  const target = page
    .getByText(text, { exact: true })
    .filter({ visible: true });
  const bounds = await target.boundingBox({ timeout: 5000 });
  if (!bounds) return false;
  await click([bounds.x + bounds.width / 2, bounds.y + bounds.height / 2]);
  return true;
}

const summary = [];
let lastChallengeClick = 0;
let lastStateWrite = 0;
async function answerVisibleChallenge() {
  if (process.env.CAMOUFOX_OPTIONS) return;
  if (Date.now() - lastChallengeClick < 10_000) return;
  for (const frame of page.frames()) {
    if (!frame.url().startsWith('https://challenges.cloudflare.com/')) continue;
    const session = await context.newCDPSession(frame);
    try {
      const tree = await session.send('Accessibility.getFullAXTree');
      const checkbox = tree.nodes.find(
        (n) =>
          n.role?.value === 'checkbox' &&
          n.name?.value === 'Verify you are human',
      );
      if (!checkbox) continue;
      const owner = await frame.frameElement();
      const bounds = await owner.boundingBox();
      if (!bounds || bounds.x < 0 || bounds.y < 0) continue;
      const { model } = await session.send('DOM.getBoxModel', {
        backendNodeId: checkbox.backendDOMNodeId,
      });
      const xs = model.content.filter((_, i) => i % 2 === 0);
      const ys = model.content.filter((_, i) => i % 2 === 1);
      await page.mouse.click(
        bounds.x + Math.min(...xs) + 12,
        bounds.y + (Math.min(...ys) + Math.max(...ys)) / 2,
      );
      lastChallengeClick = Date.now();
      console.log('Clicked visible Turnstile verification checkbox');
    } finally {
      await session.detach();
    }
  }
}
try {
  await page.goto(`${base}/computer?engine=Computer&level=7`);
  await shot('loaded-page');
  await waitForState((s) => s?.ready, 120_000, 'App probe did not initialize');
  if (process.env.CAMOUFOX_OPTIONS)
    await page.evaluate(
      'mw:document.querySelector("flt-semantics-placeholder")?.click()',
    );
  else
    await page.evaluate(() =>
      document.querySelector('flt-semantics-placeholder')?.click(),
    );
  for (let game = 1; game <= games; game++) {
    const start = Date.now();
    const initialCalls = calls.length;
    let humanMoves = 0;
    let lastProgress = Date.now();
    let previousState = '';
    await shot(`game-${game}-start`);
    while (true) {
      assert.deepEqual(failures, [], 'Browser or engine request failed');
      assert.equal(
        await page.getByText(/Computer engine unavailable/).count(),
        0,
        'The UI reported an engine failure',
      );
      await answerVisibleChallenge();
      const state = await snapshot();
      if (Date.now() - lastStateWrite >= 1000) {
        writeFileSync(
          `${out}/live-state.json`,
          JSON.stringify({ state, calls, failures, network }),
        );
        lastStateWrite = Date.now();
      }
      assert.ok(Date.now() - start < 20 * 60_000, 'Game exceeded 20 minutes');
      assert.equal(
        state?.engineErrors ?? 0,
        0,
        'The UI surfaced an engine failure',
      );
      if (!state?.ready) {
        await page.waitForTimeout(100);
        continue;
      }
      const signature = JSON.stringify([
        state.board,
        state.dice,
        state.moveNo,
        state.gameOver,
      ]);
      if (signature !== previousState) {
        lastProgress = Date.now();
        previousState = signature;
      }
      assert.ok(
        Date.now() - lastProgress < (calls.length === 0 ? 180_000 : 90_000),
        `Game stalled: ${JSON.stringify(state)}`,
      );
      if (state.gameOver) {
        await page.getByText(/wins!/).waitFor({ timeout: 10_000 });
        await shot(`game-${game}-finished`);
        const result = {
          game,
          winner: state.winner,
          turns: state.moveNo,
          humanMoves,
          serviceCalls: calls.length - initialCalls,
          seconds: Math.round((Date.now() - start) / 1000),
        };
        assert.ok(
          result.turns > 2 && result.humanMoves > 0 && result.serviceCalls > 0,
          'Game lacked real interaction',
        );
        summary.push(result);
        console.log(JSON.stringify(result));
        assert.ok(
          await clickText(game < games ? 'Yes, Please!' : 'No, Thanks'),
          'Game completion dialog was not visible',
        );
        if (game < games)
          await waitForState(
            (s) => s?.ready && !s.gameOver && s.moveNo < 3,
            10000,
            'New game did not start',
          );
        break;
      }
      const accept = page
        .getByText('Accept', { exact: true })
        .filter({ visible: true });
      if (await accept.count()) {
        await clickText('Accept');
        continue;
      }
      if (state.busy || !state.humanTurn) {
        await page.waitForTimeout(100);
        continue;
      }
      if (state.canRoll) {
        await clickText('Roll');
        continue;
      }
      if (state.canCommit) {
        await click(state.diceTarget);
        continue;
      }
      assert.ok(
        state.legalMoves.length,
        `Human has no actionable move: ${JSON.stringify(state)}`,
      );
      const move = state.legalMoves[0];
      await click(move.source);
      await click(move.destination);
      await waitForState(
        (now) =>
          now && JSON.stringify(now.board) !== JSON.stringify(state.board),
        5000,
        'Board did not change after a UI move',
      );
      humanMoves++;
      if (humanMoves % 10 === 0) {
        console.log(
          `game ${game}/${games}: turn ${state.moveNo}, human moves ${humanMoves}, engine calls ${calls.length}`,
        );
        await shot(`game-${game}-move-${humanMoves}`);
      }
    }
  }
  assert.deepEqual(failures, []);
  console.log(`PASS: ${games} complete games through the real browser UI`);
} catch (error) {
  await shot('failure');
  console.error(error.message);
  process.exitCode = 1;
} finally {
  writeFileSync(
    `${out}/results.json`,
    JSON.stringify(
      {
        summary,
        calls,
        failures,
        finalState: await snapshot().catch(() => null),
      },
      null,
      2,
    ),
  );
  await context.close();
  await browser.close();
}
