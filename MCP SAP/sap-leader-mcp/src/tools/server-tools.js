// server-tools.js
// list_servers, set_active_server, get_system_info

import { serverManager } from '../server-manager.js';
import { isRfcAvailable, getRfcLoadError } from '../utils/rfc-client.js';

const INSTALL_HINT =
  'node-rfc tidak terpasang. Untuk koneksi LIVE: install SAP NW RFC SDK lalu jalankan `npm install node-rfc`.';

function baseResponse() {
  const s = serverManager.getActiveServer();
  return {
    mode: isRfcAvailable() && serverManager.getClient()?.connected ? 'LIVE' : 'SIMULATION',
    active_server: s ? s.name : null,
    sid: s ? s.sid : null
  };
}

export async function list_servers() {
  const servers = serverManager.getServers();
  const active = serverManager.getActiveServer();
  return {
    mode: baseResponse().mode,
    active_server: active ? active.name : null,
    rfc_available: isRfcAvailable(),
    rfc_note: isRfcAvailable() ? 'node-rfc loaded' : INSTALL_HINT,
    count: servers.length,
    servers: servers.map((s, i) => ({
      number: i + 1,
      name: s.name,
      sid: s.sid,
      host: s.host,
      instance: s.instance,
      environment: s.environment,
      aliases: s.aliases,
      production_warning: s.environment === 'production',
      active: active && active.name === s.name
    }))
  };
}

export async function set_active_server({ server_ref, confirm_production }) {
  const result = await serverManager.setActiveServer(server_ref);

  if (!result.success) {
    return { mode: 'SIMULATION', success: false, ...result };
  }

  const response = {
    mode: result.mode,
    success: true,
    active_server: result.server.name,
    sid: result.server.sid,
    host: result.server.host,
    instance: result.server.instance,
    environment: result.server.environment,
    connected: result.connected,
    rfc_available: result.rfc_available
  };

  if (!result.rfc_available) {
    response.simulation_note = `${INSTALL_HINT} (${result.rfc_load_error || 'native binding unavailable'})`;
  } else if (result.connect_error) {
    response.connect_error = result.connect_error;
    response.simulation_note = 'Koneksi RFC gagal, berjalan dalam SIMULATION MODE.';
  }

  if (result.production) {
    response.warning =
      '⚠️ PRODUCTION SERVER aktif. Semua query terhadap server ini berisiko terhadap data live. Minta konfirmasi user sebelum menjalankan query apapun.';
    response.requires_confirmation = true;
    response.confirmed = !!confirm_production;
  }

  return response;
}

export async function get_system_info() {
  const gate = serverManager.requireActive();
  if (!gate.ok) return { mode: 'SIMULATION', error: gate.error };

  const client = serverManager.getClient();
  const base = baseResponse();

  const res = await client.invoke('RFC_SYSTEM_INFO', {});

  if (res.simulation) {
    return {
      ...base,
      mode: 'SIMULATION',
      tool: 'get_system_info',
      rfc_function: 'RFC_SYSTEM_INFO',
      note: `${INSTALL_HINT} ${getRfcLoadError() || ''}`.trim(),
      simulated_result: {
        RFCSI_EXPORT: {
          RFCHOST: serverManager.getActiveServer().host,
          RFCSYSID: serverManager.getActiveServer().sid,
          RFCDBSYS: 'ORACLE',
          RFCSAPRL: '731',
          RFCKERNRL: '721',
          RFCDAYST: ' '
        }
      }
    };
  }

  const out = { ...base, mode: 'LIVE', tool: 'get_system_info', system_info: res.result.RFCSI_EXPORT };
  if (serverManager.isProduction()) {
    out.production_warning = '⚠️ Response dari PRODUCTION server.';
  }
  return out;
}

export async function get_server_date() {
  const gate = serverManager.requireActive();
  if (!gate.ok) return { mode: 'SIMULATION', error: gate.error };

  const client = serverManager.getClient();
  const base = baseResponse();

  // Query USR02 — ambil TRDAT (last logon date) terbesar = tanggal server saat ini
  const res = await client.invoke('RFC_READ_TABLE', {
    QUERY_TABLE: 'USR02',
    DELIMITER: '|',
    ROWCOUNT: 50,
    OPTIONS: [{ TEXT: "TRDAT >= '20200101'" }],
    FIELDS: [{ FIELDNAME: 'BNAME' }, { FIELDNAME: 'TRDAT' }, { FIELDNAME: 'LTIME' }]
  });

  if (res.simulation) {
    return {
      ...base,
      mode: 'SIMULATION',
      tool: 'get_server_date',
      note: `${INSTALL_HINT} Tidak dapat cek tanggal server.`
    };
  }

  // Parse DATA rows: format "BNAME|TRDAT|LTIME"
  const rows = (res.result.DATA || []).map((r) => {
    const parts = (r.WA || '').split('|').map((s) => s.trim());
    return { BNAME: parts[0] || '', TRDAT: parts[1] || '', LTIME: parts[2] || '' };
  }).filter((r) => r.TRDAT);

  // Ambil TRDAT terbesar
  const maxRow = rows.reduce((max, r) => (!max || r.TRDAT > max.TRDAT ? r : max), null);

  const out = {
    ...base,
    mode: 'LIVE',
    tool: 'get_server_date',
    server_date: maxRow ? maxRow.TRDAT : null,
    server_date_formatted: maxRow
      ? `${maxRow.TRDAT.slice(6, 8)}.${maxRow.TRDAT.slice(4, 6)}.${maxRow.TRDAT.slice(0, 4)}`
      : null,
    last_logon_user: maxRow ? maxRow.BNAME : null,
    last_logon_time: maxRow ? maxRow.LTIME : null,
    method: 'USR02.TRDAT max — last logon date',
    sample_size: rows.length
  };

  if (serverManager.isProduction()) {
    out.production_warning = '⚠️ Response dari PRODUCTION server.';
  }
  return out;
}
