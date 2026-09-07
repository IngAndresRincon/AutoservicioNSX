const AppError = require("../../errors/AppError");
const productService = require("../../services/product/service");

exports.product = async (req, res, next) => {
  try {
    const response = await productService.product();

    if (!response.length) {
      throw new AppError("No hay informacion de productos", 404);
    }

    return res.status(200).json({
      isError: false,
      message: "Informacion del conector consultada",
      content: response,
    });
  } catch (error) {
    return next(error);
  }
};

exports.updateProductPrice = async (req, res, next) => {
  try {
    const { nsxId } = req.query;
    const { value } = req.body || {};

    if (!nsxId || Number.isNaN(Number(nsxId))) {
      throw new AppError("El parametro nsxId es obligatorio y debe ser numerico", 400);
    }

    if (value === undefined || Number.isNaN(Number(value))) {
      throw new AppError("El cuerpo debe incluir value con un precio numerico", 400);
    }

    const response = await productService.updateProduct(Number(nsxId), Number(value));
    if (!response) {
      throw new AppError("No hay informacion de producto para actualizar", 404);
    }

    return res.status(200).json({
      isError: false,
      message: "Producto actualizado",
      content: { product: response },
    });
  } catch (error) {
    return next(error);
  }
};
