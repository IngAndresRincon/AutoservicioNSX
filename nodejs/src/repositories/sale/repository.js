const logger = require("../../config/logger");
const AppError = require("../../errors/AppError");
const { client } = require("../../database/dbpostgres");

exports.getrefpresetid = async (params) => {
  try {
    const query = `SELECT id_presetnsx FROM public.autorizacion
      WHERE id_programacion = $1 OR id = $2
      LIMIT 1;`;
    const res0 = await client.query(query, [params.programmingId, params.authorizationId]);

    if (res0.rowCount === 0) {
      throw new AppError("No se encuentra programacion o autorizacion asociada a la venta", 404);
    }

    return { id: res0.rows[0].id_presetnsx };
  } catch (error) {
    if (error instanceof AppError) {
      throw error;
    }
    logger.error("Error obteniendo preset NSX", error);
    throw new AppError(`Error consultando preset: ${error.message}`, 502);
  }
};

exports.createBill = async (params) => {
  try {
    const queryAuthorization = `SELECT id FROM public.autorizacion 
    WHERE id_venta = $1 LIMIT 1;`;
    const res0 = await client.query(queryAuthorization, [params.saleId]);

    if (res0.rowCount === 0) {
      throw new AppError("No se encuentra informacion de la venta", 404);
    }

    let query = `SELECT id, venta_id, documento, tipo_documento, razon_social, correo
      FROM public.factura WHERE venta_id = $1 LIMIT 1;`;
    const res1 = await client.query(query, [params.saleId]);
    if (res1.rowCount > 0) {
      return { bill: res1.rows[0] };
    }

    query = `INSERT INTO public.factura (venta_id, documento, tipo_documento, razon_social, correo)
      VALUES ($1, $2, $3, $4, $5) RETURNING id;`;
    const res2 = await client.query(query, [
      params.saleId,
      params.documentNumber,
      params.documentType,
      params.companyName,
      params.email,
    ]);

    if (res2.rowCount === 0) {
      throw new AppError("Error insertando factura", 502);
    }

    return { bill: res2.rows[0] };
  } catch (error) {
    if (error instanceof AppError) {
      throw error;
    }
    logger.error("Error creando factura", error);
    throw new AppError(`Error creando registro de factura: ${error.message}`, 502);
  }
};
