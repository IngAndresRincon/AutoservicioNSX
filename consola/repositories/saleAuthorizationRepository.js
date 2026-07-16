const { client } = require("../database/dbpostgres");
const logger = require("../utils/logger");

exports.getPendingSaleAuthorization = async () => {
  let list = [];
  try {
    let query = `SELECT id,id_programacion,id_presetnsx,id_venta
    FROM public.autorizacion WHERE sincronizado = 2 AND id_venta IS NULL`;
    const res0 = await client.query(query);
    if (res0.rowCount > 0) {
      list = res0.rows;
    }
  } catch (e) {
    logger.error(e);
  }
  return list;
};

exports.reportStatusWhileSupplying = async (id) => {
  try {
    const query = `UPDATE public.autorizacion 
                    SET sincronizado = 8
                    WHERE id = ${id} AND sincronizado != 8;`;
    await client.query(query);
    logger.info(`Autorización de venta ${id} marcada como surtiendo en la base de datos`);
  } catch (e) {
    logger.error(e);
    throw new Error("Error:" + e.message);
  }
};

exports.markSaleAuthorizationAsFailed = async (id) => {
  let sync = false;
  try {
    const query = `UPDATE public.autorizacion 
                    SET sincronizado = 3
                    WHERE id = ${id};`;
    const response = await client.query(query);
    if (response.rowCount > 0) {
      sync = true;
    }
    logger.info(`AutorizaciÃ³n de venta ${id} marcada como fallida en la base de datos`);
  } catch (e) {
    logger.error(e);
    throw new Error("Error:" + e.message);
  }

  return sync;
};

exports.markSaleAuthorizationAsVentaZero = async (id) => {
  let sync = false;
  try {
    const query = `UPDATE public.autorizacion 
                    SET sincronizado = 6
                    WHERE id = ${id};`;
    const response = await client.query(query);
    if (response.rowCount > 0) {
      sync = true;
    }
    logger.info(`AutorizaciÃ³n de venta ${id} marcada como venta cero en la base de datos`);
  } catch (e) {
    logger.error(e);
    throw new Error("Error:" + e.message);
  }

  return sync;
};

exports.registerSaleAuthorization = async (auth, sale) => {
  let sync = false;
  try {
    const saleResult = await saveRecordSale(sale);

    if (!saleResult) {
      throw new Error(
        `No se logró almacenar los datos de la venta: ${JSON.stringify(sale)}`,
      );
    }

    const query = `UPDATE public.autorizacion 
                    SET id_venta = $1, sincronizado  = 4
                    WHERE id = $2 AND sincronizado IN (8,2);`;
    const response = await client.query(query, [sale.idVenta, auth.id]);
    if (response.rowCount > 0) {
      sync = true;
    }
  } catch (e) {
    logger.error(e);
    throw new Error("Error:" + e.message);
  }

  return sync;
};

const saveRecordSale = async (sale) => {
  const queryText = `INSERT INTO public.venta (
                        id_venta_nsx,
                        id_preset_nsx,
                        id_posicion,
                        id_manguera,
                        dinero,
                        volumen,
                        precio,
                        saldo,
                        id_turno
                      )
                      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, (SELECT MAX(id) FROM public.historico_turno WHERE activo = true LIMIT 1))
                      RETURNING *;`;

  const result = await client.query(queryText, [
    sale.idVenta,
    sale.idProgramacion,
    sale.idPosicion,
    sale.numeroManguera,
    sale.dinero,
    sale.volumen,
    sale.precioVenta,
    sale.vuelto,
  ]);

  return result.rows[0] || null;
};
