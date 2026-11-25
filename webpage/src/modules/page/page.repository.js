const axios = require('axios');
const { env } = require('../../config/env');
const { client } = require('../../data/connection');

// Estados de transaccion_pago (no vienen de una tabla, es un enum fijo del sistema de pagos)
const ESTADOS_PAGO = {
  1: 'Pendiente',
  2: 'Completado',
  3: 'Cancelado',
  4: 'Autorizado',
  5: 'Anulado',
  6: 'Leído',
  7: 'Validando',
};

function conEstadoPago(pagos) {
  return pagos.map((p) => ({
    ...p,
    estado: ESTADOS_PAGO[p.idestado] || `Desconocido (${p.idestado})`,
  }));
}

const ESTADOS_VUELTO = {
  1: 'Creado',
  2: 'Reservado',
  3: 'Usado',
  4: 'Vencido',
};

// El vuelto real de una programación vive en el API NSX, no en la BD local.
async function getVueltoByProgramacion(idProgramacion) {
  const response = await axios.get(
    `${env.api.baseUrl}/api/Vueltos/ObtenerVueltoByIdProgramacion`,
    { params: { idProgramacion }, validateStatus: () => true }
  );
  const vuelto = response.data?.data;
  if (!vuelto) return null;

  return { ...vuelto, estado: ESTADOS_VUELTO[vuelto.idEstadoVuelto] || `Desconocido (${vuelto.idEstadoVuelto})` };
}

// Reenvía el vuelto a la impresora (API NSX)
async function reimprimirVuelto(codigo) {
  const response = await axios.get(
    `${env.api.baseUrl}/api/Vueltos/ImprimirVueltos`,
    { params: { codigo }, validateStatus: () => true }
  );
  return { success: !!response.data?.success, message: response.data?.message };
}

// Pagos intentados de una programación, usado por los tres detalles (autorización/programación/venta)
async function getPagosByProgramacion(idProgramacion) {
  const { rows } = await client.query(
    `
    SELECT
      tp.id AS idpago,
      tp.valor,
      fp.nombre AS formapago,
      tp.id_estado_transaccion AS idestado,
      tp.respuesta_pago AS respuesta,
      TO_CHAR(tp.fecha_transaccion, 'YYYY-MM-DD HH24:MI:SS') AS fecha
    FROM transaccion_pago tp
    LEFT JOIN forma_pago fp ON fp.id = tp.id_forma_pago
    WHERE tp.id_programacion = $1
    ORDER BY tp.fecha_transaccion DESC
    `,
    [idProgramacion]
  );
  return conEstadoPago(rows);
}

async function login(userName, password) {
  return axios.post(
    `${env.api.baseUrl}/api/Admin/Login`,
    { userName, password },
    { validateStatus: () => true }
  );
}

async function getCatalogos() {
  return axios.get(
    `${env.api.baseUrl}/api/Admin/ObtenerCatalogos`,
    { validateStatus: () => true }
  );
}

// Autorizadas para pago, listas para despachar (aún sin venta asociada)
async function getAutorizaciones() {
  const { rows } = await client.query(`
    SELECT
      a.id AS idautorizacion,
      pr.nombre AS producto,
      a.preset AS programacion,
      a.tipo_programacion AS tipoprogramacion,
      p.valor_abonado AS valorabonado,
      a.precio AS precio,
      c.identificador AS identificador,
      TO_CHAR(a.fecha_registro, 'YYYY-MM-DD HH24:MI:SS') AS fecharegistro
    FROM autorizacion a
    LEFT JOIN programacion p ON p.id = a.id_programacion
    LEFT JOIN producto pr ON pr.id = a.id_producto
    LEFT JOIN cliente c ON c.id = p.id_cliente
    WHERE a.id_venta IS NULL AND a.sincronizado IS DISTINCT FROM -1
    ORDER BY a.fecha_registro DESC
    LIMIT 100
  `);
  return rows;
}

// Solicitudes programadas que todavía no tienen autorización (pendientes de pago)
async function getProgramaciones() {
  const { rows } = await client.query(`
    SELECT
      p.id AS idautorizacion,
      pr.nombre AS producto,
      p.valor_programado AS programacion,
      p.tipo_programacion AS tipoprogramacion,
      p.valor_abonado AS valorabonado,
      p.valor_pendiente AS valorpendiente,
      p.precio AS precio,
      c.identificador AS identificador,
      TO_CHAR(p.fecha_registro, 'YYYY-MM-DD HH24:MI:SS') AS fecharegistro
    FROM programacion p
    LEFT JOIN producto pr ON pr.id = p.id_producto
    LEFT JOIN cliente c ON c.id = p.id_cliente
    WHERE NOT EXISTS (SELECT 1 FROM autorizacion a WHERE a.id_programacion = p.id)
    ORDER BY (p.valor_abonado > 0) DESC, p.fecha_registro DESC
    LIMIT 100
  `);
  return rows;
}

// Últimas ventas (despachos ya completados)
async function getVentas() {
  const { rows } = await client.query(`
    SELECT
      v.id AS idventa,
      a.id AS idautorizacion,
      pr.nombre AS producto,
      a.preset AS programacion,
      a.tipo_programacion AS tipoprogramacion,
      a.precio AS precio,
      v.dinero AS dinero,
      v.volumen AS volumen,
      TO_CHAR(v.fecha_registro, 'YYYY-MM-DD HH24:MI:SS') AS fechainicial,
      TO_CHAR(v.fecha_registro, 'YYYY-MM-DD HH24:MI:SS') AS fechafinal
    FROM venta v
    LEFT JOIN autorizacion a ON a.id_venta = v.id_venta_nsx
    LEFT JOIN producto pr ON pr.id = a.id_producto
    ORDER BY v.fecha_registro DESC
    LIMIT 100
  `);
  return rows;
}

// Arqueo del turno activo: ventas agrupadas por producto
async function getArqueo() {
  const { rows } = await client.query(`
    SELECT
      pr.nombre AS producto,
      SUM(v.dinero) AS totaldinero,
      ROUND(SUM(v.volumen)::numeric, 3) AS totalvolumen,
      COUNT(*) AS ventas
    FROM venta v
    JOIN historico_turno ht ON ht.id = v.id_turno AND ht.activo = true
    LEFT JOIN autorizacion a ON a.id_venta = v.id_venta_nsx
    LEFT JOIN producto pr ON pr.id = a.id_producto
    GROUP BY pr.nombre
    ORDER BY pr.nombre
  `);
  return rows;
}

// Transferencia de saldos: ventas que quedaron con un sobrante (dispensaron menos de
// lo programado) y por lo tanto le deben un saldo al cliente. Se cruza con
// devolucion_saldo por si ya hay un intento de devolución registrado (puede no haberlo).
// No se traduce "estado" a texto porque no hay una lista oficial de sus valores.
async function getTransferenciaSaldos() {
  const { rows } = await client.query(`
    SELECT
      v.id AS idventa,
      v.id_venta_nsx AS idventasistema,
      a.id AS idautorizacion,
      a.id_programacion AS idprogramacion,
      a.id_presetnsx AS idpresetnsx,
      pr.nombre AS producto,
      c.identificador,
      v.dinero,
      v.saldo,
      TO_CHAR(v.fecha_registro, 'YYYY-MM-DD HH24:MI:SS') AS fecharegistro
    FROM venta v
    JOIN autorizacion a ON a.id_venta = v.id_venta_nsx
    LEFT JOIN programacion p ON p.id = a.id_programacion
    LEFT JOIN producto pr ON pr.id = a.id_producto
    LEFT JOIN cliente c ON c.id = p.id_cliente
    WHERE v.saldo > 0
    ORDER BY v.fecha_registro DESC
    LIMIT 100
  `);

  // El estado real del vuelto vive en el API NSX; se consulta en paralelo por cada fila.
  // El "idProgramacion" que pide esa API es id_presetnsx (el id del lado NSX), no el local.
  return Promise.all(
    rows.map(async (row) => ({ ...row, vuelto: await getVueltoByProgramacion(row.idpresetnsx) }))
  );
}

// CASE que traduce id_estado_transaccion a texto, para poder buscar por estado en SQL
// (debe reflejar el mismo mapeo que ESTADOS_PAGO arriba)
const ESTADO_PAGO_SQL_CASE = `CASE tp.id_estado_transaccion
  WHEN 1 THEN 'Pendiente' WHEN 2 THEN 'Completado' WHEN 3 THEN 'Cancelado'
  WHEN 4 THEN 'Autorizado' WHEN 5 THEN 'Anulado' WHEN 6 THEN 'Leído'
  WHEN 7 THEN 'Validando' ELSE 'Desconocido' END`;

// Reporte de pagos: filtrado por fecha/texto y paginado en el servidor (la tabla puede tener miles de filas)
async function getReportePagos({ from, to, q, page = 1, pageSize = 25 }) {
  const offset = (page - 1) * pageSize;
  const params = [from || null, to || null, q || null, pageSize, offset];

  const { rows } = await client.query(
    `
    SELECT
      tp.id AS idpago,
      fp.nombre AS formapago,
      tp.id_estado_transaccion AS idestado,
      tp.valor,
      tp.respuesta_pago AS respuesta,
      TO_CHAR(tp.fecha_transaccion, 'YYYY-MM-DD HH24:MI:SS') AS fecha,
      c.identificador,
      COUNT(*) OVER() AS total_count,
      SUM(CASE WHEN tp.id_estado_transaccion = 2 THEN tp.valor ELSE 0 END) OVER() AS total_completado
    FROM transaccion_pago tp
    LEFT JOIN forma_pago fp ON fp.id = tp.id_forma_pago
    LEFT JOIN programacion p ON p.id = tp.id_programacion
    LEFT JOIN cliente c ON c.id = p.id_cliente
    WHERE ($1::date IS NULL OR tp.fecha_transaccion::date >= $1)
      AND ($2::date IS NULL OR tp.fecha_transaccion::date <= $2)
      AND (
        $3::text IS NULL
        OR tp.id::text ILIKE '%' || $3 || '%'
        OR c.identificador ILIKE '%' || $3 || '%'
        OR fp.nombre ILIKE '%' || $3 || '%'
        OR ${ESTADO_PAGO_SQL_CASE} ILIKE '%' || $3 || '%'
      )
    ORDER BY tp.fecha_transaccion DESC
    LIMIT $4 OFFSET $5
    `,
    params
  );

  const { rows: porFormaPago } = await client.query(
    `
    SELECT fp.nombre AS formapago, SUM(tp.valor) AS total
    FROM transaccion_pago tp
    LEFT JOIN forma_pago fp ON fp.id = tp.id_forma_pago
    LEFT JOIN programacion p ON p.id = tp.id_programacion
    LEFT JOIN cliente c ON c.id = p.id_cliente
    WHERE tp.id_estado_transaccion = 2
      AND ($1::date IS NULL OR tp.fecha_transaccion::date >= $1)
      AND ($2::date IS NULL OR tp.fecha_transaccion::date <= $2)
      AND (
        $3::text IS NULL
        OR tp.id::text ILIKE '%' || $3 || '%'
        OR c.identificador ILIKE '%' || $3 || '%'
        OR fp.nombre ILIKE '%' || $3 || '%'
        OR ${ESTADO_PAGO_SQL_CASE} ILIKE '%' || $3 || '%'
      )
    GROUP BY fp.nombre
    ORDER BY total DESC
    `,
    [from || null, to || null, q || null]
  );

  const total = Number(rows[0]?.total_count || 0);
  const totalCompletado = Number(rows[0]?.total_completado || 0);
  const items = rows.map(({ total_count, total_completado, ...r }) => r);

  return { rows: conEstadoPago(items), total, totalCompletado, porFormaPago };
}

// Detalle de una autorización: cliente, posición NSX y pagos asociados
async function getAutorizacionDetalle(id) {
  const { rows } = await client.query(
    `
    SELECT
      a.id AS idautorizacion,
      a.id_programacion AS idprogramacion,
      pr.nombre AS producto,
      a.preset AS programacion,
      a.tipo_programacion AS tipoprogramacion,
      p.valor_abonado AS valorabonado,
      a.precio AS precio,
      pos.id_nsx_posicion AS posicionnsx,
      m.numero_manguera AS manguera,
      TO_CHAR(a.fecha_registro, 'YYYY-MM-DD HH24:MI:SS') AS fecharegistro,
      c.identificador,
      c.nombre,
      c.tipo_documento AS tipodocumento,
      c.correo,
      c.placa,
      c.km
    FROM autorizacion a
    LEFT JOIN programacion p ON p.id = a.id_programacion
    LEFT JOIN producto pr ON pr.id = a.id_producto
    LEFT JOIN posicion pos ON pos.id = a.id_posicion
    LEFT JOIN manguera m ON m.id = a.id_manguera
    LEFT JOIN cliente c ON c.id = p.id_cliente
    WHERE a.id = $1
    `,
    [id]
  );

  const autorizacion = rows[0];
  if (!autorizacion) return null;

  return { ...autorizacion, pagos: await getPagosByProgramacion(autorizacion.idprogramacion) };
}

// Detalle de una programación: cliente, posición NSX y pagos intentados (si los hay)
async function getProgramacionDetalle(id) {
  const { rows } = await client.query(
    `
    SELECT
      p.id AS idprogramacion,
      pr.nombre AS producto,
      p.valor_programado AS programacion,
      p.tipo_programacion AS tipoprogramacion,
      p.valor_abonado AS valorabonado,
      p.valor_pendiente AS valorpendiente,
      p.precio AS precio,
      pos.id_nsx_posicion AS posicionnsx,
      m.numero_manguera AS manguera,
      TO_CHAR(p.fecha_registro, 'YYYY-MM-DD HH24:MI:SS') AS fecharegistro,
      c.identificador,
      c.nombre,
      c.tipo_documento AS tipodocumento,
      c.correo,
      c.placa,
      c.km
    FROM programacion p
    LEFT JOIN producto pr ON pr.id = p.id_producto
    LEFT JOIN posicion pos ON pos.id = p.posicion_id
    LEFT JOIN manguera m ON m.id = p.manguera_id
    LEFT JOIN cliente c ON c.id = p.id_cliente
    WHERE p.id = $1
    `,
    [id]
  );

  const programacion = rows[0];
  if (!programacion) return null;

  return { ...programacion, pagos: await getPagosByProgramacion(id) };
}

// Detalle de una venta: cliente, posición NSX y pagos asociados
async function getVentaDetalle(id) {
  const { rows } = await client.query(
    `
    SELECT
      v.id AS idventa,
      a.id AS idautorizacion,
      a.id_programacion AS idprogramacion,
      pr.nombre AS producto,
      a.preset AS programacion,
      a.tipo_programacion AS tipoprogramacion,
      v.dinero,
      v.volumen,
      a.precio,
      pos.id_nsx_posicion AS posicionnsx,
      m.numero_manguera AS manguera,
      TO_CHAR(v.fecha_registro, 'YYYY-MM-DD HH24:MI:SS') AS fecharegistro,
      c.identificador,
      c.nombre,
      c.tipo_documento AS tipodocumento,
      c.correo,
      c.placa,
      c.km
    FROM venta v
    LEFT JOIN autorizacion a ON a.id_venta = v.id_venta_nsx
    LEFT JOIN programacion p ON p.id = a.id_programacion
    LEFT JOIN producto pr ON pr.id = a.id_producto
    LEFT JOIN posicion pos ON pos.id = a.id_posicion
    LEFT JOIN manguera m ON m.id = a.id_manguera
    LEFT JOIN cliente c ON c.id = p.id_cliente
    WHERE v.id = $1
    `,
    [id]
  );

  const venta = rows[0];
  if (!venta) return null;

  return { ...venta, pagos: await getPagosByProgramacion(venta.idprogramacion) };
}

// Anula una autorización pendiente de despacho: sincronizado = -1 evita que el
// proceso de sincronización (que solo toma sincronizado = 0) la reimpulse a NSX.
async function cancelAutorizacion(id) {
  const { rows } = await client.query(
    `UPDATE autorizacion
     SET sincronizado = -1
     WHERE id = $1 AND id_venta IS NULL
     RETURNING id`,
    [id]
  );
  return rows[0] || null;
}

// Aprueba un pago (lo lleva a estado 2 = Completado) sin importar en qué estado esté.
// El trigger de la base (trg_estado_transaccion_pago) solo actúa en la transición
// exacta 4 -> 2: por eso primero se fuerza a 4 y luego a 2, para que la segunda
// actualización sea una transición real que dispare la cascada (abona la
// programación y, si queda pagada, crea la autorización) sin tocar el trigger.
async function approvePago(id) {
  const { rows: current } = await client.query(
    'SELECT id_estado_transaccion FROM transaccion_pago WHERE id = $1',
    [id]
  );
  if (!current[0]) return { notFound: true };
  if (current[0].id_estado_transaccion === 2) return { alreadyApproved: true };

  await client.query('UPDATE transaccion_pago SET id_estado_transaccion = 4 WHERE id = $1', [id]);
  const { rows } = await client.query(
    'UPDATE transaccion_pago SET id_estado_transaccion = 2 WHERE id = $1 RETURNING id',
    [id]
  );
  return { id: rows[0]?.id };
}

async function logAudit({ accion, entidad, idEntidad, idUsuario, usuario, detalle }) {
  await client.query(
    `INSERT INTO auditoria (accion, entidad, id_entidad, id_usuario, usuario, detalle)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [accion, entidad, idEntidad, idUsuario, usuario, detalle]
  );
}

async function getAuditoria() {
  const { rows } = await client.query(`
    SELECT
      id,
      accion,
      entidad,
      id_entidad AS identidad,
      usuario,
      detalle,
      TO_CHAR(fecha_registro, 'YYYY-MM-DD HH24:MI:SS') AS fecharegistro
    FROM auditoria
    ORDER BY fecha_registro DESC
    LIMIT 200
  `);
  return rows;
}

module.exports = {
  login,
  getCatalogos,
  getAutorizaciones,
  getProgramaciones,
  getVentas,
  getAutorizacionDetalle,
  getProgramacionDetalle,
  getVentaDetalle,
  getArqueo,
  getTransferenciaSaldos,
  reimprimirVuelto,
  getReportePagos,
  cancelAutorizacion,
  approvePago,
  logAudit,
  getAuditoria,
};
