const config = require("../config");
const {
  processPendingSaleAuthorization,
  processSaleAuthorizationQueue,
} = require("./processors/saleAuthorizationProcessor");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function syncSaleNSX() {
  while (true) {
    await processSaleAuthorizationQueue({
      limitCounter: config.workers.saleSyncLimitCounter,
      retryDelayMs: config.workers.saleSyncRetryDelayMs,
      loopDelayMs: config.workers.saleSyncLoopIntervalMs,
    });
  }
}

exports.loopSyncSale = async () => {
  while (true) {
    await processPendingSaleAuthorization();
    await sleep(config.workers.salePendingIntervalMs);
  }
};

exports.syncSaleNSX = syncSaleNSX;
