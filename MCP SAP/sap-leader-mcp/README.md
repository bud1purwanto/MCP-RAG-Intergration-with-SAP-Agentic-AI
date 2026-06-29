# SAP Leader MCP Server

MCP server (stdio) that gives **Claude Code** live access to multiple SAP **ECC 6.0 EHP6 / NetWeaver 7.31** systems via RFC, with a graceful **SIMULATION MODE** fallback when `node-rfc` is not installed.

It exposes **12 tools** (server management, general query, ABAP technical) and ships a **CLAUDE.md** that defines 9 SAP sub-agent roles (Leader orchestrator + FI/CO/MM/SD/PP/PM/WM/ABAP).

---

## Features

- **Multi-server** config (`config/sap-servers.json`) — edit freely, no code changes.
- **Smart server resolution** — by name, number, alias (`dev`/`prod`/`qa`/`sandbox`), SID, or IP.
- **Production guardrails** — production servers raise ⚠️ and require explicit confirmation.
- **Simulation fallback** — informative mock responses (which RFC, which params, install hint) when `node-rfc` is missing, so the server is usable immediately.

## Tools

| Category | Tool | Equivalent |
|---|---|---|
| Server | `list_servers`, `set_active_server`, `get_system_info` | RFC_SYSTEM_INFO |
| Query | `read_table`, `call_function`, `get_sap_document` | RFC_READ_TABLE / BAPIs |
| ABAP | `read_program` | SE38 |
| ABAP | `read_table_structure` | SE11 |
| ABAP | `search_programs` | SE80 |
| ABAP | `read_function_module` | SE37 |
| ABAP | `read_class` | SE24 |
| ABAP | `get_where_used` | Where-Used |

---

## Setup

### 1. Install base dependencies
```bash
npm install
```

### 2. (Optional) Enable LIVE RFC connections
Live connectivity needs the **SAP NW RFC SDK** plus the `node-rfc` binding:
```bash
# 1. Download "SAP NW RFC SDK 7.50" from SAP Software Center (S-user required)
#    and extract it, then set SAPNWRFC_HOME to that folder.
# 2. Then:
npm install node-rfc
```
If `node-rfc` is absent or fails to load, the server keeps running in **SIMULATION MODE**.

### 3. Set environment variables
```bash
# Windows PowerShell
$env:SAP_USER="<your-sap-user>"
$env:SAP_PASSWORD="<your-sap-password>"
$env:SAP_LANGUAGE="EN"
```
> Credentials in env override the per-server defaults in `config/sap-servers.json`.
> Different servers may use different passwords — check with your SAP Basis team.

### 4. Register with Claude Code
Add to `~/.claude/mcp.json` (or copy from `.claude/mcp.json`), pointing `cwd` at this folder:
```json
{
  "mcpServers": {
    "sap-leader": {
      "type": "stdio",
      "command": "node",
      "args": ["index.js"],
      "cwd": "C:/Users/Lenovo/Documents/Claude/MCP SAP/sap-leader-mcp",
      "env": {
        "SAP_USER": "TRSTDEV",
        "SAP_PASSWORD": "your_password",
        "SAP_LANGUAGE": "EN"
      }
    }
  }
}
```
Restart Claude Code so it picks up the server.

### 5. Edit the server list
Just edit **`config/sap-servers.json`** — add/remove servers, change hosts, aliases, or passwords. No restart of anything but the MCP server is needed.

---

## Akses via URL (HTTP MCP)

Selain stdio (untuk Claude Code/Cowork lokal), server ini juga bisa diakses lewat **HTTP** dalam jaringan lokal/VPN — berguna untuk remote connector atau klien lain di jaringan yang sama.

### Menjalankan
```bash
cd sap-leader-mcp
MCP_HTTP_TOKEN="<token-rahasia>" MCP_HTTP_PORT=8091 npm run start:http
```
Atau di PowerShell:
```powershell
$env:MCP_HTTP_TOKEN="<token-rahasia>"; $env:MCP_HTTP_PORT=8091; npm run start:http
```

### Endpoint
- `GET  /health` — cek server hidup (tanpa auth, tidak membocorkan data SAP)
- `POST /mcp` — endpoint MCP JSON-RPC (wajib `Authorization: Bearer <token>`)

### Karakteristik
- **Stateless** — setiap request membuat instance server+transport baru, tidak perlu handshake `initialize` lebih dulu. Aman untuk multi-client tanpa session affinity.
- **Bind ke `0.0.0.0`** by default → bisa diakses dari mesin lain di jaringan lokal/VPN yang sama via `http://<IP-LAN-mesin-ini>:8091/mcp`.
- **Wajib Bearer token** — request tanpa/token salah ditolak `401`.
- ⚠️ **Jangan expose ke internet publik** tanpa reverse proxy HTTPS + auth tambahan, karena server ini punya akses RFC ke SAP Production.

### Contoh test manual
```bash
curl -X POST http://<IP>:8091/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Authorization: Bearer <token-rahasia>" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"list_servers","arguments":{}}}'
```

### Mendaftarkan sebagai remote MCP connector
Jika klien (Claude Desktop/Cowork lain) mendukung tipe `http`:
```json
{
  "mcpServers": {
    "sap-leader-remote": {
      "type": "http",
      "url": "http://<IP-LAN-mesin-ini>:8091/mcp",
      "headers": { "Authorization": "Bearer <token-rahasia>" }
    }
  }
}
```

---

## Usage examples (in Claude Code)

- `list_servers` → see all systems and which is active.
- `set_active_server` with `dev` → switch to Development AIX.
- `set_active_server` with `prod` + `confirm_production: true` → switch to Production (after confirmation).
- `get_system_info` → RFC_SYSTEM_INFO on the active server.
- `read_table` table `MARA`, fields `["MATNR","MTART"]`, where `["MTART = 'FERT'"]`, rowcount `10`.
- `read_program` program `RM07DOCS` → display source (SE38).
- `get_where_used` object `BKPF` → cross-references.

---

## Project structure
```
sap-leader-mcp/
├── index.js                 # MCP stdio server + tool registration
├── package.json
├── config/
│   └── sap-servers.json     # dynamic server list (editable)
├── src/
│   ├── server-manager.js    # config load, active-server state, RFC lifecycle
│   ├── tools/
│   │   ├── server-tools.js  # list_servers, set_active_server, get_system_info
│   │   ├── query-tools.js   # read_table, call_function, get_sap_document
│   │   └── abap-tools.js    # 6 ABAP technical tools
│   └── utils/
│       └── rfc-client.js    # node-rfc wrapper + simulation fallback
├── CLAUDE.md                # sub-agent system prompt (9 roles)
└── .claude/
    └── mcp.json             # Claude Code registration template
```

## Response format
Every tool returns JSON including:
```json
{ "mode": "LIVE | SIMULATION", "active_server": "...", "sid": "...", "...": "data" }
```
Production responses additionally carry a `production_warning`. Simulation responses include the target RFC, the received parameters, and a node-rfc install hint.

## Security notes
- Default credentials live in `config/sap-servers.json` for convenience; prefer overriding via `SAP_USER`/`SAP_PASSWORD` env vars and removing plaintext passwords in shared environments.
- Production servers are gated behind explicit confirmation by design — keep that flow.
