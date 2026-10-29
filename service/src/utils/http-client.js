const axios = require("axios");
const env = require("../config/env");
const AppError = require("../errors/AppError");
const logger = require("../config/logger");

const buildConfig = (method, endpoint, body, timeoutMs) => ({
  method,
  maxBodyLength: Infinity,
  timeout: timeoutMs || env.httpTimeoutMs,
  url: endpoint,
  headers: {
    "Content-Type": "application/json",
  },
  proxy: false,
  validateStatus: () => true,
  ...(body ? { data: body } : {}),
});

const request = async (method, endpoint, body, timeoutMs) => {
  try {
    return await axios.request(buildConfig(method, endpoint, body, timeoutMs));
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
exports.postJson = (endpoint, body, timeoutMs) => request("post", endpoint, body, timeoutMs);

