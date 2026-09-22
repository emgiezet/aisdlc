# Browser provider: playwright

Playwright through the repository's own Node toolchain. Chosen by `/sdlc:init` when a
`playwright.config.*` exists. Operations drive one persistent headless Chromium via a small helper
the provider generates at `.aisdlc/browser/pw.mjs` on first **open**.

## Prerequisites

Node ≥ 18, `@playwright/test` in the repo (or `npx playwright` resolvable), browsers installed
(`npx playwright install chromium`).

## Operations

### boot-check
npx playwright --version && node -e "require.resolve('playwright')"
Returns: exit 0 when Playwright is available; exit 1 — run `npx playwright install chromium`

### open
mkdir -p .aisdlc/browser
[ -f .aisdlc/browser/pw.mjs ] || cat > .aisdlc/browser/pw.mjs << 'EOF'
import { chromium } from 'playwright';
import { writeFileSync, existsSync, readFileSync } from 'fs';
const [,, op, ...a] = process.argv;
const ST = '.aisdlc/browser/state.json';
const load = () =>
  existsSync(ST) ? JSON.parse(readFileSync(ST, 'utf8')) : {};
const c = await chromium.launchPersistentContext(
  '.aisdlc/browser/profile',
  { headless: true }
);
const p = c.pages()[0] || await c.newPage();
const st = load();
if (op !== 'open' && op !== 'close' && st.url)
  await p.goto(st.url);
if (op === 'open') {
  await p.goto(a[0]);
  writeFileSync(ST, JSON.stringify({ url: a[0] }));
} else if (op === 'goto') {
  await p.goto(a[0]);
  writeFileSync(ST, JSON.stringify({ url: a[0] }));
} else if (op === 'click') {
  await p.locator(a[0]).click();
} else if (op === 'fill') {
  await p.locator(a[0]).fill(a[1]);
} else if (op === 'assert-text') {
  const got = await p.locator(a[0]).textContent() ?? '';
  if (!got.includes(a[1])) {
    process.stderr.write('actual: ' + got + '\n');
    await c.close(); process.exit(1);
  }
} else if (op === 'screenshot') {
  const dir = a[0].split('/').slice(0, -1).join('/');
  if (dir) (await import('fs')).default.mkdirSync(dir, { recursive: true });
  await p.screenshot({ path: a[0] });
} else if (op === 'close') {
  await c.close(); process.exit(0);
}
await c.close();
EOF
node .aisdlc/browser/pw.mjs open {base-url}
Returns: session started at {base-url}; pw.mjs written to .aisdlc/browser/ if absent

### goto
node .aisdlc/browser/pw.mjs goto {url}
Returns: page navigated to {url}; state.json updated

### click
node .aisdlc/browser/pw.mjs click {selector}
Returns: element at {selector} clicked

### fill
node .aisdlc/browser/pw.mjs fill {selector} {text}
Returns: field filled with {text}

### assert-text
node .aisdlc/browser/pw.mjs assert-text {selector} {text}
Returns: exit 0 when element text includes {text}; exit 1 with actual text on stderr

### screenshot
node .aisdlc/browser/pw.mjs screenshot {path}
Returns: PNG written to {path}; parent directories created

### close
node .aisdlc/browser/pw.mjs close
Returns: context closed; profile persisted to .aisdlc/browser/profile
