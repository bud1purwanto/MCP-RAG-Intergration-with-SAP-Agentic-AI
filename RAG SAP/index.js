#!/usr/bin/env node
// index.js — RAG SAP MCP Proxy (stdio → HTTP REST)
// Bridge MCP JSON-RPC protocol ke REST API RAG server.

import { createInterface } from 'node:readline';

const RAG_BASE  = (process.env.RAG_URL || 'http://192.168.1.162:8090/mcp').replace('/mcp', '');
const RAG_TOKEN = process.env.RAG_TOKEN || 'Trias123';

const rl = createInterface({ input: process.stdin, terminal: false });

let pending = 0;
let inputClosed = false;
let toolsCache = null;

function maybeExit() {
  if (inputClosed && pending === 0) process.exit(0);
}

function send(obj) {
  process.stdout.write(JSON.stringify(obj) + '\n');
}

async function fetchTools() {
  if (toolsCache) return toolsCache;
  const res = await fetch(`${RAG_BASE}/tools`, {
    headers: { 'Authorization': `Bearer ${RAG_TOKEN}` },
    signal: AbortSignal.timeout(10000)
  });
  const data = await res.json();
  toolsCache = data.tools || [];
  return toolsCache;
}

async function callTool(toolName, args) {
  const res = await fetch(`${RAG_BASE}/tools/${toolName}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${RAG_TOKEN}`
    },
    body: JSON.stringify(args || {}),
    signal: AbortSignal.timeout(30000)
  });
  return await res.json();
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
    const { method, id, params } = msg;

    if (method === 'initialize') {
      send({
        jsonrpc: '2.0', id,
        result: {
          protocolVersion: params?.protocolVersion || '2024-11-05',
          capabilities: { tools: {} },
          serverInfo: { name: 'rag-sap', version: '1.0.0' }
        }
      });

    } else if (method === 'notifications/initialized') {
      // no response needed

    } else if (method === 'tools/list') {
      const tools = await fetchTools();
      send({ jsonrpc: '2.0', id, result: { tools } });

    } else if (method === 'tools/call') {
      const toolName = params?.name;
      const args = params?.arguments || {};
      const result = await callTool(toolName, args);
      send({
        jsonrpc: '2.0', id,
        result: {
          content: [{ type: 'text', text: JSON.stringify(result, null, 2) }]
        }
      });

    } else {
      send({
        jsonrpc: '2.0', id,
        error: { code: -32601, message: `Method not found: ${method}` }
      });
    }

  } catch (err) {
    send({
      jsonrpc: '2.0',
      id: msg.id ?? null,
      error: { code: -32000, message: `RAG proxy error: ${err.message}` }
    });
  } finally {
    pending--;
    maybeExit();
  }
});

rl.on('close', () => { inputClosed = true; maybeExit(); });

process.stderr.write(`RAG SAP MCP Proxy → ${RAG_BASE}\n`);
