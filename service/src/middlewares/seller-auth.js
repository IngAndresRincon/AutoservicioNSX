const jwt = require("jsonwebtoken");
const env = require("../config/env");
const AppError = require("../errors/AppError");

const readToken = (req) => {
  const header = req.headers["authorization"] || "";
  return header.startsWith("Bearer ") ? header.slice(7).trim() : header.trim();
};

// Verifica el token del vendedor y deja req.seller; devuelve un AppError si no es valido
const verify = (req, token) => {
  try {
    const payload = jwt.verify(token, env.jwtSecret);
    if (payload.role !== "seller") {
      return new AppError("El token no es de vendedor", 403);
    }

    req.seller = payload;
    return null;
  } catch (error) {
    if (error.name === "TokenExpiredError") {
      return new AppError("La sesion del vendedor expiro, inicie sesion de nuevo", 401);
    }
    return new AppError("Token de vendedor invalido", 403);
  }
};

// Token del vendedor: "Authorization: Bearer <token>". El documento sale del token, no del cuerpo.
function validarVendedor(req, res, next) {
  const token = readToken(req);
  if (!token) {
    return next(new AppError("Token de vendedor requerido", 401));
  }

  return next(verify(req, token) || undefined);
}

// Igual, pero sin token deja pasar (cliente solo); con token invalido o vencido responde el error
validarVendedor.optional = (req, res, next) => {
  const token = readToken(req);
  if (!token) {
    return next();
  }

  return next(verify(req, token) || undefined);
};

module.exports = validarVendedor;
