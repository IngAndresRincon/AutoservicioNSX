const env = require("../config/env");

function validarApiKey(req, res, next) {
  const apiKey = req.headers["x-api-key"];

  if (!apiKey) {
    return res.status(401).json({ error: "API Key requerida" });
  }

  if (!env.apiKeys.includes(apiKey.trim())) {
    return res.status(403).json({ error: "API Key invalida" });
  }

  next();
}

module.exports = validarApiKey;

