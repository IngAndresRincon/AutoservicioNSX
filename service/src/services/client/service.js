const AppError = require("../../errors/AppError");
const clientRepository = require("../../repositories/client/repository");
const apiNsx = process.env.API_NSX;
const { getJson, postJson } = require("../../utils/http-client");

const { callNsx, getModuleIdentifier } = require("../../utils/nsx-client");

// Codigos de public.estado
const STATE = { CONFIRMED: 2, REJECTED: 3 };
const IDENTIFIER_TYPE = { IBUTTON: 1, KEYBOARD: 2, PLATE: 3 };
const readingPositions = new Set();

const getPosition = async (positionId) => {
  const position = await clientRepository.findPosition(positionId);
  if (!position) {
    throw new AppError("La posicion no existe", 404);
  }
  return position;
};

const assertTypeEnabled = async (type) => {
  if (!(await clientRepository.isIdentifierTypeEnabled(type))) {
    throw new AppError("Tipo de identificador no habilitado en este dispositivo", 400);
  }
};

// La peticion queda abierta hasta que el cliente pase el identificador o se agote timeoutSeconds
exports.readIdentifier = async ({ positionId, type, timeoutSeconds }) => {
  if (type === IDENTIFIER_TYPE.PLATE) {
    throw new AppError("La placa no se lee, se envia al autorizar", 400);
  }
  await assertTypeEnabled(type);

  const position = await getPosition(positionId);
  if (readingPositions.has(positionId)) {
    throw new AppError("Ya hay una lectura en curso en la posicion", 409);
  }

  const seconds = Math.min(Math.max(timeoutSeconds || 30, 5), 120);
  readingPositions.add(positionId);
  try {
    const identifier = await getModuleIdentifier();
    const data = await callNsx(
      "/Cliente/LeerIdentificador",
      { identificador: identifier, idPosicion: position.id_nsx_posicion, tipo: type, timeoutSegundos: seconds },
      (seconds + 10) * 1000,
    );
    return { serial: data.serial };
  } finally {
    readingPositions.delete(positionId);
  }
};

// Con vendedor (token) la venta queda en su turno; sin vendedor, en el turno del autoservicio
exports.authorizeClient = async ({ document, positionId, hoseNumber, programmingType, value, km, identifierType, serial, key }) => {
  await assertTypeEnabled(identifierType);

  const position = await getPosition(positionId);
  const identifier = await getModuleIdentifier();
  const preset = await clientRepository.reservePreset({
    positionId, hoseNumber, programmingType, value, km, identifierType, serial, document,
  });

  try {
    const data = await callNsx("/Cliente/AutorizarCliente", {
      identificador: identifier,
      idPosicion: position.id_nsx_posicion,
      numeroManguera: hoseNumber,
      tipoProgramacion: programmingType,
      valor: value,
      km,
      serial,
      clave: identifierType === IDENTIFIER_TYPE.KEYBOARD ? key : null,
      tipoIdentificador: identifierType,
      documento: document,
    });

    return await clientRepository.updatePreset(preset.id, {
      state: STATE.CONFIRMED,
      nsxPresetId: data.idPreset,
      message: data.mensaje,
    });
  } catch (error) {
    await clientRepository.updatePreset(preset.id, { state: STATE.REJECTED, message: error.message });
    throw error;
  }
};

exports.getClientPreset = async ({ id, document }) => {
  const preset = await clientRepository.getPreset(id);
  if (!preset) {
    throw new AppError("El preset no existe", 404);
  }
  if (preset.documento && preset.documento !== document) {
    throw new AppError("El preset pertenece a otro vendedor", 403);
  }
  return preset;
};

exports.clientValidation = async (params) => {
  return clientRepository.clientValidation(params);
};

exports.clientValidationDian = async (identifier) => {
  const endpoint = `${apiNsx}/Facturacion/ConsultarCliente?documento=${identifier}`;
  const response = await getJson(endpoint);

  if (response?.status !== 200 || !response.data?.data) {
    throw new AppError("No fue posible consultar el cliente en NSX", 502, {
      details: response?.data,
    });
  }

  return clientRepository.clientValidationDian(response.data.data);
};

exports.additionalInformation = async (params) => {
  return clientRepository.additionalInformation(params);
};

exports.post = async (endpoint, body) => {
  return postJson(endpoint, body);
};

exports.get = async (endpoint) => {
  return getJson(endpoint);
};

