const repository = require("../repositories/pendingAuthorizationRepository");
const logger = require("../utils/logger");
const config = require("../config");
const { requestNsx } = require("./requestNsx");

const apiNsx = config.apiNsx;

exports.getPendingAuthorization = async () => {
  return repository.getPendingAuthorization();
};

exports.syncAuthorizationNSX = async (param) => {
  console.log(`Enviando autorización a NSX: ${JSON.stringify(param)}`);
  const endpoint = `${apiNsx}/Preset/Preset`;
  const response = await requestNsx("post", endpoint, param.preset);

  const statusCode = response.status == 200 ? 2 : 3;
  await repository.updateAuthorizationSync(param, response.data, statusCode);

  return response;
};
