const config = require("../config");
const { processShifts } = require("./processors/shiftProcessor");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

exports.loopShifts = async () => {
  while (true) {
    console.log("Worker shift");
    await processShifts();
    await sleep(config.workers.shiftIntervalMs);
  }
};
