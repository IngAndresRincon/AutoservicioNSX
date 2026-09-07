const axios = require("axios");
const env = require("../config/env");
const AppError = require("../errors/AppError");
const logger = require("../config/logger");

const buildConfig = (method, endpoint, body) => ({
  method,
  maxBodyLength: Infinity,
  timeout: env.httpTimeoutMs,
  url: endpoint,
  headers: {
    "Content-Type": "application/json",
  },
  proxy: false,
  validateStatus: () => true,
  ...(body ? { data: body } : {}),
});

const request = async (method, endpoint, body) => {
  try {
    return await axios.request(buildConfig(method, endpoint, body));
  } catch (error) {
    const message = error.response
      ? `HTTP ${error.response.status} en ${endpoint}`
      : `No fue posible conectar con ${endpoint}: ${error.message}`;
    logger.error("Error en cliente HTTP", {
      endpoint,
      method,
      message: error.message,
      status: error.response?.status,
    });

    throw new AppError(message, 502, {
      details: error.response?.data || error.message,
    });
  }
};

exports.getJson = (endpoint) => request("get", endpoint);
exports.postJson = (endpoint, body) => request("post", endpoint, body);

