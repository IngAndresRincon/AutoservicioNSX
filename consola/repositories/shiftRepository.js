const { client } = require("../database/dbpostgres");


exports.getShiftToOpen = async (time) => {

    const query = `SELECT * FROM public.turno 
    WHERE hora_inicial <= $1 AND hora_final >= $1 AND activo = false AND disponible = true LIMIT 1;`;
    const result = await client.query(query, [time]);
    return result.rows[0] || null;
  
};

exports.dateValidity = async (currentDate) =>{
    const query = `SELECT * FROM public.turno 
    WHERE ($1 BETWEEN fecha_turno_inicial AND fecha_turno_final) AND activo = $2 AND disponible =$2 LIMIT 1;`;
    const result = await client.query(query,[currentDate,true]);
    return result.rowCount>0 ? true: false;
}

exports.getCurrentShiftAvailable = async (currentDate) => {

//   const query = `SELECT * FROM (
//                     SELECT id,
//                     CONCAT( '2026-07-24',' ',hora_inicial) as fecha_inicial,
//                     CASE WHEN hora_final < hora_inicial 
//                     THEN CONCAT('2026-07-25',' ',hora_final) ELSE 
//                     CONCAT( '2026-07-24',' ',hora_final)  END as fecha_final,
//                     activo,disponible
//                     FROM public.turno
//                     ) as t
//                     WHERE t.disponible = true AND fecha_inicial <= $1 AND $1 <= fecha_final LIMIT 1;`;


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

    const query0 = `UPDATE public.historico_turno SET activo = false, 
    fecha_final = (SELECT now() AT TIME ZONE 'America/Bogota')
    WHERE id_turno = $1 AND activo = true;`;
    const result0 = await client.query(query0, [shiftId]);

    const query1 = `UPDATE public.turno SET activo = false WHERE id = $1`;
    const result1 = await client.query(query1, [shiftId]);
    return result1.rowCount>0? result1.rows[0]:null;
}

exports.openShift = async (shift, nsxShift) => {

    const query0 = `INSERT INTO public.historico_turno (id_turno, fecha_inicial) 
    VALUES ($1, (SELECT now() AT TIME ZONE 'America/Bogota'));`;
    const result0 =await client.query(query0, [shift.id]);

    const query1 = `UPDATE public.turno SET 
    activo = true,
    fecha_turno_inicial = $1,
    fecha_turno_final = $2,
    fecha_registro = now(),
    id_turno_nsx = $3
    WHERE id = $4 RETURNING *;`;

    const result1 = await client.query(query1, [shift.fecha_inicial,shift.fecha_final,nsxShift.idTurno,shift.id]);
    
    return result1.rowCount>0 ?result1.rows[0] :null;
};



exports.findFirstNSXPosition = async () => {

    const query = `SELECT id_nsx_posicion FROM public.posicion 
    WHERE id = $1 AND activo = true LIMIT 1;`; 
    const result = await client.query(query,[1]);
    return result.rowCount>0?result.rows[0]['id_nsx_posicion'] : 0;  
}