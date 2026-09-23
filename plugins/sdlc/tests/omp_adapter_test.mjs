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

test('write tool with t.Skip content is allowed (no write binding in hooks.json)', async () => {
  // hooks.json has PreToolUse only for Bash, so write/edit must pass through.
  // A test-weakening write like 't.Skip(...)' must not be intercepted.
  const pi = makeMockPi();
  sdlcOmpExtension(pi);

  const result = await pi.call(
    'tool_call',
    { toolName: 'write', input: { path: 'foo_test.go', content: 't.Skip("weakening")' } },
  );

  assert.equal(result, undefined, 'write tool must not be intercepted (no write binding)');
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
  // The adapter only registers on tool_call for bash; all other tool names
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
