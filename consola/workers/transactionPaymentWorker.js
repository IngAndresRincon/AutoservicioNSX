const config = require("../config");
const { processTransactionPayments } = require("./processors/transactionPaymentProcessor");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

exports.loopTransactionPayments = async () => {
  while (true) {
    await processTransactionPayments();
    await sleep(config.workers.transactionPaymentIntervalMs);
  }
};
