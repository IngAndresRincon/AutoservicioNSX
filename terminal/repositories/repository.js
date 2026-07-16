const { client } = require("../database/dbpostgres");
require("dotenv").config();



exports.getTerminalList = async () => {
  let list = [];
  try {
    let query = `SELECT tp.id as idterminalposicion, id_terminal, id_posicion,
                        t.id as idterminal,
                        t.serial, t.ip,
                        p.id as idposicion,
                        p.id_nsx_posicion as nsxidposicion
                        FROM  public.terminal_posicion  as tp
                        INNER JOIN public.terminal as t
                        ON t.id = tp.id_terminal
                        INNER JOIN public.posicion as p
                        ON p.id = tp.id_posicion
                WHERE tp.activo = true AND p.activo = true AND t.activo = true`;
    const res0 = await client.query(query);
    if (res0.rowCount > 0) {
      list = res0.rows;
    }
  } catch (e) {
    console.error(e.message);
    throw new Error("Error:" + e.message);
  }

  return list;
};



exports.getPendingPayment = async (params,statusid) => {
  let itemPayment = null;
  try {
    let query = `SELECT 
                    tp.id as idtransaccionpago,
                    p.id as idprogramacion,
                    p.valor_programado as totalmonto,
                    tp.valor as monto,
                    p.posicion_id as idposicion,
                    tp.id_estado_transaccion as idestado
                    FROM  public.transaccion_pago as tp
                    INNER JOIN public.programacion as p
                    ON tp.id_programacion = p.id 
                WHERE id_forma_pago = 1 AND id_estado_transaccion = ${statusid} AND p.posicion_id = ${params.id_posicion} LIMIT 1`;
    const res0 = await client.query(query);
    if (res0.rowCount > 0) {
      itemPayment = res0.rows[0];
    }
  } catch (e) {
    console.error(e.message);
    throw new Error("Error:" + e.message);
  }

  return itemPayment;
};

exports.changeStatusPayment = async (id,status,response ) => {
  let isUpdate = false;
  try {
        let query = `UPDATE public.transaccion_pago SET id_estado_transaccion = ${status}, respuesta_pago = '${response}' WHERE id = ${id};`;
        const res0 = await client.query(query);
        if (res0.rowCount > 0) {
            isUpdate = true;
        }
  } catch (e) {
    console.error(e.message);
    throw new Error("Error:" + e.message);
  }

  return isUpdate;
};
