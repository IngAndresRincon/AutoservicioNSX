const AppError = require("../../errors/AppError");
const saleRepository = require("../../repositories/sale/repository");
const nsxServices = require("../../services/nsx/services");
const { getJson, postJson } = require("../../utils/http-client");
const apiNsx = process.env.API_NSX;

exports.sale = async (params) => {
  const { id } = await saleRepository.getrefpresetid(params);
  if (!id) {
    throw new AppError("No se encuentra programacion o autorizacion asociada a la venta", 404);
  }

  const endpoint = `${apiNsx}/Preset/EstadoPreset?idPreset=${id}`;
  const result = await getJson(endpoint);
  return result ;
};

exports.bill = async (params) => {
  await saleRepository.createBill(params);
  const endpoint = `${apiNsx}/Facturacion/FacturarVenta`;

  const payload = {
    idVenta: params.saleId,
    documento: params.documentNumber.toString(),
    tipoDocumento: params.documentType,
    razonSocial: params.companyName,
    email: params.email,
  };

  console.log(`BILL PAYLOAD: ${JSON.stringify(payload)}`);

  const result =await postJson(endpoint, payload);
  console.log(`Response bill: ${JSON.stringify(result.data)}`);
  return result;
};
