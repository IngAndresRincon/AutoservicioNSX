const pool = require("../database/dbpostgres");
require("dotenv").config();
const validTransactionStatusId = [2, 4];

exports.getTerminalList = async () => {
  const query = `SELECT tp.id as idterminalposicion, id_terminal, id_posicion,
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
  const result = await pool.query(query);
  return result.rowCount > 0 ? result.rows : [];
};

exports.getPendingPayment = async (params, statusid) => {
  const query = `SELECT 
                    tp.id as idtransaccionpago,
                    p.id as idprogramacion,
                    p.valor_programado as totalmonto,
                    tp.valor as monto,
                    p.posicion_id as idposicion,
                    tp.id_estado_transaccion as idestado
                    FROM  public.transaccion_pago as tp
                    INNER JOIN public.programacion as p
                    ON tp.id_programacion = p.id 
                WHERE id_forma_pago = 1 
                AND id_estado_transaccion = $1
                AND p.posicion_id = $2 LIMIT 1`;
  const result = await pool.query(query, [statusid, params.id_posicion]);
  return result.rowCount > 0 ? result.rows[0] : null;
};

exports.changeStatusPayment = async (id, status, response) => {

  const query = `UPDATE public.transaccion_pago SET 
                  id_estado_transaccion = $1,
                  respuesta_pago = $2
                WHERE id = $3 RETURNING *;`;
  const result = await pool.query(query,[status,response,id]);
  return result.rowCount>0? result.rows[0] : null;

};

exports.authorizePayment = async (payment, statusId) => {
  console.log("Authorize payment:", payment);
  const query = `UPDATE public.transaccion_pago SET 
                  id_estado_transaccion = $1 
                WHERE id = $2;`;
  const result = await pool.query(query, [statusId, payment.idtransaccionpago]);
  console.log("Authorize payment result:", result);
  return result.rowCount > 0 ? result.rows[0] : null;
};
