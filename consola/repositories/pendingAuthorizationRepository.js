const { client } = require("../database/dbpostgres");
const model = require("../model/preset");
const logger = require("../utils/logger");

exports.getPendingAuthorization = async () => {
  let pendingAutho = null;
  try {
    let query = `SELECT 
                      a.id as idautorizacion,
                      pg.id as idprogramacion,
                      p.id_nsx_posicion as numposicion,
                      m.numero_manguera as nummanguera,
                      a.tipo_programacion as tipoprogramacion,
                      ROUND(a.preset,2) as valor,
                      a.valor_dinero as valordinero,
                      c.placa,
                      c.km,
                      (SELECT id_turno_nsx FROM public.turno WHERE activo = true LIMIT 1) as idturnonsx
                    FROM  public.autorizacion as a
                    INNER JOIN public.posicion as p
                    ON a.id_posicion = p.id 
                    INNER JOIN public.manguera as m
                    ON a.id_manguera = m.id 
                    INNER JOIN public.producto as pro
                    ON a.id_producto = pro.id
                    INNER JOIN public.programacion as pg
                    ON a.id_programacion = pg.id
                    INNER JOIN public.cliente as c
                    ON pg.id_cliente = c.id
                    WHERE a.sincronizado = 0 LIMIT 1;`;
    const res0 = await client.query(query);

    console.log(JSON.stringify(res0.rows[0]));

    if (res0.rowCount > 0) {
      let itemAuth = res0.rows[0];

      query = `SELECT 
              fp.id_nsx_forma_pago as idformapago,
              tp.valor,
              tp.respuesta_pago as identificador
              FROM public.transaccion_pago as tp
              INNER JOIN public.forma_pago as fp
              ON tp.id_forma_pago = fp.id
            WHERE id_programacion = ${itemAuth.idprogramacion} AND tp.id_estado_transaccion=2;`;
        const res1 = await client.query(query);

        let _fp = [];
        if (res1.rowCount > 0) {
          const arryfp = Array.from(
            { length: res1.rowCount },
            (_, i) => res1.rows[i],
          );
          arryfp.forEach((e) => {
            _fp.push(
              new model.FormaPago(
                e.idformapago,
                parseInt(e.valor),
                e.identificador,
              ),
            );
          });
        }

        const _preset = new model.Preset(
          itemAuth.numposicion,
          itemAuth.nummanguera,
          itemAuth.tipoprogramacion,
          parseFloat(itemAuth.valor),
          parseInt(itemAuth.valordinero),
          itemAuth.placa,
          itemAuth.km,
          _fp,
          itemAuth.idturnonsx
        );
        pendingAutho ={
          authorizationId: itemAuth.idautorizacion,
          preset: _preset,
        };  
    }
  } catch (e) {
    logger.error(e);
  }

  return pendingAutho;
};

exports.updateAuthorizationSync = async (params, data, statusCode) => {
  let sync = false;
  try {
    const idPresetNsx = data.data === null ? 0 : data.data.idPreset;

    const query = `UPDATE public.autorizacion 
                    SET sincronizado = ${statusCode},
                        id_presetnsx = ${idPresetNsx}
                    WHERE id = ${params.authorizationId};`;
    const response = await client.query(query);
    if (response.rowCount > 0) {
      sync = true;
    }
  } catch (e) {
    logger.error(e);
    throw new Error("Error:" + e.message);
  }

  return sync;
};
