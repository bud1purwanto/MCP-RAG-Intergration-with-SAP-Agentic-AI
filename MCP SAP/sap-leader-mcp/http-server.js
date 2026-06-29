#!/usr/bin/env node
// http-server.js — SAP Leader MCP Server via HTTP (Streamable HTTP transport)
// Untuk akses jarak jauh dalam jaringan lokal/VPN. Wajib Bearer token.
// Setiap request membuat instance Server + transport baru (stateless) —
// aman untuk multi-client tanpa session affinity.

import express from 'express';
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { registerToolHandlers } from './src/tool-registry.js';

const PORT = process.env.MCP_HTTP_PORT || 8091;
const HOST = process.env.MCP_HTTP_HOST || '0.0.0.0';
const AUTH_TOKEN = process.env.MCP_HTTP_TOKEN || 'change-me-token';

const app = express();
app.use(express.json());

function requireAuth(req, res, next) {
  const header = req.headers['authorization'] || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token || token !== AUTH_TOKEN) {
    return res.status(401).json({
      jsonrpc: '2.0',
      error: { code: -32001, message: 'Unauthorized: missing or invalid Bearer token' },
      id: null
    });
  }
  next();
}

function buildServer() {
  const server = new Server({ name: 'sap-leader', version: '1.0.0' }, { capabilities: { tools: {} } });
  registerToolHandlers(server, { CallToolRequestSchema, ListToolsRequestSchema });
  return server;
}

// Health check tanpa auth (untuk monitoring saja, tidak bocorkan data SAP)
app.get('/health', (req, res) => res.json({ status: 'ok', server: 'sap-leader-mcp', transport: 'http' }));

app.post('/mcp', requireAuth, async (req, res) => {
  // Stateless: instance server+transport baru per request, ditutup setelah selesai.
  const server = buildServer();
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined, // stateless: tiap request independen, tidak perlu initialize dulu
    enableJsonResponse: true
  });

  res.on('close', () => {
    transport.close();
    server.close();
  });

  try {
    await server.connect(transport);
    await transport.handleRequest(req, res, req.body);
  } catch (err) {
    if (!res.headersSent) {
      res.status(500).json({
        jsonrpc: '2.0',
        error: { code: -32000, message: err.message },
        id: req.body?.id ?? null
      });
    }
  }
});

app.listen(PORT, HOST, () => {
  console.error(`SAP Leader MCP HTTP Server listening on http://${HOST}:${PORT}/mcp`);
  console.error(`Auth: Bearer token required (set via MCP_HTTP_TOKEN env var)`);
});
