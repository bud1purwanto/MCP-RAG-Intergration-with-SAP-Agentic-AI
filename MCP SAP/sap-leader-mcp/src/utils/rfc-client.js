// rfc-client.js
// Wrapper around node-rfc with graceful fallback to SIMULATION MODE
// when the native node-rfc binding is not installed/available.

let rfcModule = null;
let rfcLoadError = null;

try {
  // node-rfc is an optional dependency. If the native binary or the SAP NW RFC
  // SDK is not installed, this import will throw and we fall back to simulation.
  rfcModule = await import('node-rfc');
} catch (err) {
  rfcLoadError = err;
}

export function isRfcAvailable() {
  return rfcModule !== null;
}

export function getRfcLoadError() {
  return rfcLoadError ? (rfcLoadError.message || String(rfcLoadError)) : null;
}

/**
 * RfcClient wraps a single live connection to one SAP server.
 * If node-rfc is unavailable, every call returns a simulation marker so callers
 * can produce an informative SIMULATION response.
 */
export class RfcClient {
  constructor(server, credentials) {
    this.server = server;
    this.credentials = credentials;
    this.client = null;
    this.connected = false;
    // Antrian serialisasi: satu koneksi node-rfc TIDAK aman untuk panggilan
    // bersamaan. Tanpa ini, dua RFC call yang tumpang-tindih bisa saling
    // menukar respons (mis. satu request menerima error milik request lain).
    this._queue = Promise.resolve();
  }

  get simulation() {
    return !isRfcAvailable();
  }

  async connect() {
    if (this.simulation) {
      this.connected = false;
      return { connected: false, simulation: true, reason: getRfcLoadError() };
    }

    const { Client } = rfcModule;

    const connParams = {
      user: this.credentials.user,
      passwd: this.credentials.password,
      ashost: this.server.host,
      sysnr: this.server.instance,
      client: this.server.client || this.credentials.client || '100',
      lang: this.credentials.language || 'EN'
    };

    this.client = new Client(connParams);
    await this.client.open();
    this.connected = true;
    return { connected: true, simulation: false };
  }

  async close() {
    if (this.client && this.connected) {
      try {
        await this.client.close();
      } catch (_) {
        /* ignore close errors */
      }
    }
    this.client = null;
    this.connected = false;
  }

  /**
   * Invoke an RFC-enabled function module.
   * Returns { simulation: true } when no live binding is available.
   */
  async invoke(functionName, params = {}) {
    if (this.simulation || !this.connected) {
      return { simulation: true, function: functionName, parameters: params };
    }
    // Serialkan setiap panggilan pada koneksi tunggal ini. Panggilan berikutnya
    // baru jalan setelah yang sebelumnya selesai, sukses maupun gagal, sehingga
    // respons tidak pernah tertukar antar-request.
    const run = this._queue.then(async () => {
      const result = await this.client.call(functionName, params);
      return { simulation: false, result };
    });
    // Rantai antrian tidak boleh putus karena satu panggilan gagal.
    this._queue = run.then(
      () => undefined,
      () => undefined
    );
    return run;
  }
}
