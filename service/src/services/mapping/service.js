
const mappingRepository = require("../../repositories/mapping/repository");


exports.mapping = (params) =>{
  return mappingRepository.mapping(params);
}
exports.getStationData = async  ()=>{
  return await mappingRepository.getStationData();
}

exports.producthoses = async(screenid) =>{
  return await mappingRepository.producthoses(screenid);
}

exports.methodpayment = async  () =>{
  return await mappingRepository.methodpayment();
}

exports.speeddial = async () =>{
  return await mappingRepository.speeddial();
}

exports.fidelity = async () =>{
  return await mappingRepository.fidelity();
}



