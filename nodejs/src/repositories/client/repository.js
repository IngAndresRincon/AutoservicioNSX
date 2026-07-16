const crypto = require("crypto");
const logger = require("../../config/logger");
const AppError = require("../../errors/AppError");
const { client } = require("../../database/dbpostgres");

const generateNumericCode = () => String(crypto.randomInt(0, 100000000)).padStart(6, "0");

exports.clientValidation = async (params) => {
  try {
    let identifier = params.identifier;
    if (params.cf_client) {
      identifier = generateNumericCode();
    }

    const selectQuery = "SELECT * FROM public.cliente WHERE identificador = $1 AND activo = true;";
    const res0 = await client.query(selectQuery, [identifier]);
    if (res0.rowCount > 0) {
      return res0.rows[0];
    }

    const insertQuery = "INSERT INTO public.cliente (identificador) VALUES ($1) RETURNING *;";
    const res1 = await client.query(insertQuery, [identifier]);
    return res1.rowCount > 0 ? res1.rows[0] : null;
  } catch (error) {
    logger.error("Error validando cliente", error);
    throw new AppError("Error validando cliente", 502, { details: error.message });
  }
};

exports.clientValidationDian = async (params) => {
  try {
    const query = `UPDATE public.cliente SET
      nombre = $1,
      tipo_documento = $2,
      correo = $3
      WHERE TRIM(identificador) = TRIM($4)
      RETURNING *;`;

    const res0 = await client.query(query, [
      params.razonSocial,
      params.tipoDocumento,
      params.email,
      params.documento,
    ]);

    return res0.rowCount > 0 ? res0.rows[0] : null;
  } catch (error) {
    logger.error("Error validando cliente DIAN", error);
    throw new AppError("Error validando cliente", 502, { details: error.message });
  }
};

exports.additionalInformation = async (params) => {
  try {
    const query = "UPDATE public.cliente SET placa = $1, km = $2 WHERE id = $3 RETURNING *;";
    const res0 = await client.query(query, [params.licensePlate, params.km, params.clientId]);
    return res0.rowCount > 0 ? res0.rows[0] : null;
  } catch (error) {
    logger.error("Error actualizando informacion adicional del cliente", error);
    throw new AppError("Error validando cliente", 502, { details: error.message });
  }
};
