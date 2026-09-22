# Browser provider: playwright

Playwright through the repository's own Node toolchain. Chosen by `/sdlc:init` when a
`playwright.config.*` exists. Operations share a persistent browser page: `open` starts a
background helper that writes `{port,pid}` to `.aisdlc/browser/state.json`; every other
operation calls that server so page state (forms, DOM, navigation history) survives across steps.

## Prerequisites

Node ≥ 18, `@playwright/test` in the repo (or `npx playwright` resolvable), browsers installed
(`npx playwright install chromium`). Requires `jq` and `curl` on the runner.

## Operations

### boot-check
npx playwright --version && node -e "require.resolve('playwright')"
Returns: exit 0 when Playwright is available; exit 1 — run `npx playwright install chromium`

### open
mkdir -p .aisdlc/browser
[ -f .aisdlc/browser/pw.mjs ] || cat > .aisdlc/browser/pw.mjs << 'EOF'
import { chromium } from 'playwright';
import { createServer } from 'http';
import { writeFileSync, mkdirSync } from 'fs';
const ST = '.aisdlc/browser/state.json';
const browser = await chromium.launch({ headless: true });
const ctx     = await browser.newContext();
const page    = await ctx.newPage();
const server  = createServer(async (req, res) => {
  const u  = new URL(req.url, 'http://x');
  const op = u.pathname.slice(1);
  const a  = u.searchParams.getAll('a');
  try {
    if      (op === 'open' || op === 'goto') { await page.goto(a[0]); }
    else if (op === 'click')       { await page.locator(a[0]).click(); }
    else if (op === 'fill')        { await page.locator(a[0]).fill(a[1]); }
    else if (op === 'assert-text') {
      const got = await page.locator(a[0]).textContent() ?? '';
      if (!got.includes(a[1])) { res.writeHead(409); res.end('actual: ' + got); return; }
    } else if (op === 'screenshot') {
      const dir = a[0].replace(/\/[^/]+$/, '');
      if (dir) mkdirSync(dir, { recursive: true });
      await page.screenshot({ path: a[0] });
    } else if (op === 'close') {
      res.end('closed'); await ctx.close(); await browser.close(); server.close(); return;
    }
    res.end('ok');
  } catch (e) { res.writeHead(500); res.end(String(e)); }
});
server.listen(0, '127.0.0.1', () => {
  const { port } = server.address();
  writeFileSync(ST, JSON.stringify({ port, pid: process.pid }));
  process.stdout.write('ready:' + port + '\n');
});
EOF
node .aisdlc/browser/pw.mjs serve >.aisdlc/browser/server.log 2>&1 &
i=0; while [ "$i" -lt 100 ] && ! jq -e .port .aisdlc/browser/state.json >/dev/null 2>&1; do sleep 0.1; i=$((i+1)); done
PORT=$(jq -r .port .aisdlc/browser/state.json)
curl -sf "http://localhost:$PORT/open?a=$(jq -rn --arg v '{base-url}' '$v|@uri')"
Returns: server started; page navigated to {base-url}; state.json holds port and pid

### goto
PORT=$(jq -r .port .aisdlc/browser/state.json)
curl -sf "http://localhost:$PORT/goto?a=$(jq -rn --arg v '{url}' '$v|@uri')"
Returns: page navigated to {url}

### click
PORT=$(jq -r .port .aisdlc/browser/state.json)
curl -sf "http://localhost:$PORT/click?a=$(jq -rn --arg v '{selector}' '$v|@uri')"
Returns: element at {selector} clicked

### fill
PORT=$(jq -r .port .aisdlc/browser/state.json)
curl -sf "http://localhost:$PORT/fill?a=$(jq -rn --arg v '{selector}' '$v|@uri')&a=$(jq -rn --arg v '{text}' '$v|@uri')"
Returns: field at {selector} filled with {text}

### assert-text
PORT=$(jq -r .port .aisdlc/browser/state.json)
curl -sf "http://localhost:$PORT/assert-text?a=$(jq -rn --arg v '{selector}' '$v|@uri')&a=$(jq -rn --arg v '{text}' '$v|@uri')"
Returns: exit 0 when element text includes {text}; exit 1 (body: actual text) on mismatch

### screenshot
PORT=$(jq -r .port .aisdlc/browser/state.json)
curl -sf "http://localhost:$PORT/screenshot?a=$(jq -rn --arg v '{path}' '$v|@uri')"
Returns: PNG written to {path}; parent directories created by the server

### close
PORT=$(jq -r .port .aisdlc/browser/state.json)
curl -sf "http://localhost:$PORT/close"
Returns: browser closed; server stopped; .aisdlc/browser/server.log has the session transcript
