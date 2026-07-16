const service = require("../../services/pendingAuthorizationService");
const logger = require("../../utils/logger");

async function processPendingAuthorization() {
  const startTime = Date.now();
  try {
    const response = await service.getPendingAuthorization();

    if(response){
      await service.syncAuthorizationNSX(response);
    }
    const duration = Date.now() - startTime;
    logger.info(`Procesamiento de autorizaciones completado en ${duration}ms`);
    return true;
  } catch (error) {
    logger.error(
      `Error al obtener las programaciones pendientes de autorizacion: ${error.message}`,
    );
    return false;
  }
}

module.exports = {
  processPendingAuthorization,
};
