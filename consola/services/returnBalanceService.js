const repository = require("../repositories/returnBalanceRepository");
const logger = require("../utils/logger");
const config = require("../config");
const { requestNsx } = require("./requestNsx");

const apiNsx = config.apiNsx;

exports.getPendingReturnBalance = async () => {
  return repository.getPendingReturnBalance();
};

exports.registerReturnBalanceNSX = async (body) => {
  const endpoint = `${apiNsx}/Vueltos/RegistrarVuelto`;
  logger.info(`Enviando devolución de saldo a NSX: ${JSON.stringify(body)}`);
  return requestNsx("post", endpoint, body);
};
