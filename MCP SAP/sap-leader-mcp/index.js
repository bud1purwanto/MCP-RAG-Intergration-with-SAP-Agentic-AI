#!/usr/bin/env node
// index.js — SAP Leader MCP Server (stdio transport)
// Registers 12 tools across server management, general query, and ABAP technical access.

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema
} from '@modelcontextprotocol/sdk/types.js';

import * as serverTools from './src/tools/server-tools.js';
import * as queryTools from './src/tools/query-tools.js';
import * as abapTools from './src/tools/abap-tools.js';

// ── Tool definitions (name, description, JSON schema, handler) ──────────
const TOOLS = [
  // Server Management
  {
    name: 'list_servers',
    description:
      'Tampilkan semua SAP server dari config/sap-servers.json beserta SID, host, environment, alias, dan status aktif.',
    inputSchema: { type: 'object', properties: {} },
    handler: serverTools.list_servers
  },
  {
    name: 'set_active_server',
    description:
      'Pilih/ganti server SAP aktif. Terima nama, nomor urut, alias (dev/prod/qa/sandbox), SID, atau IP. Menutup koneksi lama & membuka koneksi baru. Untuk server production wajib konfirmasi (confirm_production=true).',
    inputSchema: {
      type: 'object',
      properties: {
        server_ref: {
          type: 'string',
          description: 'Referensi server: nama, nomor, alias, SID, atau IP.'
        },
        confirm_production: {
          type: 'boolean',
          description: 'Set true untuk mengkonfirmasi pemilihan server production.'
        }
      },
      required: ['server_ref']
    },
    handler: serverTools.set_active_server
  },
  {
    name: 'get_system_info',
    description: 'Panggil RFC_SYSTEM_INFO pada server aktif untuk info sistem (SID, release, DB, host).',
    inputSchema: { type: 'object', properties: {} },
    handler: serverTools.get_system_info
  },
  {
    name: 'get_server_date',
    description: 'Cek tanggal server SAP saat ini dengan membaca TRDAT terbesar dari tabel USR02 (last logon date). Gunakan ini sebelum input tanggal di server yang tanggalnya tidak sesuai kalender nyata (mis. Sandbox New Company TRS).',
    inputSchema: { type: 'object', properties: {} },
    handler: serverTools.get_server_date
  },

  // General SAP Query
  {
    name: 'read_table',
    description:
      'Baca tabel SAP via RFC_READ_TABLE. Berikan nama tabel, daftar fields (opsional), kondisi where (array string ABAP), dan rowcount.',
    inputSchema: {
      type: 'object',
      properties: {
        table: { type: 'string', description: 'Nama tabel SAP, mis. MARA, BKPF.' },
        fields: { type: 'array', items: { type: 'string' }, description: 'Daftar field yang dibaca.' },
        where: {
          type: 'array',
          items: { type: 'string' },
          description: "Kondisi WHERE dalam sintaks ABAP, mis. \"MATNR = '1000'\"."
        },
        rowcount: { type: 'number', description: 'Maksimum baris (0 = semua).' }
      },
      required: ['table']
    },
    handler: queryTools.read_table
  },
  {
    name: 'call_function',
    description: 'Panggil RFC/BAPI apapun pada server aktif dengan parameter bebas.',
    inputSchema: {
      type: 'object',
      properties: {
        function_name: { type: 'string', description: 'Nama function module / BAPI.' },
        parameters: { type: 'object', description: 'Parameter import/tables sesuai signature FM.' }
      },
      required: ['function_name']
    },
    handler: queryTools.call_function
  },
  {
    name: 'get_sap_document',
    description:
      'Ambil header + items dokumen SAP. doc_type: FI | SD_ORDER | MM_PO | PP_ORDER | PM_ORDER.',
    inputSchema: {
      type: 'object',
      properties: {
        doc_type: {
          type: 'string',
          enum: ['FI', 'SD_ORDER', 'MM_PO', 'PP_ORDER', 'PM_ORDER'],
          description: 'Tipe dokumen.'
        },
        doc_number: { type: 'string', description: 'Nomor dokumen.' },
        company_code: { type: 'string', description: 'Company code (untuk dokumen FI).' }
      },
      required: ['doc_type', 'doc_number']
    },
    handler: queryTools.get_sap_document
  },

  // ABAP Technical
  {
    name: 'read_program',
    description: 'Baca source code program/include via READ_REPORT (setara SE38).',
    inputSchema: {
      type: 'object',
      properties: {
        program_name: { type: 'string', description: 'Nama program/report.' },
        include_name: { type: 'string', description: 'Nama include (opsional).' }
      },
      required: ['program_name']
    },
    handler: abapTools.read_program
  },
  {
    name: 'read_table_structure',
    description: 'Baca struktur field dari DD03L + DD02L (setara SE11).',
    inputSchema: {
      type: 'object',
      properties: {
        object_name: { type: 'string', description: 'Nama tabel/struktur.' },
        object_type: { type: 'string', description: 'TABLE | STRUCTURE | VIEW (opsional).' }
      },
      required: ['object_name']
    },
    handler: abapTools.read_table_structure
  },
  {
    name: 'search_programs',
    description: 'Cari program di TRDIR berdasarkan pattern (setara SE80).',
    inputSchema: {
      type: 'object',
      properties: {
        pattern: { type: 'string', description: "Pattern nama, mis. 'ZFI*'." },
        object_type: { type: 'string', description: 'Tipe (SUBC), mis. 1=executable.' },
        max_results: { type: 'number', description: 'Maks hasil.' }
      },
      required: ['pattern']
    },
    handler: abapTools.search_programs
  },
  {
    name: 'read_function_module',
    description: 'Baca interface FM via FUNCTION_IMPORT_INTERFACE + source (setara SE37).',
    inputSchema: {
      type: 'object',
      properties: {
        function_name: { type: 'string', description: 'Nama function module.' }
      },
      required: ['function_name']
    },
    handler: abapTools.read_function_module
  },
  {
    name: 'read_class',
    description: 'Baca definisi class dari SEOCLASS + SEOCPDKEY (setara SE24).',
    inputSchema: {
      type: 'object',
      properties: {
        class_name: { type: 'string', description: 'Nama class.' },
        method_name: { type: 'string', description: 'Nama method (opsional).' }
      },
      required: ['class_name']
    },
    handler: abapTools.read_class
  },
  {
    name: 'get_where_used',
    description: 'Where-used cross-reference dari D010TAB.',
    inputSchema: {
      type: 'object',
      properties: {
        object_name: { type: 'string', description: 'Nama objek (tabel/field).' },
        object_type: { type: 'string', description: 'Tipe objek (opsional).' },
        max_results: { type: 'number', description: 'Maks hasil.' }
      },
      required: ['object_name']
    },
    handler: abapTools.get_where_used
  }
];

const HANDLERS = Object.fromEntries(TOOLS.map((t) => [t.name, t.handler]));

const server = new Server(
  { name: 'sap-leader', version: '1.0.0' },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: TOOLS.map(({ name, description, inputSchema }) => ({ name, description, inputSchema }))
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  const handler = HANDLERS[name];
  if (!handler) {
    return {
      content: [{ type: 'text', text: JSON.stringify({ error: `Unknown tool: ${name}` }) }],
      isError: true
    };
  }
  try {
    const result = await handler(args || {});
    return { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] };
  } catch (err) {
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(
            { error: err.message, stack: err.stack, tool: name },
            null,
            2
          )
        }
      ],
      isError: true
    };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  // stderr is safe for logging (stdout is reserved for MCP protocol).
  console.error('SAP Leader MCP Server running on stdio.');
}

main().catch((err) => {
  console.error('Fatal error starting SAP Leader MCP Server:', err);
  process.exit(1);
});
