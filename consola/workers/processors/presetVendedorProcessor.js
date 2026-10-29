const config = require("../../config");
const logger = require("../../utils/logger");
const { requestNsx } = require("../../services/requestNsx");

const apiNsx = config.apiNsx;

// Cierra los presets de `repository` (vendedor o cliente identificado) segun el estado del preset en NSX
const createPresetProcessor = (repository, label) => async () => {
  try {
    const expired = await repository.expirePresets();
    if (expired.length > 0) {
      logger.warn(`${label} vencidos sin completar: ${expired.join(", ")}`);
    }

    const pending = await repository.getPendingPresets();

    for (const preset of pending) {
      const response = await requestNsx("get", `${apiNsx}/Preset/EstadoPreset?idPreset=${preset.id_presetnsx}`);
      if (!response || response.status !== 200) {
        continue;
      }

      const data = response.data?.data;
      if (data?.venta != null) {
        await repository.registerSale(preset, data.venta);
        logger.info(`${label} ${preset.id}: venta ${data.venta.idVenta} registrada`);
      } else if (data?.ventaZero) {
        await repository.markAsVentaZero(preset.id);
      } else if (data?.estadoSurtidor?.toString().toUpperCase() === "SURTIENDO") {
        await repository.markAsDispatching(preset.id);
      }
    }

    return pending.length > 0;
  } catch (error) {
    logger.error(`Error al procesar ${label}: ${error.message}`);
    return false;
  }
};

module.exports = {
  processPresetVendedor: createPresetProcessor(require("../../repositories/presetVendedorRepository"), "Preset de vendedor"),
  processPresetCliente: createPresetProcessor(require("../../repositories/presetClienteRepository"), "Preset de cliente identificado"),
};
