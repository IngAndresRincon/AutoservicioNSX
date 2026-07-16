const axios = require("axios");
const logger = require("../utils/logger");

exports.requestNsx = async (method, endpoint, body, retries = 3) => {
  let response = undefined;
  logger.info(`Solicitud ${method.toUpperCase()} a servicio: ${endpoint}`);
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const config = {
        method,
        maxBodyLength: Infinity,
        timeout: 20000,
        url: endpoint,
        headers: {
          "Content-Type": "application/json",
        },
        validateStatus: function (status) {
          return true;
        },
      };

      if (method === "post") {
        config.data = body;
      }

      response = await axios.request(config);
      logger.info(
        `Respuesta ${method.toUpperCase()}: ${JSON.stringify(response.data)}`,
      );
      return response;
    } catch (error) {
      logger.error(
        `Intento ${attempt} fallido para ${method.toUpperCase()} ${endpoint}: ${error.message}`,
      );
      if (attempt === retries) {
        throw error;
      }
      await new Promise((res) => setTimeout(res, 1000 * attempt));
    }
  }
};
