// const { client } = require("../database/dbpostgres");
const pool = require("../database/dbpostgres");

exports.getTransactionRecordByStatus = async (status) => {
  let query = `SELECT 
                    tp.id as idtransaccionpago,
                    p.id as idprogramacion,
                    p.valor_programado as totalmonto,
                    tp.valor as monto,
                    p.posicion_id as idposicion,
                    tp.id_estado_transaccion as idestado,
                    tp.respuesta_pago as message
                    FROM  public.transaccion_pago as tp
                    INNER JOIN public.programacion as p
                    ON tp.id_programacion = p.id 
                WHERE id_forma_pago = $1 AND id_estado_transaccion = $2 LIMIT 1`;

  const res0 = await pool.query(query, [2, status]);

  return res0.rows[0] || null;
};

exports.updateStatusTransactionPayment = async (record, msg, status) => {
    let query = `UPDATE public.transaccion_pago 
      SET id_estado_transaccion = $1, respuesta_pago =$2 WHERE id = $3 RETURNING *;`;

    const result = await pool.query(query, [status,msg,record.idtransaccionpago]);
    return result.rows[0] || null;
};

exports.recordTelemetryNequi = async (record, rawJson, message) => {
  const query = `INSERT INTO public.telemetria_nequi 
            (transaction_payment_id,raw_json,description)
            VALUES ($1,$2,$3) RETURNING *`;
  const result = await pool.query(query, [
    record.idtransaccionpago,
    JSON.stringify(rawJson),
    message,
  ]);

  return result.rows[0] || null;
};



exports.getRecordReturnBalance = async (status) =>{
  const query = `SELECT * FROM public.devolucion_saldo 
  WHERE enviado = false AND estado = $1  LIMIT 1;`;
  const result = await pool.query(query, [status]);
  return result.rows[0] || null;
}

exports.updateStatusReturnBalance = async (status,msg,id) =>{
  const query = `UPDATE public.devolucion_saldo SET enviado = true,estado=$1,respuesta=$2 
  WHERE id = $3 RETURNING *;`;
  const result = await pool.query(query, [status,msg,id]);
  return result.rows[0] || null;

}


async function findTelemetryNequiByTransactionPaymentId(id) {
  const query = `SELECT * FROM public.telemetria_nequi WHERE transaction_payment_id = $1 LIMIT 1;`;
  const telemetry = await pool.query(query, [id]);
  return telemetry.rows[0] || null;
}
