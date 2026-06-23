// abap-tools.js
// 6 ABAP technical tools that read directly from the SAP repository:
// read_program, read_table_structure, search_programs,
// read_function_module, read_class, get_where_used

import { serverManager } from '../server-manager.js';
import { isRfcAvailable, getRfcLoadError } from '../utils/rfc-client.js';

const INSTALL_HINT =
  'node-rfc tidak terpasang. Untuk koneksi LIVE: install SAP NW RFC SDK lalu `npm install node-rfc`.';

function liveMode() {
  return isRfcAvailable() && serverManager.getClient()?.connected;
}

function base() {
  const s = serverManager.getActiveServer();
  return {
    mode: liveMode() ? 'LIVE' : 'SIMULATION',
    active_server: s ? s.name : null,
    sid: s ? s.sid : null
  };
}

function productionFlag(out) {
  if (serverManager.isProduction()) {
    out.production_warning = '⚠️ Membaca repository dari PRODUCTION server.';
  }
  return out;
}

function sim(tool, rfc, params, extra = {}) {
  return productionFlag({
    ...base(),
    mode: 'SIMULATION',
    tool,
    rfc_function: rfc,
    parameters: params,
    note: `${INSTALL_HINT} ${getRfcLoadError() || ''}`.trim(),
    ...extra
  });
}

async function gate() {
  return serverManager.requireActive();
}

// ── read_program (SE38) ────────────────────────────────────────────────
export async function read_program({ program_name, include_name }) {
  const g = await gate();
  if (!g.ok) return { mode: 'SIMULATION', error: g.error };
  if (!program_name) return { ...base(), error: 'Parameter "program_name" wajib diisi.' };

  const target = include_name || program_name;
  const client = serverManager.getClient();
  const res = await client.invoke('RPY_PROGRAM_READ', { PROGRAM_NAME: target, WITH_INCLUDELIST: 'X' });

  if (res.simulation) {
    // Try alternate READ_REPORT semantics in explanation.
    return sim('read_program', 'RPY_PROGRAM_READ / READ_REPORT', { program_name, include_name }, {
      tcode_equivalent: 'SE38',
      explanation: `Akan membaca source code program/include ${target} (setara SE38 Display Source).`,
      simulated_result: { program: target, source_lines: [] }
    });
  }

  const lines = (res.result.SOURCE_EXTENDED || res.result.SOURCE || []).map((l) =>
    typeof l === 'string' ? l : l.LINE
  );
  return productionFlag({
    ...base(),
    tool: 'read_program',
    program_name: target,
    line_count: lines.length,
    source: lines.join('\n')
  });
}

// ── read_table_structure (SE11) ────────────────────────────────────────
export async function read_table_structure({ object_name, object_type = 'TABLE' }) {
  const g = await gate();
  if (!g.ok) return { mode: 'SIMULATION', error: g.error };
  if (!object_name) return { ...base(), error: 'Parameter "object_name" wajib diisi.' };

  const client = serverManager.getClient();
  // Header from DD02L, fields from DD03L via RFC_READ_TABLE.
  const fieldsRes = await client.invoke('RFC_READ_TABLE', {
    QUERY_TABLE: 'DD03L',
    DELIMITER: '|',
    FIELDS: [
      { FIELDNAME: 'FIELDNAME' },
      { FIELDNAME: 'POSITION' },
      { FIELDNAME: 'KEYFLAG' },
      { FIELDNAME: 'ROLLNAME' },
      { FIELDNAME: 'DATATYPE' },
      { FIELDNAME: 'LENG' }
    ],
    OPTIONS: [{ TEXT: `TABNAME = '${object_name.toUpperCase()}'` }],
    ROWCOUNT: 0
  });

  if (fieldsRes.simulation) {
    return sim('read_table_structure', 'RFC_READ_TABLE (DD03L + DD02L)', { object_name, object_type }, {
      tcode_equivalent: 'SE11',
      explanation: `Akan membaca struktur ${object_name} dari DD03L (fields) + DD02L (header).`,
      simulated_result: { table: object_name, fields: [] }
    });
  }

  const meta = fieldsRes.result.FIELDS || [];
  const fields = (fieldsRes.result.DATA || []).map((r) => {
    const p = r.WA.split('|');
    const o = {};
    meta.forEach((m, i) => (o[m.FIELDNAME] = (p[i] || '').trim()));
    return {
      field: o.FIELDNAME,
      position: o.POSITION,
      key: o.KEYFLAG === 'X',
      data_element: o.ROLLNAME,
      type: o.DATATYPE,
      length: o.LENG
    };
  });

  return productionFlag({
    ...base(),
    tool: 'read_table_structure',
    object_name,
    object_type,
    field_count: fields.length,
    fields
  });
}

// ── search_programs (SE80) ─────────────────────────────────────────────
export async function search_programs({ pattern, object_type, max_results = 50 }) {
  const g = await gate();
  if (!g.ok) return { mode: 'SIMULATION', error: g.error };
  if (!pattern) return { ...base(), error: 'Parameter "pattern" wajib diisi.' };

  const client = serverManager.getClient();
  const options = [{ TEXT: `NAME LIKE '${pattern.toUpperCase()}'` }];
  if (object_type) options.push({ TEXT: `AND SUBC = '${object_type}'` });

  const res = await client.invoke('RFC_READ_TABLE', {
    QUERY_TABLE: 'TRDIR',
    DELIMITER: '|',
    FIELDS: [{ FIELDNAME: 'NAME' }, { FIELDNAME: 'SUBC' }, { FIELDNAME: 'CNAM' }, { FIELDNAME: 'RLOAD' }],
    OPTIONS: options,
    ROWCOUNT: max_results
  });

  if (res.simulation) {
    return sim('search_programs', 'RFC_READ_TABLE (TRDIR)', { pattern, object_type, max_results }, {
      tcode_equivalent: 'SE80',
      explanation: `Akan mencari program di TRDIR dengan NAME LIKE '${pattern.toUpperCase()}'${
        object_type ? ` dan tipe ${object_type}` : ''
      }, max ${max_results}.`,
      simulated_result: { programs: [] }
    });
  }

  const meta = res.result.FIELDS || [];
  const programs = (res.result.DATA || []).map((r) => {
    const p = r.WA.split('|');
    const o = {};
    meta.forEach((m, i) => (o[m.FIELDNAME] = (p[i] || '').trim()));
    return { name: o.NAME, subc: o.SUBC, author: o.CNAM };
  });

  return productionFlag({
    ...base(),
    tool: 'search_programs',
    pattern,
    result_count: programs.length,
    programs
  });
}

// ── read_function_module (SE37) ────────────────────────────────────────
export async function read_function_module({ function_name }) {
  const g = await gate();
  if (!g.ok) return { mode: 'SIMULATION', error: g.error };
  if (!function_name) return { ...base(), error: 'Parameter "function_name" wajib diisi.' };

  const client = serverManager.getClient();
  const ifaceRes = await client.invoke('FUNCTION_IMPORT_INTERFACE', {
    FUNCNAME: function_name.toUpperCase()
  });

  if (ifaceRes.simulation) {
    return sim('read_function_module', 'FUNCTION_IMPORT_INTERFACE + READ_REPORT', { function_name }, {
      tcode_equivalent: 'SE37',
      explanation: `Akan membaca interface (IMPORT/EXPORT/CHANGING/TABLES) + source FM ${function_name}.`,
      simulated_result: { function: function_name, interface: {}, source: [] }
    });
  }

  return productionFlag({
    ...base(),
    tool: 'read_function_module',
    function_name,
    interface: ifaceRes.result
  });
}

// ── read_class (SE24) ──────────────────────────────────────────────────
export async function read_class({ class_name, method_name }) {
  const g = await gate();
  if (!g.ok) return { mode: 'SIMULATION', error: g.error };
  if (!class_name) return { ...base(), error: 'Parameter "class_name" wajib diisi.' };

  const client = serverManager.getClient();
  // Class header from SEOCLASS, components/methods from SEOCPDKEY.
  const methodsRes = await client.invoke('RFC_READ_TABLE', {
    QUERY_TABLE: 'SEOCPDKEY',
    DELIMITER: '|',
    FIELDS: [{ FIELDNAME: 'CLSNAME' }, { FIELDNAME: 'CPDNAME' }],
    OPTIONS: [{ TEXT: `CLSNAME = '${class_name.toUpperCase()}'` }],
    ROWCOUNT: 200
  });

  if (methodsRes.simulation) {
    return sim('read_class', 'RFC_READ_TABLE (SEOCLASS + SEOCPDKEY)', { class_name, method_name }, {
      tcode_equivalent: 'SE24',
      explanation: `Akan membaca definisi class ${class_name}${
        method_name ? ` method ${method_name}` : ''
      } dari SEOCLASS + SEOCPDKEY.`,
      simulated_result: { class: class_name, methods: [] }
    });
  }

  const meta = methodsRes.result.FIELDS || [];
  let methods = (methodsRes.result.DATA || []).map((r) => {
    const p = r.WA.split('|');
    const o = {};
    meta.forEach((m, i) => (o[m.FIELDNAME] = (p[i] || '').trim()));
    return o.CPDNAME;
  });
  if (method_name) methods = methods.filter((m) => m === method_name.toUpperCase());

  return productionFlag({
    ...base(),
    tool: 'read_class',
    class_name,
    method_filter: method_name || null,
    method_count: methods.length,
    methods
  });
}

// ── get_where_used (cross-reference) ───────────────────────────────────
export async function get_where_used({ object_name, object_type, max_results = 100 }) {
  const g = await gate();
  if (!g.ok) return { mode: 'SIMULATION', error: g.error };
  if (!object_name) return { ...base(), error: 'Parameter "object_name" wajib diisi.' };

  const client = serverManager.getClient();
  const options = [{ TEXT: `FIELDNAME = '${object_name.toUpperCase()}'` }];
  if (object_type) options.push({ TEXT: `AND TYPE = '${object_type}'` });

  const res = await client.invoke('RFC_READ_TABLE', {
    QUERY_TABLE: 'D010TAB',
    DELIMITER: '|',
    FIELDS: [{ FIELDNAME: 'MASTER' }, { FIELDNAME: 'TABNAME' }, { FIELDNAME: 'FIELDNAME' }],
    OPTIONS: options,
    ROWCOUNT: max_results
  });

  if (res.simulation) {
    return sim('get_where_used', 'RFC_READ_TABLE (D010TAB)', { object_name, object_type, max_results }, {
      tcode_equivalent: 'Where-Used List',
      explanation: `Akan mencari penggunaan ${object_name} di D010TAB (cross-reference), max ${max_results}.`,
      simulated_result: { object: object_name, used_in: [] }
    });
  }

  const meta = res.result.FIELDS || [];
  const usedIn = (res.result.DATA || []).map((r) => {
    const p = r.WA.split('|');
    const o = {};
    meta.forEach((m, i) => (o[m.FIELDNAME] = (p[i] || '').trim()));
    return { program: o.MASTER, table: o.TABNAME };
  });

  return productionFlag({
    ...base(),
    tool: 'get_where_used',
    object_name,
    usage_count: usedIn.length,
    used_in: usedIn
  });
}
