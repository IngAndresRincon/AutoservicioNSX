
const programmingRepository = require("../../repositories/programming/repository");


exports.createprogramming = async (params) =>{
  return await programmingRepository.createprogramming(params);
}

exports.createPayment = async (params) =>{
  return await programmingRepository.createPayment(params);
}

exports.pendingProgramming = async (userId) => {
  return await programmingRepository.pendingProgramming(userId);
}

exports.pendingAuthorization = async (userId) => {
  return await programmingRepository.pendingAuthorization(userId);
}


exports.resendAuthorization = async (authorizationId) => {
  return await programmingRepository.resendAuthorization(authorizationId);
}

exports.authorizeProgramming = async (clientId, programmingId) => {
  return await programmingRepository.authorizeProgramming(clientId, programmingId);
}



