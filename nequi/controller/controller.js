const { env } = require("../config/env");
const service = require("../services/service");
const { encrypter, desencrypter } = require("../utils/encrypter");
const payment = require("../model/payment");
const status = require("../model/status");
const balance = require("../model/balance");

exports.generateToken = async () => {
  const auth = `${desencrypter(env.client_id)}:${desencrypter(env.client_secret)}`;
  const bufferObj = Buffer.from(auth, "utf8");
  const basicAuth = bufferObj.toString("base64");
  const url = desencrypter(env.url_token_auth);
  return await service.auth(url, basicAuth);
};

exports.getTransactionRecordByStatus = async (status) => {
  return service.getTransactionRecordByStatus(status);
};

exports.getRecordReturnBalance = async (token,status) =>{
  const item = await  service.getRecordReturnBalance(status);
  if(!item){
    return;
  }
  const url = desencrypter(env.url_dispersion);
  const apikey = desencrypter(env.api_key);
  let request = await balance.createBalanceModel(item);
  request.RequestMessage.RequestHeader.ClientID = desencrypter(env.client_id);
  const result = await service.post(url, request, apikey, token);
  if (result == undefined) {
    console.log("No hay respuesta de la devolución de saldo");
    await service.updateStatusReturnBalance(4,"Servidor destino no response",item.id);
    return null;
  }
  let statusBalance = 2;

  if (result.status == 200) {
    statusBalance = 2
  }else{
    statusBalance = 3;
  }
  await service.updateStatusReturnBalance(statusBalance,JSON.stringify(result.data),item.id);

  // await service.recordTelemetryNequi(
  //   item,
  //   JSON.stringify(result.data),
  //   "Response dispersion",
  // );

  return result;
}


exports.generateQr = async (token, record) => {
  const url = desencrypter(env.url_payment);
  const apikey = desencrypter(env.api_key);

  let request = payment.generateModelQrPayment(record);
  request.RequestMessage.RequestHeader.ClientID = desencrypter(env.client_id);
  request.RequestMessage.RequestBody.any.generateCodeQRRQ.code = desencrypter(
    env.code_nit,
  );
  await service.updateStatusTransactionPayment(
    record,
    "Transacción leída y en proceso",
    1,
  );
  await service.recordTelemetryNequi(record, request, "Request qr payment");
  console.log(`JSON Payment QR : ${JSON.stringify(request)}`);

  const result = await service.post(url, request, apikey, token);
  if (result != undefined)
    await service.recordTelemetryNequi(
      record,
      result.data,
      "Response qr payment",
    );

  if (result != undefined && result.status == 200) {
    const statusCode =
      result.data["ResponseMessage"]["ResponseHeader"]["Status"]["StatusCode"];
    if (statusCode == "0") {
      const qr =
        result.data["ResponseMessage"]["ResponseBody"]["any"][
          "generateCodeQRRS"
        ]["qrValue"];
      await service.updateStatusTransactionPayment(record, qr, 4);
    } else {
      await service.updateStatusTransactionPayment(
        record,
        JSON.stringify(result.data),
        3,
      );
    }
  } else {
    await service.updateStatusTransactionPayment(
      record,
      JSON.stringify(result.data),
      3,
    );
  }

  return result;
};

exports.requestStatusPayment = async (item, token) => {
  const url = desencrypter(env.url_get_status_payment);
  const apikey = desencrypter(env.api_key);
  let request = await status.generateRequestStatus(item);
  request.RequestMessage.RequestHeader.ClientID = desencrypter(env.client_id);
  const result = await service.post(url, request, apikey, token);
  if (result == undefined) {
    console.log("No hay respuesta del estado de la transacción");
    return null;
  }

  await service.recordTelemetryNequi(
    item,
    JSON.stringify(result.data),
    "Response status payment",
  );

 
  return result;
};
