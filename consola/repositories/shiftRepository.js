const { client } = require("../database/dbpostgres");


exports.getShiftToOpen = async (time) => {

    const query = `SELECT * FROM public.turno 
    WHERE hora_inicial <= $1 AND hora_final >= $1 AND activo = false AND disponible = true LIMIT 1;`;
    const result = await client.query(query, [time]);
    return result.rows[0] || null;
  
};


exports.getCurrentShiftAvailable = async (currentDate) => {

    const query = `SELECT * FROM (
                    SELECT id,
                    CONCAT( TO_CHAR(CURRENT_TIMESTAMP AT TIME ZONE 'America/Bogota','YYYY-MM-DD'),' ',hora_inicial) as fecha_inicial,
                    CASE WHEN hora_final < hora_inicial 
                    THEN CONCAT(TO_CHAR( (CURRENT_TIMESTAMP + INTERVAL '1 day') AT TIME ZONE 'America/Bogota','YYYY-MM-DD'),' ',hora_final) ELSE 
                    CONCAT( TO_CHAR(CURRENT_TIMESTAMP AT TIME ZONE 'America/Bogota','YYYY-MM-DD'),' ',hora_final)  END as fecha_final,
                    activo,disponible
                    FROM public.turno
                    ) as t
                    WHERE t.disponible = true AND fecha_inicial < $1 AND $1 < fecha_final LIMIT 1;`;
    const result = await client.query(query, [currentDate]);
    return result.rowCount>0? result.rows[0] : null;
  
};



exports.getShiftToClose = async () => {

    const query = `SELECT * FROM public.turno 
    WHERE activo = true AND disponible = true LIMIT 1;`;
    const result = await client.query(query);
    return result.rows[0] || null;
  
};


exports.closeShift = async (shiftId) => {

    const query = `UPDATE public.historico_turno SET activo = false, 
    fecha_final = (SELECT now() AT TIME ZONE 'America/Bogota')
    WHERE id_turno = $1 AND activo = true;`;
    await client.query(query, [shiftId]);
    return client.query(`UPDATE public.turno SET activo = false WHERE id = $1`, [shiftId]);
}

exports.openShift = async (shiftId, nsxShift) => {

    const query = `INSERT INTO public.historico_turno (id_turno, fecha_inicial) 
    VALUES ($1, (SELECT now() AT TIME ZONE 'America/Bogota'));`;
    await client.query(query, [shiftId]);
    return client.query(`UPDATE public.turno SET activo = true,
    fecha_registro = now(), id_turno_nsx = $2
    WHERE id = $1`, [shiftId,nsxShift.idTurno]);
};



exports.findFirstNSXPosition = async () => {

    const query = `SELECT id_nsx_posicion FROM public.posicion 
    WHERE id = $1 AND activo = true LIMIT 1;`; 
    const result = await client.query(query,[1]);
    return result.rows[0]['id_nsx_posicion'] || 0;  
}