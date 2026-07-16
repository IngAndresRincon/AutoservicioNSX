const jwt = require("jsonwebtoken");
const { v4: uuidv4 } = require("uuid");

function generarJWT(user) {
  const payload = {
    sub: user.id,
    role: "user",
    identifier: user.correo,
  };

  return jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: "1h",
  });
}

function refreshToken(user) {
  const payload = {
    userId: user.id,
    tokenId: uuidv4(),
  };

  return jwt.sign(payload, process.env.REFRESH_SECRET, { expiresIn: "30d" });
}

module.exports = { generarJWT, refreshToken };
