const config = require("../config");
const { processReturnBalance } = require("./processors/returnBalanceProcessor");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

exports.startProcessReturnBalance = async () => {
  while (true) {
    await processReturnBalance();
    await sleep(config.workers.returnBalanceIntervalMs);
  }
};
