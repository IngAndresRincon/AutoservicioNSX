const AppError = require("../errors/AppError");

module.exports = (error, req, res, next) => {
  if (res.headersSent) {
    return next(error);
  }

  const normalizedError = error instanceof AppError ? error : new AppError(error.message || "Error interno del servidor");

  return res.status(normalizedError.statusCode || 500).json({
    isError: true,
    message: normalizedError.expose ? normalizedError.message : "Error interno del servidor",
    details: normalizedError.details,
  });
};

