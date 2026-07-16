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
