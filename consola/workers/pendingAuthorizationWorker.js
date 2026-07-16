const config = require("../config");
const { processPendingAuthorization } = require("./processors/pendingAuthorizationProcessor");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

exports.loopAuthorization = async () => {
  while (true) {
    await processPendingAuthorization();
    await sleep(config.workers.getPendingAuthIntervalMs);
  }
};
