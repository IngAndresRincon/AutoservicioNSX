const repository = require("../repositories/moduleRepository");
const logger = require("../utils/logger");
const config = require("../config");
const { requestNsx } = require("./requestNsx");

const apiNsx = config.apiNsx;

exports.consultSyncRequest = async () => {
  return repository.consultSyncRequest();
};

exports.syncModule = async () => {
  const _responseMapping = await exports.getMapping();
  if (_responseMapping.status == 200) {
    logger.info(`Mapeo obtenido: ${JSON.stringify(_responseMapping.data)}`);
    const params = _responseMapping.data.data;
    await repository.recordStationData(params.estacion);
    await repository.recordSpeedDial(params.estacion.marcacionesRapidas);
    await repository.recordDispenserMapping(params.dispensadores);
    await repository.recordMethodPayment(params.formasPago);
    await repository.recordShift(params.estacion.turnos);
    await repository.recordFidelity(params.fidelidad);
  }

  const _responseProducts = await exports.getAllProduct();
  if (_responseProducts.status == 200) {
    logger.info(
      `Productos obtenidos: ${JSON.stringify(_responseProducts.data.data)}`,
    );
    await repository.registerProducts(_responseProducts.data.data);
  }

  await repository.syncModule();
};

exports.getMapping = async () => {
  const endpoint = `${apiNsx}/Mapeo/ObtenerMapeo?identificador=${config.mac}`;
  return requestNsx("get", endpoint);
};

exports.getAllProduct = async () => {
  const endpoint = `${apiNsx}/Mapeo/ObtenerPrecios`;
  return requestNsx("get", endpoint);
};
