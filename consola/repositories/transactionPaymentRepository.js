const { client } = require("../database/dbpostgres");
const logger = require("../utils/logger");

exports.getPendingTransactionPayments = async () => {
  let list = [];
  try {
    const query = `
      SELECT id, id_forma_pago, id_estado_transaccion, fecha_transaccion
      FROM public.transaccion_pago
      WHERE id_forma_pago = 3
        AND id_estado_transaccion = 4;
    `;
    const response = await client.query(query);
    if (response.rowCount > 0) {
      list = response.rows;
    }
  } catch (error) {
    logger.error(error);
    throw new Error("Error:" + error.message);
  }

  return list;
};

exports.markTransactionPaymentsAsProcessed = async (ids) => {
  let sync = false;
  try {
    if (!ids || ids.length === 0) {
      return false;
    }

    const query = `
      UPDATE public.transaccion_pago
      SET id_estado_transaccion = 2,
          fecha_transaccion = NOW()
      WHERE id = ANY($1::int[])
        AND id_forma_pago = 3
        AND id_estado_transaccion = 4
      RETURNING id;
    `;
    const response = await client.query(query, [ids]);
    if (response.rowCount > 0) {
      sync = true;
    }
  } catch (error) {
    logger.error(error);
    throw new Error("Error:" + error.message);
  }

  return sync;
};
