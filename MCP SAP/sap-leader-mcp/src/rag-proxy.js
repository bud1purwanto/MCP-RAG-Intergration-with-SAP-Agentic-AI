#!/usr/bin/env node
// rag-proxy.js — stdio → HTTP proxy untuk RAG MCP server
// Membaca JSON-RPC dari stdin, forward ke HTTP endpoint, tulis response ke stdout.

const RAG_URL = process.env.RAG_URL || 'http://192.168.1.162:8090/mcp';
const RAG_TOKEN = process.env.RAG_TOKEN || 'Trias123';

import { createInterface } from 'node:readline';

const rl = createInterface({ input: process.stdin, terminal: false });

let pending = 0;
let inputClosed = false;

function maybeExit() {
  if (inputClosed && pending === 0) process.exit(0);
}

rl.on('line', async (line) => {
  const trimmed = line.trim();
  if (!trimmed) return;

  let msg;
  try {
    msg = JSON.parse(trimmed);
  } catch {
    return;
  }

  pending++;
  try {
    const res = await fetch(RAG_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RAG_TOKEN}`
      },
      body: JSON.stringify(msg),
      signal: AbortSignal.timeout(30000)
    });

    const text = await res.text();
    // Ensure the response is a single line (MCP stdio requires newline-delimited JSON)
    process.stdout.write(text.replace(/\n/g, '') + '\n');
  } catch (err) {
    const errResponse = {
      jsonrpc: '2.0',
      id: msg.id ?? null,
      error: { code: -32000, message: `RAG proxy error: ${err.message}` }
    };
    process.stdout.write(JSON.stringify(errResponse) + '\n');
  } finally {
    pending--;
    maybeExit();
  }
});

rl.on('close', () => { inputClosed = true; maybeExit(); });

process.stderr.write(`RAG Proxy started → ${RAG_URL}\n`);
