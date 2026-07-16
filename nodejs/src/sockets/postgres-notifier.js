const { Client } = require("pg");
const { stringConnection } = require("../database/dbpostgres");
const env = require("../config/env");
const logger = require("../config/logger");

const POSTGRES_CHANNELS = [
  "notify_event_transaction_payment",
  "notify_event_authorization",
  "event_sale",
];

const DEFAULT_RETRY_MS = env.pgListenerRetryMs;

const parsePayload = (payload) => {
  if (!payload) {
    return null;
  }

  try {
    return JSON.parse(payload);
  } catch (error) {
    return payload;
  }
};

exports.POSTGRES_CHANNELS = POSTGRES_CHANNELS;

exports.createPostgresNotifier = (io) => {
  let listenerClient = null;
  let reconnectTimer = null;
  let isStopping = false;

  const scheduleReconnect = () => {
    if (isStopping || reconnectTimer) {
      return;
    }

    reconnectTimer = setTimeout(async () => {
      reconnectTimer = null;

      try {
        await connect();
      } catch (error) {
        logger.error("Error reconectando listener de PostgreSQL", error.message);
        scheduleReconnect();
      }
    }, DEFAULT_RETRY_MS);
  };

  const cleanupClient = async () => {
    if (!listenerClient) {
      return;
    }

    const currentClient = listenerClient;
    listenerClient = null;
    currentClient.removeAllListeners();

    try {
      await currentClient.end();
    } catch (error) {
      logger.error("Error cerrando listener de PostgreSQL", error.message);
    }
  };

  const connect = async () => {
    await cleanupClient();

    const pgClient = new Client(stringConnection);

    pgClient.on("notification", (message) => {
      if (!POSTGRES_CHANNELS.includes(message.channel)) {
        return;
      }

      const event = {
        channel: message.channel,
        payload: parsePayload(message.payload),
        receivedAt: new Date().toISOString(),
      };

      io.emit("postgres_event", event);
      io.emit(message.channel, event);
    });

    pgClient.on("error", (error) => {
      logger.error("Listener PostgreSQL con error", error.message);
      scheduleReconnect();
    });

    pgClient.on("end", () => {
      if (!isStopping) {
        logger.warn("Listener PostgreSQL finalizado. Reintentando conexion");
        scheduleReconnect();
      }
    });

    await pgClient.connect();

    for (const channel of POSTGRES_CHANNELS) {
      await pgClient.query(`LISTEN ${channel}`);
    }

    listenerClient = pgClient;
  };

  return {
    start: async () => {
      isStopping = false;
      await connect();
    },
    stop: async () => {
      isStopping = true;

      if (reconnectTimer) {
        clearTimeout(reconnectTimer);
        reconnectTimer = null;
      }

      await cleanupClient();
    },
  };
};
