const pool = require("../database/dbpostgres");

exports.findAvailableTerminalList = async ()=>{
    const query = `SELECT 
                    t.id,
                    t.serial,
                    t.ip,
                    t.num_terminal,
                    t.breb,
                    t.aprobacion as approval,
                    tp.id_posicion as positionId
                FROM  public.terminal as t
                INNER JOIN public.terminal_posicion as tp
                ON tp.id_terminal = t.id
                WHERE t.activo = $1  AND  tp.activo = $1;`;
    const result = await pool.query(query,[true]);
    return result.rowCount>0? result.rows : [];
}



exports.findTransactionPayment = async  ({statusId,terminal})=>{

    const methodPaymentId = 1; //Para pagos con datáfono

    const query = `
                SELECT 
                    tp.id,
                    p.id as programmingId,
                    p.valor_programado as totalAmount,
                    tp.valor as amount,
                    p.posicion_id as positionId,
                    tp.id_estado_transaccion as statusId
                FROM  public.transaccion_pago as tp
                INNER JOIN public.programacion as p
                ON tp.id_programacion = p.id 
                WHERE id_forma_pago = $1 
                AND id_estado_transaccion = $2
                AND p.posicion_id = $3 LIMIT 1`;
    const result = await pool.query(query,[methodPaymentId,statusId,terminal.positionid ]);
    return result.rowCount>0? result.rows[0] : null;

}



exports.updateTransactionStatus = async (id,statusId, response) =>{

    let query = null;

    if(statusId ===2){
        query = `UPDATE public.transaccion_pago SET 
                    respuesta_pago  =$1,
                    id_estado_transaccion = $2,
                    fecha_transaccion = now(),
                    recibo = $3,
                    franquicia = $4,
                    tarjeta = $5
                WHERE id = $3 RETURNING *;`;
        const result = await pool.query(query,[
            JSON.stringify(response),
            statusId,
            response.receiptId ?? 0,
            response.franchise ?? "",
            response.cardNumber ?? "",
            id
        ]);
        return result.rowCount>0? result.rows[0] : null;
    }
    
    query = `UPDATE public.transaccion_pago SET 
            respuesta_pago  =$1,
            id_estado_transaccion = $2,
            fecha_transaccion = now()
        WHERE id = $3 RETURNING *;`;
    const result = await pool.query(query,[JSON.stringify(response), statusId,id]);
    return result.rowCount>0? result.rows[0] : null;
}



exports.findOverduePayment = async ()=>{

    const methodPaymentId = [3,6];

    const query = `SELECT * FROM public.transaccionpago 
                    WHERE fkidestadotransaccion NOT IN(2,3,5)
                    AND fkidformapago = ANY($1::integer[])
                    AND fecharegistro < NOW() - INTERVAL '5 minutes';`;
    const result = await pool.query(query,[methodPaymentId]);
    return result.rowCount>0? result.rows : [];
}


exports.releasePaymentById = async (id) =>{
    const query = `UPDATE public.transaccionpago SET 
                    fkidestadotransaccion = $1,
                    fechatransaccion = now(),
                    respuestapago = $2
                WHERE id = $3 RETURNING *;`;
    
    const result = await pool.query(query,[5,'Transacción anulada por timeout de respuesta',id]);

    return result.rowCount>0? result.rows[0] : null;
}