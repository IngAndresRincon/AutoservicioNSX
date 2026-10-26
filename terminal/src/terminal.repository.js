const pool = require("../database/connection");

exports.findAvailableTerminalList = async ()=>{
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
                WHERE tp.activo = true AND p.activo = true AND t.activo = true;`;
    const result = await pool.query(query,[true]);
    return result.rowCount>0? result.rows : [];

}



exports.findTransactionPayment = async  ({statusId,terminal})=>{

    const query = `
                SELECT 
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
    const result = await pool.query(query,[statusId,[3,6],terminal.serial]);
    return result.rowCount>0? result.rows[0] : null;

}



exports.updateTransactionStatus = async (id,statusId, message) =>{

    const query = `UPDATE public.transaccionpago SET 
                    fkidestadotransaccion = $1,
                    respuestapago = $2,
                    fechatransaccion = now()
                WHERE id = $3 RETURNING *;`;
   
    const result = await pool.query(query,[statusId,message,id]);
    return result.rowCount>0 ? result.rows[0] : null;
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