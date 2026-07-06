// Design-review screenshotter: drives the served web build with Playwright's
// own headless Chromium (no extension, no FIBS login) and captures the screens
// we're redesigning. Point BASE_URL at a running `flutter run -d web-server`.
//
//   BASE_URL=http://127.0.0.1:9090 OUT=tool/browser_e2e/shots node shots.mjs
//
// Clicks are canvas coordinates (Flutter web paints to a canvas), matching the
// approach in fibs_e2e.mjs. Steps are passed as argv: each is "name" to just
// screenshot, or "name@x,y" to click (x,y) first, then screenshot.
import { chromium } from 'playwright';
import { mkdirSync } from 'fs';

const BASE = process.env.BASE_URL ?? 'http://127.0.0.1:9090';
const OUT = process.env.OUT ?? 'shots';
const W = Number(process.env.W ?? 1280);
const H = Number(process.env.H ?? 920);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

mkdirSync(OUT, { recursive: true });

const steps = process.argv.slice(2);
if (steps.length === 0) steps.push('landing');

const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext({
  viewport: { width: W, height: H },
  deviceScaleFactor: 2,
});
const page = await ctx.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
page.on('console', (m) => {
  const t = m.text();
  if (/error|exception|assert|overflow|fail/i.test(t)) console.log('CONSOLE:', t);
});

try {
  await page.goto(`${BASE}/`, { waitUntil: 'load' });
  await page
    .waitForSelector('flt-glass-pane, flutter-view', { timeout: 30000 })
    .catch(() => {});
  await sleep(5000); // let Flutter boot + fonts settle

  let i = 0;
  for (const step of steps) {
    const [name, coord] = step.split('@');
    if (coord) {
      const [x, y] = coord.split(',').map(Number);
      await page.mouse.click(x, y);
      await sleep(Number(process.env.CLICK_WAIT ?? 2500));
    }
    // Nudge a repaint: a static Flutter-web route can leave the CanvasKit
    // surface blank after a programmatic navigation until an input event.
    await page.mouse.move(W / 2, H / 2);
    await page.mouse.wheel(0, 2);
    await page.mouse.wheel(0, -2);
    await sleep(600);
    const label = String(i).padStart(2, '0');
    await page.screenshot({ path: `${OUT}/${label}-${name}.png` });
    console.log(`shot: ${OUT}/${label}-${name}.png`);
    i++;
  }

  console.log('PAGE_ERRORS:', JSON.stringify(errors));
} finally {
  await ctx.close();
  await browser.close();
}
