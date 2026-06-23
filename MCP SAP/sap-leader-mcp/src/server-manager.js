// server-manager.js
// Loads sap-servers.json, manages active server state, and owns the live RFC client.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { RfcClient, isRfcAvailable, getRfcLoadError } from './utils/rfc-client.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const CONFIG_PATH = join(__dirname, '..', 'config', 'sap-servers.json');

class ServerManager {
  constructor() {
    this.config = null;
    this.activeServer = null;
    this.client = null;
    this.loadConfig();
  }

  loadConfig() {
    const raw = readFileSync(CONFIG_PATH, 'utf-8');
    this.config = JSON.parse(raw);
    return this.config;
  }

  getServers() {
    if (!this.config) this.loadConfig();
    return this.config.servers;
  }

  /**
   * Resolve a server reference: name, list number (1-based), alias, SID, or host/IP.
   * Returns the matched server object or null.
   */
  resolveServer(ref) {
    if (ref === undefined || ref === null) return null;
    const servers = this.getServers();
    const needle = String(ref).trim().toLowerCase();

    // 1-based index number
    if (/^\d+$/.test(needle)) {
      const idx = parseInt(needle, 10) - 1;
      if (idx >= 0 && idx < servers.length) return servers[idx];
    }

    for (const s of servers) {
      if (s.name.toLowerCase() === needle) return s;
      if (s.host.toLowerCase() === needle) return s;
      if ((s.aliases || []).some((a) => a.toLowerCase() === needle)) return s;
    }

    // SID can match multiple servers (e.g. TRD). Return first exact SID match
    // only if there is exactly one, otherwise null so caller can disambiguate.
    const sidMatches = servers.filter((s) => s.sid.toLowerCase() === needle);
    if (sidMatches.length === 1) return sidMatches[0];

    // Partial name match as last resort
    const partial = servers.filter((s) => s.name.toLowerCase().includes(needle));
    if (partial.length === 1) return partial[0];

    return null;
  }

  /** Return all servers that ambiguously match a reference (e.g. shared SID). */
  resolveCandidates(ref) {
    const servers = this.getServers();
    const needle = String(ref).trim().toLowerCase();
    return servers.filter(
      (s) =>
        s.sid.toLowerCase() === needle ||
        s.name.toLowerCase().includes(needle) ||
        (s.aliases || []).some((a) => a.toLowerCase().includes(needle))
    );
  }

  getActiveServer() {
    return this.activeServer;
  }

  isProduction() {
    return this.activeServer && this.activeServer.environment === 'production';
  }

  async setActiveServer(ref) {
    const server = this.resolveServer(ref);
    if (!server) {
      const candidates = this.resolveCandidates(ref);
      return {
        success: false,
        ambiguous: candidates.length > 1,
        candidates: candidates.map((c) => c.name),
        error:
          candidates.length > 1
            ? `Ambiguous server reference "${ref}". Candidates: ${candidates
                .map((c) => c.name)
                .join(', ')}. Please specify the exact name.`
            : `Server "${ref}" not found. Use list_servers to see available servers.`
      };
    }

    // Close previous connection, open a fresh one to the selected server.
    if (this.client) {
      await this.client.close();
      this.client = null;
    }

    this.activeServer = server;

    const credentials = {
      user: process.env.SAP_USER || server.user,
      password: process.env.SAP_PASSWORD || server.password,
      language: process.env.SAP_LANGUAGE || this.config.default_language || 'EN',
      client: server.client || this.config.default_client || '100'
    };

    this.client = new RfcClient(server, credentials);

    let connectResult;
    try {
      connectResult = await this.client.connect();
    } catch (err) {
      connectResult = { connected: false, simulation: false, error: err.message };
    }

    return {
      success: true,
      server,
      mode: connectResult.connected ? 'LIVE' : 'SIMULATION',
      connected: !!connectResult.connected,
      production: server.environment === 'production',
      rfc_available: isRfcAvailable(),
      rfc_load_error: getRfcLoadError(),
      connect_error: connectResult.error || null
    };
  }

  getClient() {
    return this.client;
  }

  /** Common gate used by all live-SAP tools. */
  requireActive() {
    if (!this.activeServer) {
      return {
        ok: false,
        error:
          'No active server. Gunakan set_active_server dulu untuk memilih server SAP (mis. set_active_server("dev")).'
      };
    }
    return { ok: true };
  }
}

// Single shared instance for the whole MCP process.
export const serverManager = new ServerManager();
export default serverManager;
