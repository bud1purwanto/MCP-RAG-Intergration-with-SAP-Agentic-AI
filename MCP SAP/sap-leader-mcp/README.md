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
$env:SAP_USER="TRSTDEV"
$env:SAP_PASSWORD="ronin03"
$env:SAP_LANGUAGE="EN"
```
> Credentials in env override the per-server defaults in `config/sap-servers.json`.
> Note QA (TRQ) uses password `mysapku`; all others use `ronin03`.

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
