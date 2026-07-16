const AppError = require("../../errors/AppError");
const nsxService = require("../../services/nsx/services");

exports.printSale = async (req, res, next) => {
  try {
    const { saleId } = req.query;

    if (!saleId || Number.isNaN(Number(saleId))) {
      throw new AppError(
        "El parametro saleId es obligatorio y debe ser numerico",
        400,
      );
    }

    const response = await nsxService.printSale(Number(saleId));
    if (!response) {
      throw new AppError("No hay informacion de venta", 404);
    }

    return res.status(202).json({
      isError: false,
      message: "Solicitud de impresion enviada",
      content: response,
    });
  } catch (error) {
    return next(error);
  }
};

exports.getLastSale = async (req, res, next) => {
  try {
    const { dispenserId, sideId } = req.params;

    if (Number.isNaN(Number(dispenserId)) || Number.isNaN(Number(sideId))) {
      throw new AppError("dispenserId y sideId deben ser numericos", 400);
    }

    const response = await nsxService.getLastSale(
      Number(dispenserId),
      Number(sideId),
    );

    return res.status(200).json({
      isError: false,
      message: "Ultima venta consultada",
      content: response,
    });
  } catch (error) {
    return next(error);
  }
};

exports.getSalebyPresetId = async (req, res, next) => {
  try {
    const { presetId } = req.params;

    if (Number.isNaN(Number(presetId))) {
      throw new AppError("presetId debe ser numerico", 400);
    }

    const response = await nsxService.getSalebyPresetId(Number(presetId));

    return res.status(200).json({
      isError: false,
      message: "Informacion de venta consultada",
      content: response,
    });
  } catch (error) {
    return next(error);
  }
};

exports.generateChange = async (req, res, next) => {
  try {
    const response = await nsxService.generateChange(req.body);

    return res.status(200).json({
      isError: false,
      message: "Informacion de vuelto generada correctamente",
      content: response,
    });
  } catch (error) {
    return next(error);
  }
};

exports.checkChangeCode = async (req, res, next) => {
  try {
    const { code } = req.params;

    if (!code) {
      throw new AppError("El parametro code es obligatorio", 400);
    }

    const response = await nsxService.checkChangeCode(code);
    return res.status(200).json({
      isError: false,
      message: "Informacion del codigo consultada",
      content: response,
    });
  } catch (error) {
    return next(error);
  }
};

exports.registerReturnChange = async (req, res, next) => {
  try {
    const response = await nsxService.registerReturnChange(req.body);

    return res.status(200).json({
      isError: false,
      message: "Informacion del codigo consultada",
      content: response,
    });
  } catch (error) {
    return next(error);
  }
};

exports.validateSeller = async (req, res, next) => {
  try {
    const { document,password } = req.body;

    if (!document || !password) {
      throw new AppError("Los parametros document y password son obligatorios", 400);
    }

    const response = await nsxService.validateSeller(document,password);
    return res.status(200).json({
      isError: false,
      message: "Informacion del vendedor consultada",
      content: response,
    });
  } catch (error) {
    return next(error);
  }
};

exports.getStatusPosition = async (req, res, next) => {
  try {
    const { position} = req.params;

    const response = await nsxService.getStatusPosition(parseInt(position));
    return res.status(200).json({
      isError: false,
      message: "Informacion de posición consultada",
      content: response,
    });
  } catch (error) {
    return next(error);
  }
};


