//require("dotenv").config();

const path = require("path");

require("dotenv").config({
  path: path.resolve(__dirname, "../../.env"),
});

const env = {
  port: Number(process.env.PORT || 5001),
  apiNsx: process.env.API_NSX || "",
  apiKeys: process.env.API_KEYS ? process.env.API_KEYS.split(",").map((key) => key.trim()).filter(Boolean) : [],
  ioApiKey: process.env.IO_API_KEY || "",
  jwtSecret: process.env.JWT_SECRET || "",
  db: {
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 5432),
    database: process.env.DB_NAME,
    ssl: process.env.DB_SSL === "true" ? { rejectUnauthorized: false } : false,
    max: Number(process.env.DB_POOL_MAX || 10),
    idleTimeoutMillis: Number(process.env.DB_IDLE_TIMEOUT_MS || 30000),
    connectionTimeoutMillis: Number(process.env.DB_CONNECTION_TIMEOUT_MS || 10000),
    query_timeout: Number(process.env.DB_QUERY_TIMEOUT_MS || 20000),
    keepAlive: true,
  },
  httpTimeoutMs: Number(process.env.HTTP_TIMEOUT_MS || 20000),
  pgListenerRetryMs: Number(process.env.PG_LISTENER_RETRY_MS || 5000),
};

module.exports = env;

