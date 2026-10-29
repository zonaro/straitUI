#!/usr/bin/env node
/**
 * Local-only JSONL RPC bridge for the Flutter app.
 * Conversion is delegated to the upstream `strait` binary, never reimplemented.
 * The viewer is deliberately read-only, and emits no binary images or chain-of-thought.
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import readline from 'node:readline';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import initSqlJs from 'sql.js';

const HOME = os.homedir();
const RUNTIMES = ['claude', 'codex', 'opencode'];
const roots = {
  claude: path.join(HOME, '.claude', 'projects'),
  codex: path.join(HOME, '.codex', 'sessions'),
};
const candidateOpenCodeDbs = [
  process.env.STRAIT_UI_OPENCODE_DB,
  path.join(HOME, '.local', 'share', 'opencode', 'opencode.db'),
  process.env.APPDATA && path.join(process.env.APPDATA, 'opencode', 'opencode.db'),
  process.env.LOCALAPPDATA && path.join(process.env.LOCALAPPDATA, 'opencode', 'opencode.db'),
].filter(Boolean);
const openCodeDb = candidateOpenCodeDbs.find((p) => fs.existsSync(p)) ?? candidateOpenCodeDbs[0];
const straitOverride = process.env.STRAIT_UI_STRAIT_BIN;
const straitScriptCandidates = [
  straitOverride && /\.[cm]?js$/i.test(straitOverride) ? straitOverride : null,
  path.resolve(path.dirname(process.execPath), '..', 'lib', 'node_modules', 'strait-cli', 'dist', 'index.js'),
  path.resolve(path.dirname(process.execPath), 'node_modules', 'strait-cli', 'dist', 'index.js'),
  process.env.APPDATA && path.join(process.env.APPDATA, 'npm', 'node_modules', 'strait-cli', 'dist', 'index.js'),
].filter(Boolean);
function straitCommand(args) {
  const jsEntry = straitScriptCandidates.find((candidate) => fs.existsSync(candidate));
  if (jsEntry) return { command: process.execPath, args: [jsEntry, ...args] };
  if (straitOverride) return { command: straitOverride, args };
  return { command: 'strait', args };
}
let sqlPromise;

function assertRuntime(runtime) {
  if (!RUNTIMES.includes(runtime)) throw new Error('Invalid runtime');
}
function walk(root, out = [], depth = 0) {
  if (depth > 8 || !fs.existsSync(root) || out.length >= 10000) return out;
  let entries;
  try { entries = fs.readdirSync(root, { withFileTypes: true }); } catch { return out; }
  for (const entry of entries) {
    const p = path.join(root, entry.name);
    if (entry.isDirectory() && !entry.isSymbolicLink()) walk(p, out, depth + 1);
    else if (entry.isFile() && p.endsWith('.jsonl')) out.push(p);
  }
  return out;
}
function statTime(file) {
  try { return fs.statSync(file).mtimeMs; } catch { return 0; }
}
function sessionId(runtime, file) {
  const base = path.basename(file, '.jsonl');
  return runtime === 'codex' ? (base.match(/[0-9a-f]{8}-[0-9a-f-]{27,}$/i)?.[0] ?? base) : base;
}
function iso(ms) {
  return new Date(ms || Date.now()).toISOString();
}
function short(text, max = 130) {
  return String(text ?? '').replace(/\s+/g, ' ').trim().slice(0, max);
}
function parseJson(line) {
  try { return JSON.parse(line); } catch { return null; }
}
function readJsonLines(file) {
  // Files belong to local agents; reject unexpectedly large individual files.
  if (fs.statSync(file).size > 200 * 1024 * 1024) throw new Error('Session exceeds 200 MB reader limit');
  return fs.readFileSync(file, 'utf8').split(/\r?\n/).map(parseJson).filter(Boolean);
}
function block(type, text, extra = {}) {
  return { type, text: String(text ?? '').slice(0, 200000), ...extra };
}
function collectClaude(value) {
  const items = typeof value === 'string' ? [{ type: 'text', text: value }] : Array.isArray(value) ? value : [];
  return items.flatMap((item) => {
    if (item.type === 'text') return [block('text', item.text)];
    if (item.type === 'tool_use') return [block('tool_call', JSON.stringify(item.input ?? {}, null, 2), { name: item.name ?? 'tool' })];
    if (item.type === 'tool_result') return [block('tool_result', typeof item.content === 'string' ? item.content : (item.content ?? []).filter((p) => p.type === 'text').map((p) => p.text).join('\n'))];
    if (item.type === 'image') return [block('image', '[Image not displayed]')];
    if (item.type === 'thinking') return [block('thinking', '[Private reasoning omitted]')];
    return [];
  });
}
function parseClaude(file) {
  const messages = [];
  let cwd = '';
  for (const row of readJsonLines(file)) {
    if (row.type !== 'user' && row.type !== 'assistant') continue;
    if (typeof row.cwd === 'string') cwd ||= row.cwd;
    const blocks = collectClaude(row.message?.content);
    if (!blocks.length) continue;
    messages.push({ role: row.type, timestamp: row.timestamp ?? '', blocks });
  }
  return { messages, cwd, warnings: [] };
}
function parseCodex(file) {
  const messages = [];
  let cwd = '';
  for (const row of readJsonLines(file)) {
    if (row.type === 'session_meta') cwd = row.payload?.cwd ?? cwd;
    if (row.type !== 'response_item') continue;
    const p = row.payload ?? {};
    if (p.type === 'message' && ['user', 'assistant', 'system'].includes(p.role)) {
      const blocks = (p.content ?? []).filter((c) => ['input_text', 'output_text', 'text'].includes(c.type)).map((c) => block('text', c.text));
      if (blocks.length) messages.push({ role: p.role, timestamp: row.timestamp ?? '', blocks });
    } else if (p.type === 'function_call' || p.type === 'custom_tool_call') {
      messages.push({ role: 'assistant', timestamp: row.timestamp ?? '', blocks: [block('tool_call', p.arguments ?? p.input ?? '', { name: p.name ?? 'tool' })] });
    } else if (p.type === 'function_call_output' || p.type === 'custom_tool_call_output') {
      messages.push({ role: 'tool', timestamp: row.timestamp ?? '', blocks: [block('tool_result', p.output ?? '')] });
    }
  }
  return { messages, cwd, warnings: [] };
}
function sqlFactory() {
  sqlPromise ??= initSqlJs({ locateFile: (name) => path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'node_modules', 'sql.js', 'dist', name) });
  return sqlPromise;
}
async function withDb(fn) {
  if (!openCodeDb || !fs.existsSync(openCodeDb)) return null;
  const SQL = await sqlFactory();
  const db = new SQL.Database(new Uint8Array(fs.readFileSync(openCodeDb)));
  try { return fn(db); } finally { db.close(); }
}
function query(db, statement, params = []) {
  const stmt = db.prepare(statement);
  try {
    stmt.bind(params);
    const rows = [];
    while (stmt.step()) rows.push(stmt.getAsObject());
    return rows;
  } finally { stmt.free(); }
}
function walPending() {
  try { return fs.statSync(openCodeDb + '-wal').size > 0; } catch { return false; }
}
async function listOpenCode() {
  return (await withDb((db) => query(db, 'SELECT id, title, directory, time_created, time_updated FROM session ORDER BY time_updated DESC LIMIT 1000')) ?? []).map((r) => ({
    id: r.id, runtime: 'opencode', title: short(r.title, 100) || 'OpenCode session', preview: short(r.title),
    updatedAt: iso(r.time_updated), cwd: r.directory ?? '', messageCount: null,
  }));
}
async function readOpenCode(id) {
  return withDb((db) => {
    const session = query(db, 'SELECT id, directory, title FROM session WHERE id = ?', [id])[0];
    if (!session) throw new Error('OpenCode session not found');
    const rows = query(db, 'SELECT id, time_created, data FROM message WHERE session_id = ? ORDER BY time_created, id', [id]);
    const parts = query(db, 'SELECT message_id, time_created, data FROM part WHERE session_id = ? ORDER BY time_created, id', [id]);
    const byMessage = new Map();
    for (const p of parts) {
      if (!byMessage.has(p.message_id)) byMessage.set(p.message_id, []);
      byMessage.get(p.message_id).push(p);
    }
    const messages = [];
    for (const m of rows) {
      const meta = parseJson(m.data) ?? {};
      const blocks = [];
      for (const part of byMessage.get(m.id) ?? []) {
        const p = parseJson(part.data) ?? {};
        if (p.type === 'text') blocks.push(block('text', p.text));
        if (p.type === 'reasoning') blocks.push(block('thinking', '[Private reasoning omitted]'));
        if (p.type === 'file') blocks.push(block('image', '[Attachment not displayed]'));
        if (p.type === 'tool') {
          blocks.push(block('tool_call', JSON.stringify(p.state?.input ?? {}, null, 2), { name: p.tool ?? 'tool' }));
          if (p.state?.output || p.state?.error) blocks.push(block('tool_result', p.state.output ?? p.state.error));
        }
      }
      if (blocks.length) messages.push({ role: meta.role === 'assistant' ? 'assistant' : 'user', timestamp: iso(m.time_created), blocks });
    }
    return { messages, cwd: session.directory ?? '', warnings: walPending() ? ['OpenCode has a pending WAL file. The read-only preview may be incomplete.'] : [] };
  });
}
function firstText(messages) {
  for (const msg of messages) {
    if (msg.role !== 'user') continue;
    const found = msg.blocks?.find((b) => b.type === 'text');
    if (found) return short(found.text, 110);
  }
  return '';
}
function pathsFor(runtime) {
  return walk(roots[runtime]).sort((a, b) => statTime(b) - statTime(a));
}
async function list() {
  const items = [];
  for (const runtime of ['claude', 'codex']) {
    for (const file of pathsFor(runtime).slice(0, 500)) {
      let preview = '';
      try {
        // Preview is read from first 256 KB to avoid parsing each entire history.
        const fd = fs.openSync(file, 'r');
        const buf = Buffer.alloc(262144);
        let bytes = 0;
        try { bytes = fs.readSync(fd, buf, 0, buf.length, 0); } finally { fs.closeSync(fd); }
        const head = buf.subarray(0, bytes).toString('utf8').split(/\r?\n/);
        for (const line of head) {
          const row = parseJson(line);
          if (!row) continue;
          if (runtime === 'claude' && row.type === 'user') preview = firstText([{ role: 'user', blocks: collectClaude(row.message?.content) }]);
          if (runtime === 'codex' && row.type === 'response_item' && row.payload?.type === 'message' && row.payload.role === 'user') {
            preview = short(row.payload.content?.find((c) => c.type === 'input_text')?.text);
          }
          if (preview) break;
        }
      } catch { /* skip bad preview */ }
      items.push({ id: sessionId(runtime, file), runtime, title: preview || path.basename(file, '.jsonl'), preview,
        updatedAt: iso(statTime(file)), cwd: '', messageCount: null });
    }
  }
  items.push(...await listOpenCode());
  return items.sort((a, b) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt)).slice(0, 1000);
}
async function getSession(runtime, id) {
  assertRuntime(runtime);
  if (typeof id !== 'string' || !/^[a-zA-Z0-9_-]{4,100}$/.test(id)) throw new Error('Invalid session id');
  if (runtime === 'opencode') {
    const result = await readOpenCode(id);
    if (!result) throw new Error('OpenCode database not found');
    return { id, runtime, ...result };
  }
  const file = pathsFor(runtime).find((f) => sessionId(runtime, f) === id);
  if (!file) throw new Error('Session not found');
  return { id, runtime, ...(runtime === 'claude' ? parseClaude(file) : parseCodex(file)) };
}
function detectCli() {
  const invocation = straitCommand(['--help']);
  const result = spawnSync(invocation.command, invocation.args, { encoding: 'utf8', timeout: 8000, windowsHide: true });
  return !result.error;
}
async function scan() {
  const counts = { claude: pathsFor('claude').length, codex: pathsFor('codex').length, opencode: (await listOpenCode()).length };
  return { providers: RUNTIMES.map((id) => ({ id, available: counts[id] > 0, count: counts[id] })),
    straitInstalled: detectCli(), openCodeWalPending: walPending(),
    nodeVersion: process.version };
}
function execute(command, args, timeoutMs = 120000) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { shell: false, windowsHide: true, env: { ...process.env, FORCE_COLOR: '0', NO_COLOR: '1' } });
    let stdout = '', stderr = '';
    const timer = setTimeout(() => child.kill(), timeoutMs);
    child.stdout.on('data', (b) => { stdout += b.toString(); if (stdout.length > 200000) child.kill(); });
    child.stderr.on('data', (b) => { stderr += b.toString(); if (stderr.length > 200000) child.kill(); });
    child.on('error', (e) => { clearTimeout(timer); reject(e); });
    child.on('close', (code) => {
      clearTimeout(timer);
      if (code !== 0) return reject(new Error(short(stderr || stdout || `Strait exited with code ${code}`, 1000)));
      resolve({ stdout: stdout.replace(/\x1b\[[0-9;]*m/g, ''), stderr: stderr.replace(/\x1b\[[0-9;]*m/g, '') });
    });
  });
}
async function sync({ from, to, sessionId: id }) {
  assertRuntime(from); assertRuntime(to);
  if (from === to) throw new Error('Source and destination must differ');
  await getSession(from, id); // validate identity before passing it to CLI
  if (!detectCli()) throw new Error('Strait CLI is missing. Install with: npm install -g strait-cli');
  if (to === 'opencode') {
    if (!openCodeDb || !fs.existsSync(openCodeDb)) throw new Error('OpenCode database not found');
    if (walPending()) throw new Error('OpenCode WAL is non-empty. Close OpenCode and checkpoint/backup the database before trying again.');
    if (spawnSync(process.platform === 'win32' ? 'sqlite3.exe' : 'sqlite3', ['-version'], { windowsHide: true }).error) {
      throw new Error('sqlite3 CLI is required for a safe OpenCode database write');
    }
  }
  const invocation = straitCommand(['sync', from, to, '--session', id]);
  const result = await execute(invocation.command, invocation.args);
  const found = result.stdout.match(/session id:\s*([^\s]+)/i);
  const targetId = found?.[1] ?? '';
  const resume = targetId ? (to === 'codex' ? `codex resume ${targetId}` : to === 'claude' ? `claude --resume ${targetId}` : `opencode --session ${targetId}`) : '';
  return { ...result, targetId, resume };
}
async function handle(method, params = {}) {
  if (method === 'scan') return scan();
  if (method === 'list') return { sessions: await list() };
  if (method === 'read') return getSession(params.runtime, params.id);
  if (method === 'sync') return sync(params);
  throw new Error('Unknown method');
}

const rl = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });
for await (const line of rl) {
  const request = parseJson(line);
  if (!request || !Number.isInteger(request.id)) continue;
  try { process.stdout.write(JSON.stringify({ id: request.id, result: await handle(request.method, request.params) }) + '\n'); }
  catch (error) { process.stdout.write(JSON.stringify({ id: request.id, error: error?.message ?? 'Unknown error' }) + '\n'); }
}
