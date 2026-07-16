const { client } = require("../database/dbpostgres");
const logger = require("../utils/logger");

exports.getPendingReturnBalance = async () => {
  let list = [];
  try {
    const query = `SELECT ds.id,a.id as idautorizacion, a.id_presetnsx,
    ds.id_forma_pago,ds.monto,ds.contacto,ds.enviado,ds.estado,ds.respuesta, ds.fecharegistro
    FROM public.devolucion_saldo as ds
    INNER JOIN public.autorizacion as a
    ON a.id = ds.id_autorizacion 
    WHERE ds.estado = 0 AND id_forma_pago = 3 AND enviado = false;`;
    const res0 = await client.query(query);
    if (res0.rowCount > 0) {
      list = res0.rows;
    }
  } catch (e) {
    logger.error(e);
  }
  return list;
};

exports.updateReturnBalanceState = async (id, estado,message) => {
  let sync = false;
  try {
    const query = `UPDATE public.devolucion_saldo
                    SET estado = $1, respuestas = $2
                    WHERE id = $3;`;
    const response = await client.query(query, [estado, message??'',id]);
    if (response.rowCount > 0) {
      sync = true;
    }
  } catch (e) {
    logger.error(e);
    throw new Error("Error:" + e.message);
  }

  return sync;
};
