const { client } = require("../database/dbpostgres");
const logger = require("../utils/logger");

exports.getPendingReturnBalance = async () => {
  const query = `SELECT ds.id,
                        a.id as idautorizacion, 
                        a.id_presetnsx,
                        ds.id_forma_pago,
                        ds.monto,
                        ds.contacto,
                        ds.enviado,
                        ds.estado,
                        ds.respuesta,
                        ds.fecharegistro
    FROM public.devolucion_saldo as ds
    INNER JOIN public.autorizacion as a
    ON a.id = ds.id_autorizacion 
    WHERE ds.estado = $1 AND id_forma_pago = $2 AND enviado = $3;`;
    const result = await client.query(query,[0,3,false]);
    return result.rowCount > 0 ? result.rows : [];
};

exports.updateReturnBalanceState = async (id, estado,message) => {

  const query = `UPDATE public.devolucion_saldo
                    SET estado = $1, respuesta = $2
                    WHERE id = $3 RETURNING *;`;
  const result = await client.query(query, [estado, message??'',id]);
  return result.rowCount > 0 ? true : false;
};
