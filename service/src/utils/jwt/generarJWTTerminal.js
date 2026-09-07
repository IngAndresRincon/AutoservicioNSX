const jwt = require("jsonwebtoken");

function generarJWT(terminal) {
  const payload = {
    sub: terminal.key,
    role: "terminal",
    identifier: terminal.serial,
  };

  return jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: "30d",
  });
}

module.exports = generarJWT;
