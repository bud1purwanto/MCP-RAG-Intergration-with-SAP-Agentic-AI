#!/usr/bin/env node
// index.js — SAP Leader MCP Server (stdio transport, untuk Claude Code / Cowork lokal)

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { registerToolHandlers } from './src/tool-registry.js';

const server = new Server(
  { name: 'sap-leader', version: '1.0.0' },
  { capabilities: { tools: {} } }
);

registerToolHandlers(server, { CallToolRequestSchema, ListToolsRequestSchema });

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('SAP Leader MCP Server running on stdio.');
}

main().catch((err) => {
  console.error('Fatal error starting SAP Leader MCP Server:', err);
  process.exit(1);
});
