/**
 * omp_adapter_test.mjs — offline tests for the sdlc omp extension adapter.
 *
 * Tests the adapter against the real guard script (no network, no mocks for
 * the guard itself) and verifies fail-open behavior for infrastructure errors.
 *
 * Run: node --test plugins/sdlc/tests/omp_adapter_test.mjs
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { execFileSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';

import sdlcOmpExtension, {
  runHook,
  translateGuardDecision,
  buildBashPayload,
  buildEnv,
} from '../extensions/omp.mjs';

const TESTS_DIR = dirname(fileURLToPath(import.meta.url));
const PLUGIN_ROOT = join(TESTS_DIR, '..');

// ── Test helper ───────────────────────────────────────────────────────────────

/** Minimal pi mock that records registered handlers and captured messages. */
function makeMockPi() {
  const handlers = {};
  const messages = [];
  const warns = [];
  const pi = {
    on(evt, fn) { handlers[evt] = fn; },
    async sendMessage(msg) { messages.push(msg); },
    logger: { warn(...args) { warns.push(args.join(' ')); } },
    /** Call a registered event handler (test helper). */
    async call(evt, event, ctx = { hasUI: false }) {
      return handlers[evt]?.(event, ctx);
    },
    messages,
    warns,
  };
  return pi;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

test('destructive bash (git push --force) is blocked with guard message', async () => {
  const pi = makeMockPi();
  sdlcOmpExtension(pi);

  const result = await pi.call(
    'tool_call',
    { toolName: 'bash', input: { command: 'git push --force origin main' } },
  );

  assert.equal(result?.block, true, 'expected block:true');
  assert.match(
    result?.reason ?? '',
    /guard: force push blocked/,
    `expected guard message in reason; got: ${JSON.stringify(result?.reason)}`,
  );
});

test('benign bash command is allowed', async () => {
  const pi = makeMockPi();
  sdlcOmpExtension(pi);

  const result = await pi.call(
    'tool_call',
    { toolName: 'bash', input: { command: 'echo hello world' } },
  );

  assert.equal(result, undefined, 'benign bash should return undefined (allow)');
});

test('write and edit pass without a planning marker and are gated by one', async (t) => {
  // Runs the real guard pre-write in a throwaway repo, before and after /sdlc:chart's marker.
  const repo = mkdtempSync(join(tmpdir(), 'sdlc-omp-write-'));
  const cwd = process.cwd();
  t.after(() => { process.chdir(cwd); rmSync(repo, { recursive: true, force: true }); });
  execFileSync('git', ['init', '-q', '-b', 'main'], { cwd: repo, stdio: 'pipe' });
  process.chdir(repo);

  const pi = makeMockPi();
  sdlcOmpExtension(pi);
  const call = (toolName, input) => pi.call('tool_call', { toolName, input }, { hasUI: true });
  const edit = (...paths) => ({ input: paths.map((p) => `[${p}#AB12]\nPUT >1:\n+x`).join('\n') });

  assert.equal(await call('write', { path: 'src/app.py', content: 'x' }), undefined,
    'no marker: a write must pass');

  mkdirSync(join(repo, '.aisdlc'));
  writeFileSync(join(repo, '.aisdlc', 'planning-mode'),
    'map: specs/briefs/map-x.md\nsince: 2026-01-01T00:00:00Z\nallow: specs/ .aisdlc/\n');

  const blocked = await call('write', { path: 'src/app.py', content: 'x' });
  assert.equal(blocked?.block, true, 'marker: a write outside allow: must block');
  assert.match(blocked?.reason ?? '', /planning mode/);
  assert.equal(await call('write', { path: 'specs/briefs/map-x.md', content: 'x' }), undefined,
    'marker: the map file must pass');
  assert.equal(await call('write', { path: 'local://plan.md', content: 'x' }), undefined,
    'marker: an internal URL is not a repository path');
  assert.equal((await call('edit', edit('specs/briefs/map-x.md', 'src/app.py')))?.block, true,
    'marker: an edit whose second file is outside allow: must block');
});

test('write and edit that approve a spec are blocked; a draft passes', async (t) => {
  const repo = mkdtempSync(join(tmpdir(), 'sdlc-omp-approve-'));
  const cwd = process.cwd();
  t.after(() => { process.chdir(cwd); rmSync(repo, { recursive: true, force: true }); });
  execFileSync('git', ['init', '-q', '-b', 'main'], { cwd: repo, stdio: 'pipe' });
  process.chdir(repo);

  const pi = makeMockPi();
  sdlcOmpExtension(pi);
  const call = (toolName, input) => pi.call('tool_call', { toolName, input }, { hasUI: true });

  const written = await call('write', { path: 'specs/X-1/spec.md', content: '---\nstatus: approved\n---\n' });
  assert.equal(written?.block, true, 'a write approving a spec must block');
  assert.match(written?.reason ?? '', /approval is the human's signature/);
  const edited = await call('edit', { input: '[specs/X-1/spec.md#AB12]\nPUT 3.=3:\n+status: approved' });
  assert.equal(edited?.block, true, 'an edit row approving a spec must block');
  assert.equal(await call('write', { path: 'specs/X-1/spec.md', content: '---\nstatus: draft\n---\n' }),
    undefined, 'a draft spec must pass');
});

test('missing hook script allows (fail-open) and decision is null', async () => {
  // runHook with a non-existent executable returns rc = -1 (ENOENT).
  // translateGuardDecision must allow (fail-open) on rc !== 2.
  const { rc, stderr } = await runHook(
    '/nonexistent/sdlc-guard-test',
    [],
    '{}',
    { CLAUDE_PLUGIN_ROOT: '/nonexistent' },
  );

  assert.equal(rc, -1, 'spawn error should yield rc = -1');

  const decision = translateGuardDecision(rc, '', stderr);
  assert.equal(decision, null, 'translateGuardDecision should allow (fail-open) on rc = -1');
});

test('unknown tool (read) spawns nothing and returns undefined', async () => {
  // The adapter acts on tool_call only for bash, write and edit; all other tool names
  // must return immediately without calling any subprocess.
  const pi = makeMockPi();
  sdlcOmpExtension(pi);

  const result = await pi.call(
    'tool_call',
    { toolName: 'read', input: { path: '/etc/passwd' } },
  );

  assert.equal(result, undefined, 'unknown tool should return undefined (no block)');
  assert.equal(pi.warns.length, 0, 'no warnings should be logged for unknown tool');
});

test('turn_end sends an unchanged stop advisory once, and again after a clean turn', async (t) => {
  // Every sendMessage starts a new turn; re-sending the same advisory on each turn_end
  // loops the session forever. Runs the real guard in a throwaway repo.
  const repo = mkdtempSync(join(tmpdir(), 'sdlc-omp-stop-'));
  const cwd = process.cwd();
  t.after(() => { process.chdir(cwd); rmSync(repo, { recursive: true, force: true }); });
  const git = (...args) => execFileSync('git', [
    '-c', 'user.email=omp@localhost', '-c', 'user.name=omp', '-c', 'commit.gpgsign=false', ...args,
  ], { cwd: repo, stdio: 'pipe' });
  git('init', '-q', '-b', 'main');
  writeFileSync(join(repo, 'test_sample.py'), 'def test_sample():\n    assert 1\n');
  git('add', 'test_sample.py');
  git('commit', '-q', '-m', 'base');
  process.chdir(repo);

  const pi = makeMockPi();
  sdlcOmpExtension(pi);
  const turnEnd = () => pi.call('turn_end', {}, { hasUI: true });

  git('rm', '-q', 'test_sample.py');
  await turnEnd();
  await turnEnd();
  assert.equal(pi.messages.length, 1, 'unchanged advisory must be sent once');
  assert.match(pi.messages[0], /test_sample\.py/);

  git('checkout', '-q', 'HEAD', '--', 'test_sample.py');
  await turnEnd();
  git('rm', '-q', 'test_sample.py');
  await turnEnd();
  assert.equal(pi.messages.length, 2, 'advisory must return after a clean turn');
});
