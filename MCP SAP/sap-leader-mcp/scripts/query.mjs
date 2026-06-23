// query.mjs — sequential MCP client untuk testing/debugging
// Usage: node scripts/query.mjs req1.json req2.json ...
// Atau: node scripts/query.mjs - (baca JSON array dari stdin)

import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readFileSync } from 'node:fs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SERVER = join(__dirname, '..', 'index.js');

// Requests dari argumen atau hard-coded untuk penggunaan programatik
const requests = JSON.parse(process.env.MCP_REQUESTS || '[]');

const proc = spawn('node', [SERVER], { stdio: ['pipe', 'pipe', 'inherit'] });

const rl = createInterface({ input: proc.stdout });
const pending = new Map();

rl.on('line', (line) => {
  if (!line.trim()) return;
  try {
    const msg = JSON.parse(line);
    const res = pending.get(msg.id);
    if (res) res(msg);
  } catch (_) {}
});

function call(id, method, params) {
  return new Promise((resolve) => {
    pending.set(id, resolve);
    proc.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
  });
}

async function run() {
  const results = [];
  for (let i = 0; i < requests.length; i++) {
    const { method, params } = requests[i];
    const r = await call(i + 1, method || 'tools/call', params);
    results.push(r);
  }
  proc.stdin.end();
  console.log(JSON.stringify(results, null, 2));
}

run().catch((e) => { console.error(e); process.exit(1); });
