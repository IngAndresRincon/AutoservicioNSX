const { Pool } = require("pg");
const env = require("./env");
const logger = require("./logger");
const AppError = require("../errors/AppError");

const requiredEnvVars = ["DB_USER", "DB_PASSWORD", "DB_HOST", "DB_PORT", "DB_NAME"];
const missingEnvVars = requiredEnvVars.filter((envVar) => !process.env[envVar]);

if (missingEnvVars.length > 0) {
  throw new AppError(`Faltan variables de entorno para PostgreSQL: ${missingEnvVars.join(", ")}`, 500);
}

const stringConnection = env.db;
const client = new Pool(stringConnection);

client.on("error", (error) => {
  logger.error("Error inesperado en el pool de PostgreSQL", error);
});

module.exports = { client, stringConnection };

