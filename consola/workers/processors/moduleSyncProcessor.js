const service = require("../../services/moduleSyncService");
const logger = require("../../utils/logger");

async function processModuleSync() {
  const startTime = Date.now();
  try {
    const response = await service.consultSyncRequest();
    if (response) {
      await service.syncModule();
      const duration = Date.now() - startTime;
      logger.info(`Sincronización de módulo completada en ${duration}ms`);
      return true;
    }
    return false;
  } catch (error) {
    logger.error(`Error al sincronizar módulo: ${error.message}`);
    return false;
  }
}

module.exports = {
  processModuleSync,
};
