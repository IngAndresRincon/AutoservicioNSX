const AppError = require("../../errors/AppError");
const env = require("../../config/env");
const sellerRepository = require("../../repositories/seller/repository");
const { callNsx, getModuleIdentifier } = require("../../utils/nsx-client");
const { getJson } = require("../../utils/http-client");
const { generarJWTSeller } = require("../../utils/jwt/generarJWTSeller");

// Codigos de public.estado
const STATE = { CONFIRMED: 2, REJECTED: 3, CANCELLED: 5 };

const failedLogins = new Map();

const getHybridPosition = async (positionId) => {
  const position = await sellerRepository.findPosition(positionId);
  if (!position) {
    throw new AppError("La posicion no existe", 404);
  }
  if (!position.hibrido) {
    throw new AppError("El dispensador de la posicion no es hibrido", 403);
  }
  return position;
};

const registerFailedLogin = (document) => {
  const now = Date.now();
  const entry = failedLogins.get(document);
  const current = entry && now - entry.first < env.sellerLoginWindowMs ? entry : { count: 0, first: now };
  current.count += 1;
  failedLogins.set(document, current);
};

const assertLoginAllowed = (document) => {
  const entry = failedLogins.get(document);
  if (entry && Date.now() - entry.first < env.sellerLoginWindowMs && entry.count >= env.sellerLoginMaxAttempts) {
    throw new AppError("Demasiados intentos fallidos, intente de nuevo en unos minutos", 429);
  }
};

exports.login = async ({ document, password }) => {
  assertLoginAllowed(document);

  let seller;
  try {
    seller = await callNsx("/Turno/ValidarVendedor", { documento: document, password });
  } catch (error) {
    if (error.statusCode === 401) {
      registerFailedLogin(document);
    }
    throw error;
  }

  if (!seller.activo) {
    throw new AppError("El vendedor esta inactivo", 403);
  }

  failedLogins.delete(document);
  const name = `${seller.nombre} ${seller.apellidos}`.trim();
  const token = generarJWTSeller({ document: seller.cedula, sellerId: seller.idIslero, name });

  // Si ya tiene turno abierto en NSX se toma tal cual (en cualquier equipo) y la app no lo pide de nuevo
  const nsxShiftId = Number(seller.idTurnoAbierto) || 0;
  await sellerRepository.syncSellerShift({ document: seller.cedula, nsxShiftId });

  return {
    token,
    expiresInHours: env.sellerTokenHours,
    seller: { sellerId: seller.idIslero, document: seller.cedula, name },
    shift: nsxShiftId > 0 ? { nsxShiftId } : null,
  };
};

const shift = (path) => async ({ document, password, positionId }) => {
  const position = await getHybridPosition(positionId);
  const identifier = await getModuleIdentifier();

  const result = await callNsx(path, {
    identificador: identifier,
    idPosicion: position.id_nsx_posicion,
    documento: document,
    password,
  });

  return { position, result };
};

exports.openShift = async (params) => {
  const { position, result } = await shift("/Turno/AbrirTurno")(params);
  await sellerRepository.openSellerShift({
    document: params.document,
    nsxShiftId: result.idTurno,
    positionId: position.id,
  });
  return result;
};

exports.closeShift = async (params) => {
  const { result } = await shift("/Turno/CerrarTurno")(params);
  await sellerRepository.closeSellerShift(params.document);
  return result;
};

exports.createPreset = async ({ document, positionId, hoseNumber, programmingType, value, plate, km }) => {
  const position = await getHybridPosition(positionId);
  const identifier = await getModuleIdentifier();

  const preset = await sellerRepository.reservePreset({ document, positionId, hoseNumber, programmingType, value, plate, km });

  try {
    const result = await callNsx("/Preset/PresetVendedor", {
      identificador: identifier,
      documento: document,
      idPosicion: position.id_nsx_posicion,
      numeroManguera: hoseNumber,
      tipoProgramacion: programmingType,
      valor: value,
      placa: plate,
      km,
    });

    return await sellerRepository.updatePreset(preset.id, { state: STATE.CONFIRMED, nsxPresetId: result.idPreset });
  } catch (error) {
    await sellerRepository.updatePreset(preset.id, { state: STATE.REJECTED, message: error.message });
    throw error;
  }
};

exports.cancelPreset = async ({ document, positionId }) => {
  const position = await getHybridPosition(positionId);
  const identifier = await getModuleIdentifier();

  const preset = await sellerRepository.findCancelablePreset(document, positionId);
  if (!preset) {
    throw new AppError("No hay un preset del vendedor para cancelar en la posicion", 404);
  }

  await callNsx("/Preset/CancelarPreset", {
    identificador: identifier,
    documento: document,
    idPosicion: position.id_nsx_posicion,
  });

  return sellerRepository.updatePreset(preset.id, { state: STATE.CANCELLED });
};

exports.getPreset = async ({ id, document }) => {
  const preset = await sellerRepository.getPreset(id, document);
  if (!preset) {
    throw new AppError("El preset no existe para este vendedor", 404);
  }
  return withPump(preset);
};

// Con el preset vivo se agrega el grado preset y el grado levantado, para avisar si no coinciden
const withPump = async (preset) => {
  if (![STATE.CONFIRMED, 8].includes(preset.sincronizado)) {
    return preset;
  }

  try {
    const position = await sellerRepository.findPosition(preset.id_posicion);
    const response = await getJson(`${env.apiNsx}/Preset/ObtenerEstado?idPosicion=${position.id_nsx_posicion}`);
    const pump = response?.data?.data;
    if (pump) {
      return { ...preset, bomba: { estado: pump.estadoSurtidor, gradoReal: pump.grado, gradoPreset: pump.gradoPreset } };
    }
  } catch (error) {
    // Es informativo: si falla, el preset se devuelve sin estos datos
  }
  return preset;
};

exports.payments = async ({ document, saleId, paymentMethods }) => {
  const allowed = await sellerRepository.findSellerPaymentMethods(paymentMethods.map((item) => item.paymentMethodId));
  const notAllowed = paymentMethods.find((item) => !allowed.includes(item.paymentMethodId));
  if (notAllowed) {
    throw new AppError(`La forma de pago ${notAllowed.paymentMethodId} no esta habilitada para el vendedor`, 400);
  }

  const preset = await sellerRepository.findPresetBySale(saleId, document);
  if (!preset) {
    throw new AppError("La venta no corresponde a un preset de este vendedor", 404);
  }

  const result = await callNsx("/Venta/AnclarFormaPago", {
    documento: document,
    idVenta: saleId,
    formasPago: paymentMethods.map((item) => ({
      idFormaPago: item.paymentMethodId,
      valor: item.amount,
      identificador: item.reference,
    })),
  });

  await sellerRepository.insertPayments(preset.id, saleId, paymentMethods);
  return result;
};

exports.shiftSales = async ({ document }) => {
  const rows = await sellerRepository.shiftSales(document);
  return rows.map((row) => ({
    presetId: row.preset_id,
    saleId: row.sale_id,
    presetNsxId: row.preset_nsx_id,
    nsxPositionId: row.nsx_position_id,
    hoseNumber: row.hose_number,
    type: row.type,
    value: Number(row.value),
    date: row.date,
    paid: Number(row.paid),
    invoiced: row.invoiced,
    credit: row.credit,
  }));
};

// status: free | autoservice | seller | client; own indica que el despacho es del vendedor que consulta
exports.positions = async ({ screenId, document }) => {
  const rows = await sellerRepository.positionsStatus(screenId);
  return rows.map((row) => ({
    positionId: row.positionid,
    nsxPositionId: row.nsxpositionid,
    status: row.origen === "autoservicio" ? "autoservice" : row.origen === "vendedor" ? "seller" : row.origen === "cliente" ? "client" : "free",
    own: row.document != null && row.document === document,
    presetId: row.presetid ?? null,
    sync: row.sync ?? null,
    value: row.value != null ? Number(row.value) : null,
  }));
};
