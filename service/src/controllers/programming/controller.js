const AppError = require("../../errors/AppError");
const programmingService = require("../../services/programming/service");

exports.createProgramming = async (req, res, next) => {
  try {
    const body = req.body;
    const requiredNumericFields = ["clientId", "positionId", "hoseId", "programmingValue", "programmingType", "price", "productId"];
    const hasInvalidNumericField = requiredNumericFields.some(
      (field) => body[field] === undefined || Number.isNaN(Number(body[field]))
    );

    if (hasInvalidNumericField) {
      throw new AppError("clientId, positionId, hoseId, programmingValue, programmingType, price y productId son obligatorios y numericos", 400);
    }

    const response = await programmingService.createprogramming({
      clientId: Number(body.clientId),
      positionId: Number(body.positionId),
      hoseId: Number(body.hoseId),
      programmingValue: Number(body.programmingValue),
      programmingType: Number(body.programmingType),
      price: Number(body.price),
      productId: Number(body.productId),
    });

    if (!response) {
      throw new AppError("No se pudo crear la programacion", 400);
    }

    return res.status(response.idRecovered ? 200 : 201).json({
      isError: false,
      message: "Programacion registrada",
      content: response,
    });
  } catch (error) {
    return next(error);
  }
};

exports.createPayment = async (req, res, next) => {
  try {
    const body = req.body;
    const requiredNumericFields = ["programmingId", "amounttopay", "paymentmethodId",];
    const hasInvalidNumericField = requiredNumericFields.some(
      (field) => body[field] === undefined || Number.isNaN(Number(body[field]))
    );

    if (hasInvalidNumericField) {
      throw new AppError("programmingId, amounttopay y paymentmethodId son obligatorios y numericos", 400);
    }

    const response = await programmingService.createPayment({
      programmingId: Number(body.programmingId),
      amounttopay: Number(body.amounttopay),
      paymentmethodId: Number(body.paymentmethodId),
      ref: body.reference
    });

    if (!response) {
      throw new AppError("No se pudo crear el pago", 404);
    }

    return res.status(201).json({
      isError: false,
      message: "Informacion del pago registrada",
      content: { payment: response },
    });
  } catch (error) {
    return next(error);
  }
};

exports.pendingProgramming = async (req, res, next) => {
  try {
    const { userId } = req.query;

    if (!userId || Number.isNaN(Number(userId))) {
      throw new AppError("El parametro userId es obligatorio y debe ser numerico", 400);
    }

    const response = await programmingService.pendingProgramming(Number(userId));
    if (!response) {
      throw new AppError("No se encontraron programaciones pendientes para el usuario", 204); // La petición se procesó correctamente pero no hay contenido que retornar
    }

    return res.status(200).json({
      isError: false,
      message: "Informacion de la programacion",
      content: { programming: response },
    });
  } catch (error) {
    return next(error);
  }
};

exports.pendingAuthorization = async (req, res, next) => {
  try {
    const { userId } = req.query;

    if (!userId || Number.isNaN(Number(userId))) {
      throw new AppError("El parametro userId es obligatorio y debe ser numerico", 400);
    }

    const response = await programmingService.pendingAuthorization(Number(userId));
    if (!response) {
      throw new AppError("No se encontraron autorizaciones pendientes para el usuario", 204);
    }

    return res.status(200).json({
      isError: false,
      message: "Informacion de la autorizacion",
      content: { authorization: response },
    });
  } catch (error) {
    return next(error);
  }
};


exports.resendAuthorization = async (req, res, next) => {
  try {
    const { authorizationId } = req.query;

    if (!authorizationId || Number.isNaN(Number(authorizationId))) {
      throw new AppError("El parametro authorizationId es obligatorio y debe ser numerico", 400);
    }

    const response = await programmingService.resendAuthorization(Number(authorizationId));
    if (!response) {
      throw new AppError("Error re impulsando la autorizacion, no se encontro el registro o no se pudo actualizar", 404);
    }

    return res.status(200).json({
      isError: false,
      message: "Autorizacion re impulsada exitosamente",
    });
  } catch (error) {
    return next(error);
  }
};


exports.authorizeProgramming = async (req, res, next) => {
  try {
    const { clientId, programmingId } = req.params;

    if (!clientId || Number.isNaN(Number(clientId))) {
      throw new AppError("El parametro clientId es obligatorio y debe ser numerico", 400);
    }

    if (!programmingId || Number.isNaN(Number(programmingId))) {
      throw new AppError("El parametro programmingId es obligatorio y debe ser numerico", 400);
    }

    const response = await programmingService.authorizeProgramming(Number(clientId), Number(programmingId));
    if (!response) {
      throw new AppError("Error autorizando la programacion, no se encontro el registro o no se pudo actualizar", 404);
    }

    return res.status(200).json({
      isError: false,
      message: "Programacion autorizada exitosamente",
      content: { programming: response },
    });
  } catch (error) {
    return next(error);
  }
};


