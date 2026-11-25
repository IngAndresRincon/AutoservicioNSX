const { verifySession } = require('../utils/jwt');

function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;

  if (!token) {
    return res.status(401).json({ success: false, message: 'Sesión requerida' });
  }

  try {
    req.user = verifySession(token);
    next();
  } catch (error) {
    return res.status(401).json({ success: false, message: 'Sesión inválida o expirada' });
  }
}

module.exports = { requireAuth };
