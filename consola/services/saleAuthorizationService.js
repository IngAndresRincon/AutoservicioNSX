const repository = require("../repositories/saleAuthorizationRepository");
const config = require("../config");
const { requestNsx } = require("./requestNsx");

const apiNsx = config.apiNsx;

exports.getPendingSaleAuthorization = async () => {
  return repository.getPendingSaleAuthorization();
};

exports.getSaleAuthorizationState = async (idPresetNsx) => {
  const endpoint = `${apiNsx}/Preset/EstadoPreset?idPreset=${idPresetNsx}`;
  return requestNsx("get", endpoint);
};
