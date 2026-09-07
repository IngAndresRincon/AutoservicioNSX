const jwt = require("jsonwebtoken");

function generarJWT(mod) {
  const payload = {
    sub: mod[0].idestacion,
    role: "module",
    identifier: mod[0].serialmodulo,
  };

  return jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: "30d",
  });
}

module.exports = generarJWT;
