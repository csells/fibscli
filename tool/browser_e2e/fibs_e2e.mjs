// Browser e2e for the FIBS web client, driven by Playwright (its own Chromium —
// no extension needed). Single clean pass, ONE FIBS login:
//
//   landing page -> "Play a bot (FIBS)" -> app autologins (creds baked in via
//   --dart-define) -> live bot list renders (real bots/ratings/games) -> logout
//
// FIBS etiquette (AGENTS.md): one login per run, log out cleanly. Iterate on
// selectors/coordinates offline; a live run should be a single pass.
//
// Prereqs (see run.sh, which automates them):
//   * web build with creds: flutter build web --release \
//       --dart-define=fibs_uname=$U --dart-define=fibs_pword=$P \
//       --dart-define=fibs_proxy_host=127.0.0.1 \
//       --dart-define=fibs_proxy_port=8080 \
//       --dart-define=fibs_proxy_secure=false \
//       --dart-define=fibs_proxy_path=
//   * local developer bridge:  websocat --binary ws-l:127.0.0.1:8080 \
//       tcp:fibs.com:4321 --exit-on-eof
//   * serve build/web, e.g. (cd build/web && python3 -m http.server 8088)
//
//   BASE_URL=http://localhost:8088 OUT=tool/browser_e2e/out node fibs_e2e.mjs
//
// Credentials live only in the build (via .env -> dart-define); this script
// never sees or types them.
import { chromium } from 'playwright';
import { mkdirSync } from 'fs';

const BASE = process.env.BASE_URL ?? 'http://localhost:8088';
const OUT = process.env.OUT ?? 'out';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext({
  viewport: { width: 1100, height: 850 },
  recordVideo: { dir: `${OUT}/video`, size: { width: 1100, height: 850 } },
});
const page = await ctx.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));

try {
  await page.goto(`${BASE}/`, { waitUntil: 'load' });
  await page
    .waitForSelector('flt-glass-pane, flutter-view', { timeout: 30000 })
    .catch(() => {});
  await sleep(4000);
  await page.screenshot({ path: `${OUT}/01-landing.png` });

  // "Play a bot (FIBS)" (centered button) -> the app autologins
  await page.mouse.click(550, 477);
  await sleep(13000); // connect + who-list populate
  await page.screenshot({ path: `${OUT}/02-botlist.png` });

  // good citizen: log out cleanly (Logout is top-right on the bot list)
  await page.mouse.click(1065, 28);
  await sleep(2500);
  await page.screenshot({ path: `${OUT}/03-loggedout.png` });

  console.log('PAGE_ERRORS:', JSON.stringify(errors));
  console.log(`screenshots + video in ${OUT}/`);
} finally {
  await ctx.close(); // flush video
  await browser.close();
}
