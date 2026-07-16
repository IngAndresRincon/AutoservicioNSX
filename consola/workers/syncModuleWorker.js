const config = require("../config");
const { processModuleSync } = require("./processors/moduleSyncProcessor");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

exports.loopSyncModule = async () => {
  while (true) {
    await processModuleSync();
    await sleep(config.workers.syncModuleIntervalMs);
  }
};
