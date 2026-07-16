const jwt = require("jsonwebtoken");
const env = require("../config/env");
const AppError = require("../errors/AppError");

function validarJWT(req, res, next) {
  const token = req.headers["authorization"];

  if (!token) {
    return next(new AppError("Token requerido", 401));
  }

  try {
    req.user = jwt.verify(token, env.jwtSecret);
    return next();
  } catch (error) {
    return next(new AppError("Token invalido o expirado", 403, { details: error.message }));
  }
}

module.exports = validarJWT;

