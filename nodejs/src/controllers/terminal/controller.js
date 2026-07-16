const AppError = require("../../errors/AppError");
const serviceSystem = require("../../services/terminal/services");

exports.synchronizeTerminal = async (req, res, next) => {
  try {
    const { serial, ip } = req.query;

    if (!serial || !ip) {
      throw new AppError("Los parametros serial e ip son obligatorios", 400);
    }

    const response = await serviceSystem.synchronizeTerminal({ serial, ip });
    if (!response) {
      throw new AppError("No se pudo sincronizar el terminal", 404);
    }

    return res.status(200).json({
      isError: false,
      message: "Terminal sincronizado correctamente",
      content: { terminal: response },
    });
  } catch (error) {
    return next(error);
  }
};
