const assert = require("node:assert/strict");
const axios = require("axios");
const crypto = require("crypto");
const fsPromises = require("fs/promises");
const path = require("path");

const nsxService = require("../src/services/nsx/services");
const saleService = require("../src/services/sale/service");
const clientService = require("../src/services/client/service");
const clientController = require("../src/controllers/client/controller");
const systemService = require("../src/services/system/services");
const controllerNsx = require("../src/controllers/nsx/controller");
const systemController = require("../src/controllers/system/controller");
const db = require("../src/database/dbpostgres");
const clientRepository = require("../src/repositories/client/repository");
const saleRepository = require("../src/repositories/sale/repository");
const AppError = require("../src/errors/AppError");
const logger = require("../src/config/logger");
const pg = require("pg");

const tests = [];

const test = (name, fn) => {
  tests.push({ name, fn });
};

const createRes = () => {
  const state = {
    statusCode: null,
    payload: null,
  };

  return {
    status(code) {
      state.statusCode = code;
      return this;
    },
    json(payload) {
      state.payload = payload;
      return payload;
    },
    get state() {
      return state;
    },
  };
};

test("controller: nsx last sale success", async () => {
  const original = nsxService.getLastSale;
  nsxService.getLastSale = async () => ({ saleId: 10, total: 1250 });

  try {
    const req = { params: { dispenserId: "1", sideId: "2" } };
    const res = createRes();
    let nextCalled = false;

    await controllerNsx.getLastSale(req, res, () => {
      nextCalled = true;
    });

    assert.equal(nextCalled, false);
    assert.equal(res.state.statusCode, 200);
    assert.equal(res.state.payload.isError, false);
    assert.equal(res.state.payload.content.saleId, 10);
  } finally {
    nsxService.getLastSale = original;
  }
});

test("controller: nsx last sale validates params", async () => {
  const req = { params: { dispenserId: "x", sideId: "2" } };
  const res = createRes();

  let capturedError = null;
  await controllerNsx.getLastSale(req, res, (error) => {
    capturedError = error;
  });

  assert.ok(capturedError);
  assert.equal(capturedError.statusCode, 400);
  assert.equal(capturedError.message, "dispenserId y sideId deben ser numericos");
});

test("repository: clientValidation returns existing id", async () => {
  const originalQuery = db.client.query;

  db.client.query = async (sql) => {
    if (sql.includes("SELECT id FROM public.cliente")) {
      return { rowCount: 1, rows: [{ id: 77 }] };
    }

    throw new Error(`Unexpected query: ${sql}`);
  };

  try {
    const clientId = await clientRepository.clientValidation({ identifier: "ABC123" });
    assert.equal(clientId, 77);
  } finally {
    db.client.query = originalQuery;
  }
});

test("repository: clientValidation generates 8-digit identifier for cf_client", async () => {
  const originalQuery = db.client.query;
  const originalRandomInt = crypto.randomInt;
  const capturedParams = [];

  crypto.randomInt = () => 1234;
  db.client.query = async (sql, params) => {
    capturedParams.push(params);

    if (sql.includes("SELECT id FROM public.cliente")) {
      return { rowCount: 0, rows: [] };
    }

    if (sql.includes("INSERT INTO public.cliente")) {
      return { rowCount: 1, rows: [{ id: 88 }] };
    }

    throw new Error(`Unexpected query: ${sql}`);
  };

  try {
    const clientId = await clientRepository.clientValidation({ identifier: "ABC123", cf_client: true });
    assert.equal(clientId, 88);
    assert.equal(capturedParams[0][0], "00001234");
    assert.equal(capturedParams[1][0], "00001234");
  } finally {
    db.client.query = originalQuery;
    crypto.randomInt = originalRandomInt;
  }
});

test("repository: clientValidation wraps database failures", async () => {
  const originalQuery = db.client.query;
  const originalLoggerError = logger.error;
  db.client.query = async () => {
    throw new Error("db down");
  };
  logger.error = () => {};

  try {
    await assert.rejects(
      clientRepository.clientValidation({ identifier: "ABC123" }),
      (error) => error instanceof AppError && error.statusCode === 502
    );
  } finally {
    db.client.query = originalQuery;
    logger.error = originalLoggerError;
  }
});

test("controller: clientValidation allows cf_client without identifier", async () => {
  const originalClientValidation = clientService.clientValidation;
  clientService.clientValidation = async () => 91;

  try {
    const req = { body: { cf_client: true } };
    const res = createRes();

    await clientController.clientValidation(req, res, () => {});

    assert.equal(res.state.statusCode, 200);
    assert.equal(res.state.payload.content.clientId, 91);
  } finally {
    clientService.clientValidation = originalClientValidation;
  }
});

test("repository: sale getrefpresetid returns 404 when missing", async () => {
  const originalQuery = db.client.query;
  db.client.query = async () => ({ rowCount: 0, rows: [] });

  try {
    await assert.rejects(
      saleRepository.getrefpresetid({ programmingId: 1, authorizationId: 2 }),
      (error) => error instanceof AppError && error.statusCode === 404
    );
  } finally {
    db.client.query = originalQuery;
  }
});

test("service: sale uses GET request for sale lookup", async () => {
  const originalGetrefpresetid = saleRepository.getrefpresetid;
  const originalAxiosRequest = axios.request;

  axios.request = async (config) => ({ status: 200, data: { endpoint: config.url, method: config.method } });
  saleRepository.getrefpresetid = async () => ({ id: 123 });

  try {
    const response = await saleService.sale({ authorizationId: 10 });
    assert.equal(response.status, 200);
    assert.ok(response.data.endpoint.includes("EstadoPreset?idPreset=123"));
    assert.equal(response.data.method, "get");
  } finally {
    axios.request = originalAxiosRequest;
    saleRepository.getrefpresetid = originalGetrefpresetid;
  }
});

test("service: sale uses POST request for billing", async () => {
  const originalCreateBill = saleRepository.createBill;
  const originalAxiosRequest = axios.request;

  axios.request = async (config) => ({ status: 200, data: { endpoint: config.url, body: config.data, method: config.method } });
  saleRepository.createBill = async () => ({ bill: { id: 1 } });

  try {
    const response = await saleService.bill({
      saleId: 55,
      documentNumber: "123",
      documentType: "CC",
      companyName: "ACME",
      email: "test@example.com",
    });

    assert.equal(response.status, 200);
    assert.ok(response.data.endpoint.includes("Facturacion/FacturarVenta"));
    assert.equal(response.data.body.idVenta, 55);
    assert.equal(response.data.method, "post");
  } finally {
    axios.request = originalAxiosRequest;
    saleRepository.createBill = originalCreateBill;
  }
});

test("controller: system uploadVideo stores multipart video files in public/video", async () => {
  const originalMkdir = fsPromises.mkdir;
  const originalWriteFile = fsPromises.writeFile;
  const originalRename = fsPromises.rename;
  const originalStat = fsPromises.stat;
  const writes = [];
  const renames = [];

  fsPromises.mkdir = async () => {};
  fsPromises.writeFile = async (filePath, buffer) => {
    writes.push({ filePath, buffer });
  };
  fsPromises.rename = async (from, to) => {
    renames.push({ from, to });
  };
  fsPromises.stat = async () => ({ size: Buffer.byteLength("VIDEO_BYTES") });

  try {
    const req = {
      body: { videoName: "clip.mp4" },
      file: {
        fieldname: "video",
        originalname: "original.mp4",
        mimetype: "video/mp4",
        path: path.join("tmp", "upload-1.mp4"),
      },
      headers: {},
      query: {},
    };

    const res = createRes();

    await systemController.uploadVideo(req, res, () => {});

    assert.equal(res.state.statusCode, 201);
    assert.equal(res.state.payload.isError, false);
    assert.equal(res.state.payload.content.filename, "clip.mp4");
    assert.equal(
      res.state.payload.content.filePath,
      path.join(process.cwd(), "public", "video", "clip.mp4")
    );
    assert.equal(res.state.payload.content.publicUrl, "/mediav/clip.mp4");
    assert.equal(res.state.payload.content.size, "VIDEO_BYTES".length);
    assert.equal(renames.length, 1);
    assert.equal(renames[0].from, path.join("tmp", "upload-1.mp4"));
    assert.equal(
      renames[0].to,
      path.join(process.cwd(), "public", "video", "clip.mp4")
    );
  } finally {
    fsPromises.mkdir = originalMkdir;
    fsPromises.writeFile = originalWriteFile;
    fsPromises.rename = originalRename;
    fsPromises.stat = originalStat;
  }
});

test("controller: system uploadVideo uses the provided x-video-name when present", async () => {
  const originalMkdir = fsPromises.mkdir;
  const originalWriteFile = fsPromises.writeFile;
  const originalRename = fsPromises.rename;
  const originalStat = fsPromises.stat;
  const writes = [];
  const renames = [];

  fsPromises.mkdir = async () => {};
  fsPromises.writeFile = async (filePath, buffer) => {
    writes.push({ filePath, buffer });
  };
  fsPromises.rename = async (from, to) => {
    renames.push({ from, to });
  };
  fsPromises.stat = async () => ({ size: Buffer.byteLength("VIDEO_BYTES") });

  try {
    const req = {
      body: {},
      file: {
        fieldname: "video",
        originalname: "original.mp4",
        mimetype: "video/mp4",
        path: path.join("tmp", "upload-2.mp4"),
      },
      headers: {
        "x-video-name": "MiVideoFinal.mp4",
      },
      query: {},
    };

    const res = createRes();

    await systemController.uploadVideo(req, res, () => {});

    assert.equal(res.state.statusCode, 201);
    assert.equal(res.state.payload.content.filename, "MiVideoFinal.mp4");
    assert.equal(
      res.state.payload.content.filePath,
      path.join(process.cwd(), "public", "video", "MiVideoFinal.mp4")
    );
    assert.equal(res.state.payload.content.requestedName, "MiVideoFinal.mp4");
    assert.equal(renames.length, 1);
    assert.equal(
      renames[0].to,
      path.join(process.cwd(), "public", "video", "MiVideoFinal.mp4")
    );
  } finally {
    fsPromises.mkdir = originalMkdir;
    fsPromises.writeFile = originalWriteFile;
    fsPromises.rename = originalRename;
    fsPromises.stat = originalStat;
  }
});

test("socket: postgres notifier emits subscribed events", async () => {
  const originalPgClient = pg.Client;
  const originalStringConnection = db.stringConnection;

  class FakeClient {
    constructor(connectionString) {
      this.connectionString = connectionString;
      this.handlers = {};
      this.listenQueries = [];
      this.endCalled = false;
      FakeClient.instances.push(this);
    }

    on(event, handler) {
      this.handlers[event] = handler;
    }

    async connect() {
      this.connected = true;
    }

    async query(sql) {
      this.listenQueries.push(sql);
      return { rowCount: 1, rows: [] };
    }

    removeAllListeners() {
      this.handlers = {};
    }

    async end() {
      this.endCalled = true;
    }
  }

  FakeClient.instances = [];
  pg.Client = FakeClient;
  db.stringConnection = "postgres://unit-test";

  delete require.cache[require.resolve("../src/sockets/postgres-notifier")];
  const { createPostgresNotifier, POSTGRES_CHANNELS } = require("../src/sockets/postgres-notifier");

  try {
    const emitted = [];
    const io = {
      emit(event, payload) {
        emitted.push({ event, payload });
      },
    };

    const notifier = createPostgresNotifier(io);
    await notifier.start();

    const instance = FakeClient.instances[0];
    assert.ok(instance.connected);
    assert.equal(instance.connectionString, "postgres://unit-test");
    assert.equal(instance.listenQueries.length, POSTGRES_CHANNELS.length);

    instance.handlers.notification({
      channel: "event_sale",
      payload: JSON.stringify({ saleId: 99 }),
    });

    assert.equal(emitted[0].event, "postgres_event");
    assert.equal(emitted[1].event, "event_sale");
    assert.equal(emitted[1].payload.payload.saleId, 99);

    await notifier.stop();
    assert.equal(instance.endCalled, true);
  } finally {
    pg.Client = originalPgClient;
    db.stringConnection = originalStringConnection;
  }
});

const main = async () => {
  let failed = 0;

  for (const entry of tests) {
    try {
      await entry.fn();
      console.log(`ok - ${entry.name}`);
    } catch (error) {
      failed += 1;
      console.error(`fail - ${entry.name}`);
      console.error(error);
    }
  }

  console.log(`tests: ${tests.length}, failed: ${failed}`);

  if (failed > 0) {
    process.exitCode = 1;
  }
};

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
