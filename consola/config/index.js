const dotenv = require("dotenv");

dotenv.config();

function toInt(value, fallback) {
  const parsed = parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

module.exports = {
  apiNsx: process.env.API_NSX || "",
  identifier: process.env.IDENTIFIER || "",
  mac: process.env.MAC || "",
  positionShift: 1,
  db: {
    user: process.env.DB_USER || "postgres",
    password: process.env.DB_PASSWORD || "admin",
    host: process.env.DB_HOST || "100.103.140.20",
    port: toInt(process.env.DB_PORT, 5432),
    database: process.env.DB_NAME || "Autoservicio_nsx2",
    max: toInt(process.env.DB_POOL_MAX, 20),
    min: toInt(process.env.DB_POOL_MIN, 2),
    idleTimeoutMillis: toInt(process.env.DB_IDLE_TIMEOUT, 30000),
    connectionTimeoutMillis: toInt(process.env.DB_CONNECTION_TIMEOUT, 2000),
    allowExitOnIdle: true,
  },
  workers: {
    getPendingAuthIntervalMs: toInt(process.env.GET_PENDING_AUTH_INTERVAL_MS, 4000),
    syncModuleIntervalMs: toInt(process.env.SYNC_MODULE_INTERVAL_MS, 5000),
    shiftIntervalMs: toInt(process.env.SHIFT_INTERVAL_MS, 10000),
    salePendingIntervalMs: toInt(process.env.SALE_PENDING_INTERVAL_MS, 200),
    saleSyncRetryDelayMs: toInt(process.env.SALE_SYNC_RETRY_DELAY_MS, 5000),
    saleSyncLoopIntervalMs: toInt(process.env.SALE_SYNC_LOOP_INTERVAL_MS, 10000),
    saleSyncLimitCounter: toInt(process.env.SALE_SYNC_LIMIT_COUNTER, 40),
    returnBalanceIntervalMs: toInt(process.env.RETURN_BALANCE_INTERVAL_MS, 10000),
    transactionPaymentIntervalMs: toInt(
      process.env.TRANSACTION_PAYMENT_INTERVAL_MS,
      5000,
    ),
  },
};
