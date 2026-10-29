const logger = require("../../config/logger");
const AppError = require("../../errors/AppError");
const { client } = require("../../database/dbpostgres");

const fail = (message, error) => {
  logger.error(message, error);
  return new AppError(message, 502, { details: error.message });
};

exports.findPosition = async (positionId) => {
  try {
    const query = `SELECT p.id, p.id_nsx_posicion, d.hibrido
                   FROM public.posicion as p
                   INNER JOIN public.dispensador as d ON d.id = p.id_dispensador
                   WHERE p.id = $1;`;
    const result = await client.query(query, [positionId]);
    return result.rows[0] || null;
  } catch (error) {
    throw fail("Error consultando la posicion", error);
  }
};

exports.findSellerPaymentMethods = async (nsxPaymentIds) => {
  try {
    const query = `SELECT id_nsx_forma_pago FROM public.forma_pago_vendedor WHERE id_nsx_forma_pago = ANY($1::int[]);`;
    const result = await client.query(query, [nsxPaymentIds]);
    return result.rows.map((row) => row.id_nsx_forma_pago);
  } catch (error) {
    throw fail("Error consultando las formas de pago del vendedor", error);
  }
};

exports.openSellerShift = async ({ document, nsxShiftId, positionId }) => {
  try {
    const existing = await client.query(
      `SELECT id FROM public.turno_vendedor WHERE documento = $1 AND id_turno_nsx = $2 AND activo = true LIMIT 1;`,
      [document, nsxShiftId],
    );
    if (existing.rowCount > 0) {
      return existing.rows[0];
    }

    const result = await client.query(
      `INSERT INTO public.turno_vendedor (documento, id_turno_nsx, id_posicion) VALUES ($1, $2, $3) RETURNING *;`,
      [document, nsxShiftId, positionId],
    );
    return result.rows[0];
  } catch (error) {
    throw fail("Error registrando el turno del vendedor", error);
  }
};

// Deja el turno del vendedor igual que NSX: con turno abierto lo registra (si se abrio desde otro equipo o antes) y
// cierra cualquier otro; sin turno abierto cierra el que tuviera marcado
exports.syncSellerShift = async ({ document, nsxShiftId }) => {
  try {
    if (!nsxShiftId) {
      await client.query(
        `UPDATE public.turno_vendedor SET activo = false, fecha_cierre = CURRENT_TIMESTAMP WHERE documento = $1 AND activo = true;`,
        [document],
      );
      return;
    }

    await client.query(
      `UPDATE public.turno_vendedor SET activo = false, fecha_cierre = CURRENT_TIMESTAMP
       WHERE documento = $1 AND activo = true AND id_turno_nsx <> $2;`,
      [document, nsxShiftId],
    );

    const existing = await client.query(
      `SELECT id FROM public.turno_vendedor WHERE documento = $1 AND id_turno_nsx = $2 AND activo = true LIMIT 1;`,
      [document, nsxShiftId],
    );
    if (existing.rowCount > 0) {
      return;
    }

    const position = await client.query(
      `SELECT p.id FROM public.posicion p INNER JOIN public.dispensador d ON d.id = p.id_dispensador
       WHERE d.hibrido = true ORDER BY p.id LIMIT 1;`,
    );
    if (position.rowCount === 0) {
      return;
    }
    await client.query(
      `INSERT INTO public.turno_vendedor (documento, id_turno_nsx, id_posicion) VALUES ($1, $2, $3);`,
      [document, nsxShiftId, position.rows[0].id],
    );
  } catch (error) {
    throw fail("Error sincronizando el turno del vendedor", error);
  }
};

exports.closeSellerShift = async (document) => {
  try {
    await client.query(
      `UPDATE public.turno_vendedor SET activo = false, fecha_cierre = CURRENT_TIMESTAMP
       WHERE documento = $1 AND activo = true;`,
      [document],
    );
    return true;
  } catch (error) {
    throw fail("Error cerrando el turno del vendedor", error);
  }
};

// Reserva la posicion: bajo un candado por posicion revisa que no haya autoservicio ni otro preset de vendedor activo
// (sin venta; el estado del preset lo mantiene consola desde NSX) e inserta el preset en estado 0.
// Estados de public.estado: 0, 2 y 8 = activo.
exports.reservePreset = async (params) => {
  const db = await client.connect();
  try {
    await db.query("BEGIN");
    await db.query("SELECT pg_advisory_xact_lock($1);", [params.positionId]);

    const autoActive = await db.query(
      `SELECT 1 FROM public.autorizacion
       WHERE id_posicion = $1 AND sincronizado IN (0, 2, 8) AND id_venta IS NULL
         AND fecha_registro > NOW() - INTERVAL '30 minutes' LIMIT 1;`,
      [params.positionId],
    );
    if (autoActive.rowCount > 0) {
      throw new AppError("La posicion esta ocupada por un cliente de autoservicio", 409);
    }

    const sellerActive = await db.query(
      `SELECT 1 FROM public.preset_vendedor
       WHERE id_posicion = $1 AND sincronizado IN (0, 2, 8) AND id_venta IS NULL LIMIT 1;`,
      [params.positionId],
    );
    if (sellerActive.rowCount > 0) {
      throw new AppError("La posicion ya tiene un preset de vendedor activo", 409);
    }

    const clientActive = await db.query(
      `SELECT 1 FROM public.preset_cliente
       WHERE id_posicion = $1 AND sincronizado IN (0, 2, 8) AND id_venta IS NULL LIMIT 1;`,
      [params.positionId],
    );
    if (clientActive.rowCount > 0) {
      throw new AppError("La posicion esta ocupada por un cliente identificado", 409);
    }

    const result = await db.query(
      `INSERT INTO public.preset_vendedor
         (documento, id_posicion, numero_manguera, tipo_programacion, valor, placa, km, id_turno_vendedor)
       VALUES ($1::varchar, $2, $3, $4, $5, $6, $7,
               (SELECT id FROM public.turno_vendedor WHERE documento = $1::varchar AND activo = true ORDER BY id DESC LIMIT 1))
       RETURNING *;`,
      [
        params.document,
        params.positionId,
        params.hoseNumber,
        params.programmingType,
        params.value,
        params.plate,
        params.km,
      ],
    );

    await db.query("COMMIT");
    return result.rows[0];
  } catch (error) {
    await db.query("ROLLBACK");
    if (error instanceof AppError) {
      throw error;
    }
    throw fail("Error registrando el preset del vendedor", error);
  } finally {
    db.release();
  }
};

exports.updatePreset = async (id, { state, nsxPresetId = null, message = null }) => {
  try {
    const query = `UPDATE public.preset_vendedor
                   SET sincronizado = $2,
                       id_presetnsx = COALESCE($3, id_presetnsx),
                       mensaje = $4,
                       fecha_actualizacion = CURRENT_TIMESTAMP
                   WHERE id = $1
                   RETURNING *;`;
    const result = await client.query(query, [id, state, nsxPresetId, message]);
    return result.rows[0] || null;
  } catch (error) {
    throw fail("Error actualizando el preset del vendedor", error);
  }
};

exports.getPreset = async (id, document) => {
  try {
    const query = `SELECT * FROM public.preset_vendedor WHERE id = $1 AND documento = $2;`;
    const result = await client.query(query, [id, document]);
    return result.rows[0] || null;
  } catch (error) {
    throw fail("Error consultando el preset del vendedor", error);
  }
};

exports.findCancelablePreset = async (document, positionId) => {
  try {
    const query = `SELECT * FROM public.preset_vendedor
                   WHERE documento = $1 AND id_posicion = $2
                     AND sincronizado IN (2, 8) AND id_venta IS NULL
                   ORDER BY id DESC LIMIT 1;`;
    const result = await client.query(query, [document, positionId]);
    return result.rows[0] || null;
  } catch (error) {
    throw fail("Error consultando el preset a cancelar", error);
  }
};

// Estado de cada posicion de la pantalla: libre o el despacho activo (autoservicio, vendedor o cliente identificado)
exports.positionsStatus = async (screenId) => {
  try {
    const result = await client.query(
      `WITH pos AS (
         SELECT p.id, p.id_nsx_posicion
         FROM public.posicion as p
         INNER JOIN public.pantalla_posicion as pp ON pp.id_posicion = p.id
         WHERE pp.id_pantalla = $1
       ),
       act AS (
         SELECT id_posicion, 'autoservicio' as origen, id as preset_id, sincronizado as sync, valor_dinero as valor, NULL::varchar as documento
           FROM public.autorizacion
           WHERE sincronizado IN (0, 2, 8) AND id_venta IS NULL AND fecha_registro > NOW() - INTERVAL '30 minutes'
         UNION ALL
         SELECT id_posicion, 'vendedor', id, sincronizado, valor, documento
           FROM public.preset_vendedor WHERE sincronizado IN (0, 2, 8) AND id_venta IS NULL
         UNION ALL
         SELECT id_posicion, 'cliente', id, sincronizado, valor, documento
           FROM public.preset_cliente WHERE sincronizado IN (0, 2, 8) AND id_venta IS NULL
       )
       SELECT pos.id as positionid, pos.id_nsx_posicion as nsxpositionid,
              act.origen, act.preset_id as presetid, act.sync, act.valor as value, act.documento as document
       FROM pos
       LEFT JOIN LATERAL (SELECT * FROM act WHERE act.id_posicion = pos.id LIMIT 1) as act ON true
       ORDER BY pos.id;`,
      [screenId],
    );
    return result.rows;
  } catch (error) {
    throw fail("Error consultando el estado de las posiciones", error);
  }
};

// Ventas del vendedor en su turno abierto (mas recientes primero), con lo ya anclado y si tiene factura
exports.shiftSales = async (document) => {
  try {
    // Efectivo (preset_vendedor) y credito (preset_cliente con el turno del vendedor)
    const query = `SELECT * FROM (
                     SELECT p.id AS preset_id, p.id_venta AS sale_id, p.id_presetnsx AS preset_nsx_id,
                            pos.id_nsx_posicion AS nsx_position_id, p.numero_manguera AS hose_number,
                            p.tipo_programacion AS type, p.valor AS value, p.fecha_actualizacion AS date,
                            COALESCE((SELECT SUM(valor) FROM public.preset_vendedor_pago WHERE id_preset_vendedor = p.id), 0) AS paid,
                            EXISTS (SELECT 1 FROM public.factura f WHERE f.venta_id = p.id_venta) AS invoiced,
                            false AS credit
                     FROM public.preset_vendedor p
                     INNER JOIN public.turno_vendedor t ON t.id = p.id_turno_vendedor AND t.activo = true
                     LEFT JOIN public.posicion pos ON pos.id = p.id_posicion
                     WHERE p.documento = $1 AND p.id_venta IS NOT NULL
                     UNION ALL
                     SELECT c.id, c.id_venta, c.id_presetnsx, pos.id_nsx_posicion, c.numero_manguera,
                            c.tipo_programacion, c.valor, c.fecha_actualizacion,
                            0,
                            EXISTS (SELECT 1 FROM public.factura f WHERE f.venta_id = c.id_venta),
                            true
                     FROM public.preset_cliente c
                     INNER JOIN public.turno_vendedor t ON t.id = c.id_turno_vendedor AND t.activo = true
                     LEFT JOIN public.posicion pos ON pos.id = c.id_posicion
                     WHERE c.documento = $1 AND c.id_venta IS NOT NULL
                   ) sales
                   ORDER BY date DESC
                   LIMIT 30;`;
    const result = await client.query(query, [document]);
    return result.rows;
  } catch (error) {
    throw fail("Error consultando las ventas del turno", error);
  }
};

exports.findPresetBySale = async (saleId, document) => {
  try {
    const query = `SELECT * FROM public.preset_vendedor WHERE id_venta = $1 AND documento = $2 LIMIT 1;`;
    const result = await client.query(query, [saleId, document]);
    return result.rows[0] || null;
  } catch (error) {
    throw fail("Error consultando la venta del vendedor", error);
  }
};

exports.insertPayments = async (presetId, saleId, items) => {
  try {
    for (const item of items) {
      await client.query(
        `INSERT INTO public.preset_vendedor_pago
           (id_preset_vendedor, id_venta, id_nsx_forma_pago, valor, identificador)
         VALUES ($1, $2, $3, $4, $5);`,
        [presetId, saleId, item.paymentMethodId, item.amount, item.reference ?? null],
      );
    }
    return true;
  } catch (error) {
    throw fail("Error registrando las formas de pago del vendedor", error);
  }
};
