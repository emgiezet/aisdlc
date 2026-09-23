/**
 * omp.mjs — sdlc plugin extension for the omp (Oh My Pi) host.
 *
 * Bridges omp events to the existing sdlc hook scripts so that enforcement
 * that Claude/Codex receive through hooks.json is also active under omp.
 *
 * hooks.json bindings and their omp equivalents:
 *   SessionStart  → session_start  : run hooks/session-start; post context via sendMessage
 *   PreToolUse(Bash) → tool_call (bash) : guard pre-bash; exit 2 = block
 *   Stop          → turn_end        : guard stop; exit 2 = advisory via sendMessage
 *                                     (omp turn_end cannot block; enforcement is advisory)
 *
 * hooks.json has NO PreToolUse binding for Write or Edit, so those events are
 * NOT intercepted here.  The guard's test-weakening rules only fire on bash
 * commands (force push, --no-verify, dangerous rm) and at turn end (deleted/
 * skipped tests).
 *
 * Decision contract (Claude mode, set by CLAUDE_PLUGIN_ROOT):
 *   exit 0          → allow
 *   exit 2 + stderr → block (tool_call) or advisory (turn_end)
 *   any other rc    → fail-open (a broken hook must not brick the session)
 */

import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const PLUGIN_ROOT = dirname(dirname(fileURLToPath(import.meta.url)));
const DEFAULT_TIMEOUT_MS = 5000;

// ── Pure helpers (exported for testing) ──────────────────────────────────────

/**
 * Run a hook subprocess and capture { rc, stdout, stderr }.
 * Returns rc = -1 on ENOENT, spawn error, or timeout (fail-open callers check
 * only rc === 2 for block; -1 is treated as allow).
 */
export async function runHook(scriptPath, args, stdinPayload, env, timeoutMs = DEFAULT_TIMEOUT_MS) {
  return new Promise((resolve) => {
    let child;
    try {
      child = spawn(scriptPath, args, {
        env: { ...process.env, ...env },
        stdio: ['pipe', 'pipe', 'pipe'],
      });
    } catch (err) {
      resolve({ rc: -1, stdout: '', stderr: String(err.message) });
      return;
    }

    let stdout = '';
    let stderr = '';
    let done = false;

    const settle = (rc) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      resolve({ rc, stdout, stderr });
    };

    const timer = setTimeout(() => {
      try { child.kill('SIGTERM'); } catch { /* ignore */ }
      settle(-1);
    }, timeoutMs);

    child.stdout.on('data', (d) => { stdout += d; });
    child.stderr.on('data', (d) => { stderr += d; });
    child.on('close', (code) => settle(code ?? -1));
    child.on('error', () => settle(-1));

    try {
      child.stdin.write(stdinPayload);
      child.stdin.end();
    } catch { /* ignore — subprocess will close without stdin if needed */ }
  });
}

/**
 * Translate guard subprocess result to an omp block decision or null (allow).
 * Claude convention: exit 2 + stderr text = block; exit 0 = allow.
 * Any other rc (timeout, ENOENT, etc.) = fail-open → null.
 */
export function translateGuardDecision(rc, _stdout, stderr) {
  if (rc === 2) {
    return { block: true, reason: stderr.trim() };
  }
  return null;
}

/**
 * Build the JSON input for guard pre-bash (Claude snake_case format).
 */
export function buildBashPayload(command) {
  return JSON.stringify({ tool_input: { command } });
}

/**
 * Build the JSON input for guard stop mode.
 */
export function buildStopPayload(stopHookActive = false) {
  return JSON.stringify({ stop_hook_active: stopHookActive });
}

/**
 * Build the subprocess environment for a hook call.
 * Always sets CLAUDE_PLUGIN_ROOT so guard uses Claude decision mode (exit 2).
 * Sets AISDLC_HEADLESS=1 when there is no UI, matching the bash policy flag.
 */
export function buildEnv(pluginRoot, hasUI = false) {
  const xdgData = process.env.XDG_DATA_HOME ??
    join(process.env.HOME ?? '', '.local', 'share');
  const env = {
    CLAUDE_PLUGIN_ROOT: pluginRoot,
    CLAUDE_PLUGIN_DATA: process.env.CLAUDE_PLUGIN_DATA ??
      join(xdgData, 'claude', 'plugins', 'sdlc'),
  };
  if (!hasUI) {
    env.AISDLC_HEADLESS = '1';
  }
  return env;
}

// ── Extension factory ─────────────────────────────────────────────────────────

export default function sdlcOmpExtension(pi) {
  const guardScript = join(PLUGIN_ROOT, 'hooks', 'guard');
  const sessionStartScript = join(PLUGIN_ROOT, 'hooks', 'session-start');

  const env = (ctx) => buildEnv(PLUGIN_ROOT, ctx?.hasUI ?? false);

  // ── session_start: inject SDLC pipeline context ────────────────────────────
  // Mirrors what Claude/Codex receive as SessionStart additionalContext.
  pi.on('session_start', async (_event, ctx) => {
    try {
      const { rc, stdout } = await runHook(sessionStartScript, [], '{}', env(ctx));
      if (rc !== 0 || !stdout.trim()) return;
      let context = '';
      try {
        const parsed = JSON.parse(stdout);
        context = parsed?.hookSpecificOutput?.additionalContext ?? '';
      } catch {
        /* ignore unparseable output — session-start is non-critical */
      }
      if (context) await pi.sendMessage(context);
    } catch (err) {
      pi.logger?.warn?.('sdlc: session-start hook failed (non-fatal):', String(err?.message));
    }
  });

  // ── tool_call: guard pre-bash for bash commands ────────────────────────────
  // hooks.json binds PreToolUse only for Bash; write/edit are NOT guarded here.
  pi.on('tool_call', async (event, ctx) => {
    if (event.toolName !== 'bash') return;

    const command = String(event.input?.command ?? '');
    try {
      const { rc, stdout, stderr } = await runHook(
        guardScript, ['pre-bash'], buildBashPayload(command), env(ctx),
      );
      const decision = translateGuardDecision(rc, stdout, stderr);
      if (decision) return decision;
    } catch (err) {
      pi.logger?.warn?.('sdlc: guard pre-bash failed (fail-open):', String(err?.message));
    }
  });

  // ── turn_end: advisory stop-gate ────────────────────────────────────────────
  // hooks.json binds Stop (→ guard stop); omp's turn_end cannot block execution
  // so findings are surfaced as a persistent message the agent sees next turn.
  pi.on('turn_end', async (_event, ctx) => {
    try {
      const { rc, stderr } = await runHook(
        guardScript, ['stop'], buildStopPayload(false), env(ctx),
      );
      if (rc === 2 && stderr.trim()) {
        await pi.sendMessage(stderr.trim());
      }
    } catch (err) {
      pi.logger?.warn?.('sdlc: guard stop failed (non-fatal):', String(err?.message));
    }
  });
}
