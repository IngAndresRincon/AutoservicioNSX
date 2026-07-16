const service = require("../../services/saleAuthorizationService");
const repository = require("../../repositories/saleAuthorizationRepository");
const logger = require("../../utils/logger");

const saleAuthorization = [];

async function processSaleAuthorizationQueue({
  limitCounter = 40,
  retryDelayMs = 500,
  loopDelayMs = 3000,
} = {}) {
  const startTime = Date.now();
  let processed = 0;

  while (saleAuthorization.length > 0) {
    for (let i = saleAuthorization.length - 1; i >= 0; i--) {
      const item = saleAuthorization[i];
      let sync = false;

      try {
        const response = await service.getSaleAuthorizationState(
          item.data.id_presetnsx,
        );

        if (response.status !== 200) {
          sync = await repository.markSaleAuthorizationAsFailed(item.data.id);
        } else {
          const responseData = response.data?.data;

          if (responseData?.venta != null) {
            sync = await repository.registerSaleAuthorization(
              item.data,
              responseData.venta,
            );
          } else if (responseData?.ventaZero) {
            sync = await repository.markSaleAuthorizationAsVentaZero(
              item.data.id,
            );
          } else if (
            responseData?.estadoSurtidor &&
            responseData.estadoSurtidor.toString().toUpperCase() === "SURTIENDO"
          ) {
            sync = await repository.reportStatusWhileSupplying(item.data.id);
          }
        }
      } catch (error) {
        logger.error(
          `Error al sincronizar venta ${item.data.id}: ${error.message}`,
        );
      }

      if (sync) {
        saleAuthorization.splice(i, 1);
        processed++;
        continue;
      }

      if (saleAuthorization[i] && saleAuthorization[i].counter == limitCounter) {
        logger.warn(
          `Autorizacion de venta ${saleAuthorization[i].data.id} eliminada por limite de reintentos`,
        );
        await repository.markSaleAuthorizationAsFailed(saleAuthorization[i].data.id);
        saleAuthorization.splice(i, 1);
        continue;
      }

      if (saleAuthorization[i]) {
        saleAuthorization[i].counter++;
      }

      await sleep(retryDelayMs);
    }
  }

  const duration = Date.now() - startTime;
  if (processed > 0) {
    logger.info(`Sincronizacion de ventas: ${processed} procesadas en ${duration}ms`);
  }
  await sleep(loopDelayMs);
  return processed > 0;
}

async function processPendingSaleAuthorization() {
  const startTime = Date.now();
  try {
    const response = await service.getPendingSaleAuthorization();
    if (response.length > 0) {
      response.forEach((item) => {
        const exist = saleAuthorization.some((e) => e.data.id === item.id);
        if (!exist) {
          saleAuthorization.unshift({ data: item, counter: 0 });
        }
      });
      logger.info(`Agregadas ${response.length} autorizaciones de venta pendientes`);
    }

    const duration = Date.now() - startTime;
    logger.info(`Procesamiento de autorizaciones de venta completado en ${duration}ms`);
    return true;
  } catch (error) {
    logger.error(
      `Error al obtener las autorizaciones de venta pendientes: ${error.message}`,
    );
    return false;
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

module.exports = {
  processPendingSaleAuthorization,
  processSaleAuthorizationQueue,
};
