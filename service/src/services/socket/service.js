const socketRepository = require("../../repositories/socket/repository");

exports.validateSocketSerial = async (serial) => {
  return socketRepository.validateSocketSerial(serial);
};

