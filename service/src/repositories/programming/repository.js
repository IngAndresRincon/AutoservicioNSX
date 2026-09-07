const logger = require("../../config/logger");
const AppError = require("../../errors/AppError");
const { client } = require("../../database/dbpostgres");

exports.createprogramming = async (params) => {
  try {

    const openShit = await client.query(`SELECT id FROM  public.turno 
    WHERE activo = true AND disponible = true;`);
    if (openShit.rowCount === 0 ) {
      throw new AppError("No hay un turno disponible en este momento, valide de nuevo más tarde", 503);
    }

    let query = `SELECT
      id, posicion_id, manguera_id, valor_programado, valor_dinero,
      tipo_programacion, precio, sincronizado,
      valor_abonado, valor_pendiente,
      id_producto, id_cliente, fecha_registro
      FROM public.programacion
      WHERE id_cliente = $1 AND valor_abonado > 0 AND sincronizado = false
      LIMIT 1;`;
    const res0 = await client.query(query, [params.clientId]);

    if (res0.rowCount > 0) {
      return {
        idRecovered: true,
        programming: res0.rows[0],
      };
    }

    const moneyValue =
      params.programmingType === 2
        ? params.programmingValue
        : params.programmingType === 3
          ? params.programmingValue * params.price
          : 0;

    query = `SELECT id FROM public.programacion
      WHERE id_cliente = $1 AND valor_abonado = 0 AND sincronizado = false
      LIMIT 1;`;
    const res1 = await client.query(query, [params.clientId]);

    if (res1.rowCount > 0) {
      query = `UPDATE public.programacion SET
        posicion_id = $1,
        manguera_id = $2,
        valor_programado = $3,
        valor_dinero = $4,
        tipo_programacion = $5,
        precio = $6,
        valor_pendiente = $7,
        id_producto = $8
        WHERE id_cliente = $9 AND valor_abonado = 0
        RETURNING *;`;
    } else {
      query = `INSERT INTO public.programacion(
        posicion_id,
        manguera_id,
        valor_programado,
        valor_dinero,
        tipo_programacion,
        precio,
        valor_pendiente,
        id_producto,
        id_cliente)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        RETURNING *;`;
    }

    const values = [
      params.positionId,
      params.hoseId,
      params.programmingValue,
      moneyValue,
      params.programmingType,
      params.price,
      moneyValue,
      params.productId,
      params.clientId,
    ];

    const res2 = await client.query(query, values);
    return res2.rowCount > 0
      ? {
          idRecovered: false,
          programming: res2.rows[0],
        }
      : null;
  } catch (error) {
    logger.error("Error creando programacion", error);
    throw new AppError("Error creando programacion", 502, { details: error.message });
  }
};

exports.createPayment = async (params) => {
  const dbClient = await client.connect();

  try {
    await dbClient.query("BEGIN");

    let query = `SELECT id FROM public.transaccion_pago
      WHERE id_programacion = $1 AND id_estado_transaccion IN (4)
      LIMIT 1;`;
    const res0 = await dbClient.query(query, [params.programmingId]);
    if (res0.rowCount > 0) {
      throw new AppError("Ya existe un pago registrado para esta programacion", 409);
    }

    query = `UPDATE public.transaccion_pago SET id_estado_transaccion = 3
      WHERE id_programacion = $1 AND id_estado_transaccion IN (0, 1);`;
    await dbClient.query(query, [params.programmingId]);

    query = `INSERT INTO public.transaccion_pago 
    (id_programacion,respuesta_pago,valor,id_forma_pago,id_estado_transaccion)
    VALUES ($1, $2, $3, $4, $5) RETURNING *;`;

    console.log('Id método de pago validado', params.paymentmethodId);
    const nsxCodePayment =  await getMethodPaymentCode(params.paymentmethodId);
    if(!nsxCodePayment){
      throw new AppError("No hay información del método de pago asociado", 404);
    }


    const statusPayment = params.paymentmethodId === 3 ? 4 : 0;
    
    //const statusPayment = nsxCodePayment === 26 ? 4 : 0; // Se deja en 4 porque el proceso de generación de vuelto en NSX se encarga de actualizar el estado del pago a aprobado, esto para los pagos con código 26 que corresponde a QR Vueltos o Bono, para los demás métodos de pago se deja en estado pendiente de aprobación (0)
    // Si es QR vueltos o Bono se marca como aprobado directamente, de lo contrario queda pendiente de aprobación

    const res1 = await dbClient.query(query, [
      params.programmingId,
      params.ref,
      params.amounttopay,
      params.paymentmethodId,
      statusPayment
    ]);

    await dbClient.query("COMMIT");
    return res1.rowCount > 0 ? res1.rows[0] : null;
  } catch (error) {
    await dbClient.query("ROLLBACK");
    if (error instanceof AppError) {
      throw error;
    }
    logger.error("Error creando pago de programacion", error);
    throw new AppError("Error creando programacion", 502, { details: error.message });
  } finally {
    dbClient.release();
  }
};


async function getMethodPaymentCode(id) {
  const query = `SELECT id_nsx_forma_pago FROM public.forma_pago WHERE id = $1;`;
  const result =  await client.query(query, [id]);
  return result.rowCount > 0 ? result.rows[0].id_nsx_forma_pago : null;
}

exports.pendingProgramming = async (userId) => {
  try {
    const query = `
       SELECT
        p.id idprogramacion,
        p.posicion_id,
        p.manguera_id,
        p.tipo_programacion,
        p.valor_programado,
        p.valor_dinero,
        p.precio,
        p.valor_pendiente,
		    p.valor_abonado,
        p.id_producto,
        p.id_cliente,
		    p.sincronizado 
      FROM public.programacion as p
      WHERE p.sincronizado = false AND valor_abonado > 0 AND p.id_cliente = $1
      LIMIT 1;`;
    const res0 = await client.query(query, [userId]);
    return res0.rowCount === 0 ? null : res0.rows[0];
  } catch (error) {
    logger.error("Error consultando programacion pendiente", error);
    throw new AppError("Error consultando programacion pendiente", 502, { details: error.message });
  }
};


exports.pendingAuthorization = async (userId) => {
  try {
    const query = `
      SELECT
        p.id idprogramacion,
        p.posicion_id,
        p.manguera_id,
        p.tipo_programacion,
        p.valor_programado,
        p.valor_dinero,
        p.precio,
        p.valor_pendiente,
        p.id_producto,
        p.id_cliente,
        a.id as idautorizacion,
        a.id_presetnsx,
        a.sincronizado,
        e.nombre as estado
      FROM public.programacion as p
      INNER JOIN public.autorizacion as a ON p.id = a.id_programacion
      INNER JOIN public.estado as e ON a.sincronizado = e.codigo
      WHERE a.sincronizado in (6,3) AND p.id_cliente = $1
      LIMIT 1;`;
    const res0 = await client.query(query, [userId]);
    return res0.rowCount === 0 ? null : res0.rows[0];
  } catch (error) {
    logger.error("Error consultando programacion pendiente", error);
    throw new AppError("Error consultando programacion pendiente", 502, { details: error.message });
  }
};


exports.resendAuthorization = async (authorizationId) => {
  try {
    const query = `UPDATE public.autorizacion SET sincronizado = 0
      WHERE id = $1 AND sincronizado IN (6,3)
      RETURNING *;`;
    const res0 = await client.query(query, [authorizationId]);
    return res0.rows[0] || null;
  } catch (error) {
    logger.error("Error reenviando autorizacion", error);
    throw new AppError("Error reenviando autorizacion", 502, { details: error.message });
  }
};


exports.authorizeProgramming = async (clientId, programmingId) => {
  try {
    const query = `UPDATE public.programacion SET 
                  valor_dinero = valor_abonado,
                  valor_programado = CASE WHEN tipo_programacion = 2 THEN valor_abonado ELSE (valor_abonado/precio) END,
                  valor_pendiente = 0
                  WHERE id_cliente = $1 AND id = $2 RETURNING *;`;
    const res0 = await client.query(query, [clientId, programmingId]);
    return res0.rows[0] || null;
  } catch (error) {
    logger.error("Error reenviando autorizacion", error);
    throw new AppError("Error reenviando autorizacion", 502, { details: error.message });
  }
};



