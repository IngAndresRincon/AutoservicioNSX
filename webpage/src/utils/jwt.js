const jwt = require('jsonwebtoken');
const { env } = require('../config/env');

function signSession(usuario) {
  return jwt.sign(
    { idUsuario: usuario.idUsuario, userName: usuario.userName, nombres: usuario.nombres },
    env.jwtSecret,
    { expiresIn: '8h' }
  );
}

function verifySession(token) {
  return jwt.verify(token, env.jwtSecret);
}

module.exports = { signSession, verifySession };
