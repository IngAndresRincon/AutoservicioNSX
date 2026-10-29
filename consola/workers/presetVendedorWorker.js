const config = require("../config");
const { processPresetVendedor, processPresetCliente } = require("./processors/presetVendedorProcessor");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

exports.loopPresetVendedor = async () => {
  while (true) {
    await processPresetVendedor();
    await processPresetCliente();
    await sleep(config.workers.presetSellerIntervalMs);
  }
};
