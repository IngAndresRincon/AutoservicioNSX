const repository = require("../../repositories/transactionPaymentRepository");
const logger = require("../../utils/logger");

async function processTransactionPayments() {
  const startTime = Date.now();
  try {
    const pending = await repository.getPendingTransactionPayments();

    if (pending.length === 0) {
      const duration = Date.now() - startTime;
      logger.info(`No hay transacciones de pago pendientes en ${duration}ms`);
      return false;
    }

    const ids = pending.map((item) => item.id);
    const sync = await repository.markTransactionPaymentsAsProcessed(ids);

    const duration = Date.now() - startTime;
    if (sync) {
      logger.info(
        `Procesadas ${ids.length} transacciones de pago en ${duration}ms`,
      );
    }

    return sync;
  } catch (error) {
    logger.error(`Error al procesar transacciones de pago: ${error.message}`);
    return false;
  }
}

module.exports = {
  processTransactionPayments,
};
