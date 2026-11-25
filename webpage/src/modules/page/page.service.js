const repository = require('./page.repository');
const { signSession } = require('../../utils/jwt');

async function authenticate(userName, password) {
  const response = await repository.login(userName, password);
  const body = response.data || {};
  const usuario = body.data || null;

  return {
    success: !!body.success,
    message: body.message,
    usuario,
    token: usuario ? signSession(usuario) : null,
  };
}

const DEFAULT_COLORS = ['#6a11cb', '#2575fc', '#ffcc00'];

// El API entrega los colores en formato ARGB (AARRGGBB); CSS solo necesita RRGGBB.
function argbToRgb(hex) {
  return typeof hex === 'string' && hex.length === 9 ? `#${hex.slice(3)}` : hex;
}

async function getTheme() {
  try {
    const response = await repository.getCatalogos();
    const colores = response.data?.data?.colores;

    if (!Array.isArray(colores) || colores.length < 3) {
      return { colors: DEFAULT_COLORS };
    }

    return { colors: colores.slice(0, 3).map(argbToRgb) };
  } catch (error) {
    return { colors: DEFAULT_COLORS };
  }
}

async function getAutorizaciones() {
  return repository.getAutorizaciones();
}

async function getProgramaciones() {
  return repository.getProgramaciones();
}

async function getVentas() {
  return repository.getVentas();
}

async function getAutorizacionDetalle(id) {
  return repository.getAutorizacionDetalle(id);
}

async function getProgramacionDetalle(id) {
  return repository.getProgramacionDetalle(id);
}

async function getVentaDetalle(id) {
  return repository.getVentaDetalle(id);
}

async function getArqueo() {
  return repository.getArqueo();
}

async function getTransferenciaSaldos() {
  return repository.getTransferenciaSaldos();
}

async function reimprimirVuelto(codigo, user) {
  const result = await repository.reimprimirVuelto(codigo);

  if (result.success) {
    await repository.logAudit({
      accion: 'reimprimir_vuelto',
      entidad: 'vuelto',
      idEntidad: null,
      idUsuario: user?.idUsuario ?? null,
      usuario: user?.userName ?? null,
      detalle: `Vuelto ${codigo} reimpreso`,
    });
  }

  return result;
}

async function getReportePagos(params) {
  return repository.getReportePagos(params);
}

async function cancelAutorizacion(id, user) {
  const cancelada = await repository.cancelAutorizacion(id);

  if (cancelada) {
    await repository.logAudit({
      accion: 'anular_autorizacion',
      entidad: 'autorizacion',
      idEntidad: id,
      idUsuario: user?.idUsuario ?? null,
      usuario: user?.userName ?? null,
      detalle: `Autorización #${id} anulada`,
    });
  }

  return cancelada;
}

async function getAuditoria() {
  return repository.getAuditoria();
}

async function approvePago(id, user) {
  const result = await repository.approvePago(id);

  if (result.id) {
    await repository.logAudit({
      accion: 'aprobar_pago',
      entidad: 'transaccion_pago',
      idEntidad: id,
      idUsuario: user?.idUsuario ?? null,
      usuario: user?.userName ?? null,
      detalle: `Pago #${id} aprobado`,
    });
  }

  return result;
}

module.exports = {
  authenticate,
  getTheme,
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
  getAuditoria,
};
