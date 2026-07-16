const AppError = require("../../errors/AppError");
const saleService = require("../../services/sale/service");

exports.sale = async (req, res, next) => {
  try {
    const { authorizationId } = req.query;

    if (!authorizationId || Number.isNaN(Number(authorizationId))) {
      throw new AppError("El parametro authorizationId es obligatorio y debe ser numerico", 400);
    }

    const response = await saleService.sale({ authorizationId: Number(authorizationId) });

    return res.status(parseInt(response.status)).json({
      isError: false,
      message: "Datos de venta",
      content: response.data,
    });
  } catch (error) {
    return next(error);
  }
};

exports.bill = async (req, res, next) => {
  try {
    const bill = req.body;
    const requiredFields = ["saleId", "documentNumber", "documentType", "companyName", "email"];
    const missingField = requiredFields.find((field) => bill[field] === undefined || bill[field] === null || bill[field] === "");

    if (missingField) {
      throw new AppError(`El campo ${missingField} es obligatorio`, 400);
    }

    const response = await saleService.bill(bill);
    const statusCode = parseInt(response.status);

    return res.status(statusCode).json({
      isError: statusCode !== 200,
      message: "Informacion de factura",
      content: response.data,
    });
  } catch (error) {
    return next(error);
  }
};
