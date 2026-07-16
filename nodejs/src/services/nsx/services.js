const AppError = require("../../errors/AppError");
const apiNsx = process.env.API_NSX;
const nsxRepository = require("../../repositories/nsx/repository");
const { getJson, postJson } = require("../../utils/http-client");

const ensureResponseOk = (response, fallbackMessage) => {
  if (!response) {
    throw new AppError("Servidor destino no responde", 502);
  }

  if (response.status !== 200) {
    throw new AppError(
      fallbackMessage,
      502,
      { details: response.data }
    );
  }

  return response.data;
};

exports.printSale = async (saleId) => {
  const endpoint = `${apiNsx}/Impresion/ImprimirVenta?idVenta=${saleId}`;
  const response = await getJson(endpoint);
  return response?.status === 200;
};

exports.getLastSale = async (dispenserId, sideId) => {
  const endpoint = `${apiNsx}/Venta/ultima?dispensador=${dispenserId}&cara=${sideId}`;
  const response = await getJson(endpoint);
  return ensureResponseOk(response, "No hay informacion encontrada para la solicitud");
};

exports.getSalebyPresetId = async (presetId) => {
  const endpoint = `${apiNsx}/Venta/preset/${presetId}`;
  const response = await getJson(endpoint);
  return ensureResponseOk(response, "No hay informacion encontrada para la solicitud");
};

exports.checkChangeCode = async (code) => {
  const endpoint = `${apiNsx}/Vueltos/ConsultarVueltos?codigo=${code}`;
  const response = await getJson(endpoint);
  return ensureResponseOk(response, "No hay informacion encontrada para la solicitud");
};

exports.generateChange = async (request) => {
  const existPreset = await nsxRepository.validPresetId(request.presetId);
  if (!existPreset) {
    throw new AppError("El valor de preset id no existe", 404);
  }

  const methodPayment = await nsxRepository.getMethodPayment(request.methodPaymentId);
  if(!methodPayment){
    throw new AppError("No hay información del método de pago asociado", 404);
  }

  if(methodPayment.id_nsx_forma_pago === 25){
    const result = await nsxRepository.saveRecordReturnBalanceNequi(existPreset.id,request);
    return result;
  }

  const endpoint = `${apiNsx}/Vueltos/GenerarVuelto`;
  const body = {
    idPreset: request.presetId,
    valor: request.amount,
    idFormaPago: request.methodPaymentId,
  };

  const response = await postJson(endpoint, body);
  return ensureResponseOk(response, "No hay informacion encontrada para la solicitud");
};

exports.registerReturnChange = async (request) => {
  const endpoint = `${apiNsx}/Vueltos/RegistrarVuelto`;
  const body = {
    codigo: request.code,
    valor: request.amount,
    idDisPosProgramacion: request.programmingpositionId,
    fechaCreacion: request.creationdate,
    fechaUso: request.dateofuse,
    idFormaPago: request.methodpaymentId,
  };

  const response = await postJson(endpoint, body);
  return ensureResponseOk(response, "No hay informacion encontrada para la solicitud");
};

exports.validateSeller = async (document,pass) => {
  const endpoint = `${apiNsx}/Turno/ValidarVendedor`;
  const body = {
    documento: document,
    password: pass
  };
  const response = await postJson(endpoint, body);
  return ensureResponseOk(response, "No hay informacion encontrada para la solicitud");
};


exports.getStatusPosition = async (position) => {
  const endpoint = `${apiNsx}/Preset/ObtenerEstado?idPosicion=${position}`;
  const response = await getJson(endpoint);
  return ensureResponseOk(response, "No hay informacion encontrada para la solicitud");
};
