const logger = require("../../config/logger");
const AppError = require("../../errors/AppError");
const { client } = require("../../database/dbpostgres");

exports.synchronizeModule = async () => {
  try {
    const query = "UPDATE public.modulo SET sincronizar = true WHERE sincronizar = false;";
    const res0 = await client.query(query);
    return res0.rowCount > 0;
  } catch (error) {
    logger.error("Error sincronizando modulo", error);
    throw new AppError(`Error sincronizando modulo: ${error.message}`, 502);
  }
};

exports.synchronizeScreen = async (params) => {
  try {
    const selectQuery = "SELECT id FROM public.pantalla WHERE TRIM(serial) = TRIM($1);";
    const res0 = await client.query(selectQuery, [params.serial]);
    if (res0.rowCount === 0) {
      throw new AppError("No se encuentra pantalla asociada al sistema", 404);
    }

    const updateQuery = "UPDATE public.pantalla SET ip = $1 WHERE id = $2;";
    const res1 = await client.query(updateQuery, [params.ip, res0.rows[0].id]);
    return res1.rowCount > 0 ? res0.rows[0].id : 0;
  } catch (error) {
    if (error instanceof AppError) {
      throw error;
    }
    logger.error("Error sincronizando pantalla", error);
    throw new AppError(`Error sincronizando pantalla: ${error.message}`, 502);
  }
};

exports.getScreenList = async () => {
  try {
    const query = "SELECT id, serial, ip FROM public.pantalla WHERE activo = true;";
    const res0 = await client.query(query);
    return res0.rowCount > 0 ? res0.rows : [];
  } catch (error) {
    logger.error("Error obteniendo lista de pantallas", error);
    throw new AppError(`Error obteniendo lista de pantallas: ${error.message}`, 502);   
  }
};