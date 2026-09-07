
const systemRepository = require("../../repositories/terminal/repository");

exports.synchronizeTerminal = async (params) =>{
  return await  systemRepository.synchronizeTerminal(params);
}

