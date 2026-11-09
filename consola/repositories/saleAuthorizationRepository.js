const { client } = require("../database/dbpostgres");
const logger = require("../utils/logger");

exports.getPendingSaleAuthorization = async () => {
    
  const query = `SELECT a.id,id_programacion,id_presetnsx,id_venta,a.id_posicion,tp.id_terminal
                  FROM public.autorizacion as a
                  INNER JOIN public.terminal_posicion as tp
                  ON a.id_posicion = tp.id_posicion AND tp.activo = $1
                  WHERE sincronizado = $2 AND id_venta IS NULL`;
  const result  = await client.query(query, [true, 2]);
  return result.rowCount > 0 ? result.rows : [];

};

exports.reportStatusWhileSupplying = async (id) => {

  const query = `UPDATE public.autorizacion 
                    SET sincronizado = $1
                    WHERE id = $2 AND sincronizado != $3;`;
  const result = await client.query(query,[8,id,8]);
  return result.rowCount > 0 ? true : false;
}

exports.markSaleAuthorizationAsFailed = async (id) => {

  const query = `UPDATE public.autorizacion 
                    SET sincronizado = $1
                    WHERE id = $2 RETURNING * ;`;
  const result = await client.query(query,[3,id]);
  return result.rowCount > 0 ? true : false;
};

exports.markSaleAuthorizationAsVentaZero = async (id) => {

  const query = `UPDATE public.autorizacion 
                    SET sincronizado = $1
                    WHERE id = $2 RETURNING *;`;
  const result = await client.query(query,[6,id]);
  return result.rowCount > 0 ? true : false;
};

exports.registerSaleAuthorization = async (auth, sale) => {
  try {
    const saleResult = await saveRecordSale(sale);

    if (!saleResult) {
      logger.error(`No se logró almacenar los datos de la venta: ${JSON.stringify(sale)}`);
      return false;
    }

    const query = `UPDATE public.autorizacion 
                    SET id_venta = $1, sincronizado  = $2
                    WHERE id = $3 AND sincronizado IN (8,2);`;
    const result = await client.query(query, [sale.idVenta,4,auth.id]);
    return result.rowCount > 0 ? true : false;
  } catch (e) {
    logger.error(`Error al registrar la venta: ${e.message}`);
  }
  return false;
};


exports.findPaymentMethodByProgramming = async(programmingId) => {
  const query = `SELECT * FROM public.transaccion_pago 
                  WHERE id_programacion = $1 
                  AND id_estado_transaccion = $2 LIMIT 1;`;
  const result = await client.query(query, [programmingId, 2]);
  return result.rowCount>0 ? result.rows[0] : null; 
}

exports.findRecordHospitalitySale = async(authorizationId) =>{

    const query = `SELECT id FROM public.aprobacion_pago 
                    WHERE id_autorizacion = $1;`;
    const result = await client.query(query, [authorizationId]);
    return result.rowCount>0 ? result.rows[0] : null;
}

exports.registerSaleForHospitality = async (auth, reciptId, sale) => {

  const query = `INSERT INTO public.aprobacion_pago (
                  id_autorizacion,
                  id_terminal,
                  monto,
                  id_recibo
                ) VALUES($1, $2, $3, $4) RETURNING *;`;

  const result = await client.query(query, [
                    auth.id,
                    auth.id_terminal,
                    sale.dinero,
                    reciptId]);
  return result.rowCount>0 ? result.rows[0] : null;
}


const saveRecordSale = async (sale) => {
  const queryText = `INSERT INTO public.venta (
                        id_venta_nsx,
                        id_preset_nsx,
                        id_posicion,
                        id_manguera,
                        dinero,
                        volumen,
                        precio,
                        saldo,
                        id_turno
                      )
                      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, (SELECT MAX(id) FROM public.historico_turno WHERE activo = true LIMIT 1))
                      RETURNING *;`;

  const result = await client.query(queryText, [
    sale.idVenta,
    sale.idProgramacion,
    sale.idPosicion,
    sale.numeroManguera,
    sale.dinero,
    sale.volumen,
    sale.precioVenta,
    sale.vuelto,
  ]);

  return result.rows[0] || null;
};
