const crypto = require("crypto");
const logger = require("../../config/logger");
const AppError = require("../../errors/AppError");
const { client } = require("../../database/dbpostgres");

const generateNumericCode = () => String(crypto.randomInt(0, 100000)).padStart(5, "0");

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

const fail = (message, error) => {
  logger.error(message, error);
  return new AppError(message, 502, { details: error.message });
};

exports.findPosition = async (positionId) => {
  try {
    const result = await client.query("SELECT id, id_nsx_posicion FROM public.posicion WHERE id = $1;", [positionId]);
    return result.rows[0] || null;
  } catch (error) {
    throw fail("Error consultando la posicion", error);
  }
};

exports.isIdentifierTypeEnabled = async (typeId) => {
  try {
    const result = await client.query(
      "SELECT 1 FROM public.identificador_cliente WHERE id_nsx_identificador = $1;",
      [typeId],
    );
    return result.rowCount > 0;
  } catch (error) {
    throw fail("Error consultando los identificadores", error);
  }
};

// Reserva la posicion bajo un candado: no puede haber autoservicio, vendedor ni otro cliente identificado activos
exports.reservePreset = async (params) => {
  const db = await client.connect();
  try {
    await db.query("BEGIN");
    await db.query("SELECT pg_advisory_xact_lock($1);", [params.positionId]);

    const busy = await db.query(
      `SELECT 'autoservicio' as origen FROM public.autorizacion
         WHERE id_posicion = $1 AND sincronizado IN (0, 2, 8) AND id_venta IS NULL
           AND fecha_registro > NOW() - INTERVAL '30 minutes'
       UNION ALL
       SELECT 'vendedor' FROM public.preset_vendedor
         WHERE id_posicion = $1 AND sincronizado IN (0, 2, 8) AND id_venta IS NULL
       UNION ALL
       SELECT 'cliente' FROM public.preset_cliente
         WHERE id_posicion = $1 AND sincronizado IN (0, 2, 8) AND id_venta IS NULL
       LIMIT 1;`,
      [params.positionId],
    );
    if (busy.rowCount > 0) {
      throw new AppError(`La posicion esta ocupada (${busy.rows[0].origen})`, 409);
    }

    const result = await db.query(
      `INSERT INTO public.preset_cliente
         (id_posicion, numero_manguera, tipo_programacion, valor, km, tipo_identificador, serial, documento, id_turno_vendedor)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8::varchar,
               (SELECT id FROM public.turno_vendedor WHERE documento = $8::varchar AND activo = true ORDER BY id DESC LIMIT 1))
       RETURNING *;`,
      [
        params.positionId,
        params.hoseNumber,
        params.programmingType,
        params.value,
        params.km,
        params.identifierType,
        params.serial,
        params.document,
      ],
    );

    await db.query("COMMIT");
    return result.rows[0];
  } catch (error) {
    await db.query("ROLLBACK");
    if (error instanceof AppError) {
      throw error;
    }
    throw fail("Error registrando el preset del cliente", error);
  } finally {
    db.release();
  }
};

exports.updatePreset = async (id, { state, nsxPresetId = null, message = null }) => {
  try {
    const result = await client.query(
      `UPDATE public.preset_cliente
       SET sincronizado = $2, id_presetnsx = COALESCE($3, id_presetnsx), mensaje = $4, fecha_actualizacion = CURRENT_TIMESTAMP
       WHERE id = $1
       RETURNING *;`,
      [id, state, nsxPresetId, message],
    );
    return result.rows[0] || null;
  } catch (error) {
    throw fail("Error actualizando el preset del cliente", error);
  }
};

exports.getPreset = async (id) => {
  try {
    const result = await client.query("SELECT * FROM public.preset_cliente WHERE id = $1;", [id]);
    return result.rows[0] || null;
  } catch (error) {
    throw fail("Error consultando el preset del cliente", error);
  }
};
