const AppError = require("../../errors/AppError");
const clientRepository = require("../../repositories/client/repository");
const apiNsx = process.env.API_NSX;
const { getJson, postJson } = require("../../utils/http-client");

exports.clientValidation = async (params) => {
  return clientRepository.clientValidation(params);
};

exports.clientValidationDian = async (identifier) => {
  const endpoint = `${apiNsx}/Facturacion/ConsultarCliente?documento=${identifier}`;
  const response = await getJson(endpoint);

  if (response?.status !== 200 || !response.data?.data) {
    throw new AppError("No fue posible consultar el cliente en NSX", 502, {
      details: response?.data,
    });
  }

  return clientRepository.clientValidationDian(response.data.data);
};

exports.additionalInformation = async (params) => {
  return clientRepository.additionalInformation(params);
};

exports.post = async (endpoint, body) => {
  return postJson(endpoint, body);
};

exports.get = async (endpoint) => {
  return getJson(endpoint);
};

