const logger = require("../../config/logger");
const AppError = require("../../errors/AppError");
const { client } = require("../../database/dbpostgres");

exports.validateSocketSerial = async (serial) => {
  const normalizedSerial = serial ? serial.trim() : "";

  if (!normalizedSerial) {
    return false;
  }

  try {
    const query = "SELECT 1 FROM public.pantalla WHERE TRIM(serial) = TRIM($1) LIMIT 1;";
    const response = await client.query(query, [normalizedSerial]);
    return response.rowCount > 0;
  } catch (error) {
    logger.error("Error validando serial para socket", error);
    throw new AppError("Error validando serial para socket", 502, { details: error.message });
  }
};
