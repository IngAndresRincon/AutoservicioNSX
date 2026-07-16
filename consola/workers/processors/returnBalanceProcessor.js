const service = require("../../services/returnBalanceService");
const repository = require("../../repositories/returnBalanceRepository");
const logger = require("../../utils/logger");

function buildReturnBalanceBody(item) {
  const now = new Date().toISOString();

  return {
    codigo: `${item.contacto}|${item.respuesta}`,
    valor: item.monto ?? 0,
    idDisPosProgramacion: item.id_presetnsx,
    fechaCreacion: item.fecharegistro,
    fechaUso: now,
    idFormaPago: item.id_forma_pago,
  };
}

async function processReturnBalance() {
  const startTime = Date.now();
  try {
    const pending = await service.getPendingReturnBalance();

    if (pending.length === 0) {
      const duration = Date.now() - startTime;
      logger.info(`Sin devoluciones de saldo pendientes en ${duration}ms`);
      return false;
    }

    logger.info(`Encontradas ${pending.length} devoluciones de saldo pendientes`);

    for (const item of pending) {
      const body = buildReturnBalanceBody(item);

      try {
        const response = await service.registerReturnBalanceNSX(body);
        if(response == undefined) return;
        console.log(response.data??'No hay respuestas del servidor NSX');
        if (response.status === 200) {
          await repository.updateReturnBalanceState(item.id, 4, JSON.stringify(response.data));
          logger.info(`Devolución de saldo ${item.id} enviada correctamente`);
        } else {
          await repository.updateReturnBalanceState(item.id, 5,JSON.stringify(response.data));
          logger.warn(
            `Devolución de saldo ${item.id} no fue aceptada por NSX. Status: ${response.status}`,
          );
        }
      } catch (error) {
        logger.error(
          `Error al sincronizar devolución de saldo ${item.id}: ${error.message}`,
        );
        await repository.updateReturnBalanceState(item.id, 3);
      }
    }

    const duration = Date.now() - startTime;
    logger.info(`Procesamiento de devoluciones de saldo completado en ${duration}ms`);
    return true;
  } catch (error) {
    logger.error(`Error al procesar devoluciones de saldo: ${error.message}`);
    return false;
  }
}

module.exports = {
  processReturnBalance,
};
