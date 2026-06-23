// query-tools.js
// read_table, call_function, get_sap_document

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
    out.production_warning = '⚠️ Response dari PRODUCTION server. Pastikan sudah ada konfirmasi user.';
  }
  return out;
}

function simResponse(tool, rfc_function, parameters, extra = {}) {
  return productionFlag({
    ...base(),
    mode: 'SIMULATION',
    tool,
    rfc_function,
    parameters,
    note: `${INSTALL_HINT} ${getRfcLoadError() || ''}`.trim(),
    ...extra
  });
}

export async function read_table({ table, fields = [], where = [], rowcount = 100 }) {
  const gate = serverManager.requireActive();
  if (!gate.ok) return { mode: 'SIMULATION', error: gate.error };
  if (!table) return { ...base(), error: 'Parameter "table" wajib diisi.' };

  const options = (Array.isArray(where) ? where : [where])
    .filter(Boolean)
    .map((w) => ({ TEXT: w }));
  const fieldsParam = (fields || []).map((f) => ({ FIELDNAME: f }));

  const client = serverManager.getClient();
  const res = await client.invoke('RFC_READ_TABLE', {
    QUERY_TABLE: table,
    DELIMITER: '|',
    ROWCOUNT: rowcount,
    OPTIONS: options,
    FIELDS: fieldsParam
  });

  if (res.simulation) {
    return simResponse('read_table', 'RFC_READ_TABLE', { table, fields, where, rowcount }, {
      explanation: `Akan membaca tabel ${table} dengan ${fieldsParam.length || 'semua'} field, filter: ${
        options.map((o) => o.TEXT).join(' ') || '(tanpa filter)'
      }, max ${rowcount} baris.`
    });
  }

  // Parse RFC_READ_TABLE output (DATA split by DELIMITER, FIELDS metadata).
  const meta = res.result.FIELDS || [];
  const rows = (res.result.DATA || []).map((r) => {
    const parts = r.WA.split('|');
    const obj = {};
    meta.forEach((m, i) => {
      obj[m.FIELDNAME] = (parts[i] || '').trim();
    });
    return obj;
  });

  return productionFlag({
    ...base(),
    tool: 'read_table',
    table,
    row_count: rows.length,
    fields: meta.map((m) => m.FIELDNAME),
    rows
  });
}

export async function call_function({ function_name, parameters = {} }) {
  const gate = serverManager.requireActive();
  if (!gate.ok) return { mode: 'SIMULATION', error: gate.error };
  if (!function_name) return { ...base(), error: 'Parameter "function_name" wajib diisi.' };

  const client = serverManager.getClient();
  const res = await client.invoke(function_name, parameters);

  if (res.simulation) {
    return simResponse('call_function', function_name, parameters, {
      explanation: `Akan memanggil RFC/BAPI ${function_name} dengan parameter di atas.`
    });
  }

  return productionFlag({
    ...base(),
    tool: 'call_function',
    function_name,
    result: res.result
  });
}

// Document type → RFC/BAPI mapping for header + items.
const DOC_HANDLERS = {
  FI: { fn: 'BAPI_ACC_DOCUMENT_REV', desc: 'FI accounting document (BKPF/BSEG)' },
  SD_ORDER: { fn: 'BAPI_SALESORDER_GETDETAILBOS', desc: 'SD sales order (VBAK/VBAP)' },
  MM_PO: { fn: 'BAPI_PO_GETDETAIL', desc: 'MM purchase order (EKKO/EKPO)' },
  PP_ORDER: { fn: 'BAPI_PRODORD_GET_DETAIL', desc: 'PP production order (AUFK/AFKO/AFPO)' },
  PM_ORDER: { fn: 'BAPI_ALM_ORDER_GET_DETAIL', desc: 'PM maintenance order (AUFK/AFIH)' }
};

export async function get_sap_document({ doc_type, doc_number, company_code }) {
  const gate = serverManager.requireActive();
  if (!gate.ok) return { mode: 'SIMULATION', error: gate.error };

  const handler = DOC_HANDLERS[doc_type];
  if (!handler) {
    return {
      ...base(),
      error: `doc_type tidak dikenal: ${doc_type}. Pilihan: ${Object.keys(DOC_HANDLERS).join(', ')}.`
    };
  }
  if (!doc_number) return { ...base(), error: 'Parameter "doc_number" wajib diisi.' };

  const client = serverManager.getClient();

  // Build parameters per document type.
  let params = {};
  switch (doc_type) {
    case 'FI':
      params = { OBJ_TYPE: 'BKPFF', OBJ_KEY: doc_number, COMPANYCODE: company_code };
      break;
    case 'SD_ORDER':
      params = { SALESDOCUMENT: doc_number };
      break;
    case 'MM_PO':
      params = { PURCHASEORDER: doc_number, ITEMS: 'X', HEADER_TEXTS: 'X' };
      break;
    case 'PP_ORDER':
      params = { NUMBER: doc_number };
      break;
    case 'PM_ORDER':
      params = { NUMBER: doc_number };
      break;
  }

  const res = await client.invoke(handler.fn, params);

  if (res.simulation) {
    return simResponse('get_sap_document', handler.fn, { doc_type, doc_number, company_code }, {
      explanation: `Akan membaca ${handler.desc} no ${doc_number}${
        company_code ? ` (company code ${company_code})` : ''
      }.`,
      simulated_result: {
        header: { document: doc_number, type: doc_type, company_code: company_code || null },
        items: []
      }
    });
  }

  return productionFlag({
    ...base(),
    tool: 'get_sap_document',
    doc_type,
    doc_number,
    company_code: company_code || null,
    bapi: handler.fn,
    result: res.result
  });
}
