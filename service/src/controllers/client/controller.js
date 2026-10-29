const AppError = require("../../errors/AppError");
const clientService = require("../../services/client/service");

exports.clientValidation = async (req, res, next) => {
  try {
    const { identifier, cf_client } = req.body;

    if (!identifier && !cf_client) {
      throw new AppError("El campo identifier es obligatorio", 400);
    }

    const response = await clientService.clientValidation(req.body);
    if (!response) {
      throw new AppError("Error validando informacion del cliente", 404);
    }

    return res.status(200).json({
      isError: false,
      message: "Id de cliente",
      content: { clientId: response },
    });
  } catch (error) {
    return next(error);
  }
};

exports.clienteValidationDian = async (req, res, next) => {
  try {
    const { identifier } = req.query;

    if (!identifier) {
      throw new AppError("El parametro identifier es obligatorio", 400);
    }

    const response = await clientService.clientValidationDian(identifier);
    if (!response) {
      throw new AppError("Error validando informacion del cliente", 404);
    }

    return res.status(200).json({
      isError: false,
      message: "Id de cliente",
      content: { clientId: response },
    });
  } catch (error) {
    return next(error);
  }
};

exports.additionalInformation = async (req, res, next) => {
  try {
    const { clientId, licensePlate, km } = req.body;

    if (
      !clientId ||
      licensePlate === undefined ||
      km === undefined ||
      Number.isNaN(Number(clientId)) ||
      Number.isNaN(Number(km))
    ) {
      throw new AppError("clientId, licensePlate y km son obligatorios", 400);
    }

    const response = await clientService.additionalInformation({
      clientId: Number(clientId),
      licensePlate,
      km: Number(km),
    });

    if (!response) {
      throw new AppError("Error actualizando informacion adicional", 404);
    }

    return res.status(200).json({
      isError: false,
      message: "Informacion adicional actualizada",
      content: { information: response },
    });
  } catch (error) {
    return next(error);
  }
};

const isNumber = (value) => value !== undefined && value !== null && value !== "" && !Number.isNaN(Number(value));

const requireNumbers = (body, fields) => {
  const invalid = fields.find((field) => !isNumber(body[field]));
  if (invalid) {
    throw new AppError(`El campo ${invalid} es obligatorio y debe ser numerico`, 400);
  }
};

exports.readIdentifier = async (req, res, next) => {
  try {
    requireNumbers(req.body, ["positionId", "type"]);

    const content = await clientService.readIdentifier({
      positionId: Number(req.body.positionId),
      type: Number(req.body.type),
      timeoutSeconds: isNumber(req.body.timeoutSeconds) ? Number(req.body.timeoutSeconds) : undefined,
    });
    return res.status(200).json({ isError: false, message: "Identificador leido", content });
  } catch (error) {
    return next(error);
  }
};

exports.authorizeClient = async (req, res, next) => {
  try {
    const body = req.body;
    requireNumbers(body, ["positionId", "hoseNumber", "programmingType", "identifierType"]);

    const programmingType = Number(body.programmingType);
    const identifierType = Number(body.identifierType);
    if (![1, 2, 3].includes(programmingType)) {
      throw new AppError("programmingType debe ser 1 (lleno), 2 (dinero) o 3 (volumen)", 400);
    }
    if (![1, 2, 3].includes(identifierType)) {
      throw new AppError("identifierType debe ser 1 (iButton), 2 (teclado) o 3 (placa)", 400);
    }
    if (programmingType !== 1) {
      requireNumbers(body, ["value"]);
    }
    if (!body.serial) {
      throw new AppError("El campo serial es obligatorio", 400);
    }
    if (identifierType === 2 && !body.key) {
      throw new AppError("El campo key es obligatorio para el teclado", 400);
    }

    const content = await clientService.authorizeClient({
      document: req.seller ? req.seller.document : null,
      positionId: Number(body.positionId),
      hoseNumber: Number(body.hoseNumber),
      programmingType,
      value: programmingType === 1 ? 0 : Number(body.value),
      km: isNumber(body.km) ? Math.round(Number(body.km)) : null,
      identifierType,
      serial: String(body.serial),
      key: body.key ? String(body.key) : null,
    });
    return res.status(201).json({ isError: false, message: "Cliente autorizado", content });
  } catch (error) {
    return next(error);
  }
};

exports.getClientPreset = async (req, res, next) => {
  try {
    requireNumbers(req.params, ["id"]);

    const content = await clientService.getClientPreset({
      id: Number(req.params.id),
      document: req.seller ? req.seller.document : null,
    });
    return res.status(200).json({ isError: false, message: "Preset del cliente consultado", content });
  } catch (error) {
    return next(error);
  }
};
