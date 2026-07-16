const logger = require("../../config/logger");
const AppError = require("../../errors/AppError");
const { client } = require("../../database/dbpostgres");

exports.synchronizeTerminal = async (params) => {
  try {
    const selectQuery = "SELECT id FROM public.terminal WHERE TRIM(serial) = TRIM($1);";
    const res0 = await client.query(selectQuery, [params.serial]);

    if (res0.rowCount === 0) {
      const insertQuery = "INSERT INTO public.terminal (serial, ip) VALUES($1, $2) RETURNING *;";
      const res1 = await client.query(insertQuery, [params.serial, `${params.ip}:8080`]);
      return res1.rowCount > 0 ? res1.rows : null;
    }

    const updateQuery = "UPDATE public.terminal SET ip = $1 WHERE id = $2 RETURNING *;";
    const res1 = await client.query(updateQuery, [`${params.ip}:8080`, res0.rows[0].id]);
    return res1.rowCount > 0 ? res1.rows : null;
  } catch (error) {
    logger.error("Error sincronizando terminal", error);
    throw new AppError("Error sincronizando terminal", 502, { details: error.message });
  }
};
