const axios = require("axios");
const repository = require("../repositories/repository");
const model = require("../model/payment");

exports.getTerminalList = async () => {
  return await repository.getTerminalList();
};

exports.getPendingPayment = async (params, statusid) => {
  return await repository.getPendingPayment(params, statusid);
};

exports.sendPayment = async (terminal, payment) => {
  let isSend = false;

  try {
    const jsonPayment = model.createItemPayment(terminal, payment);
    if (jsonPayment == null) {
      throw new Error("No se pudo generar el JSON de pago para datafono");
    }
    let statusCode = 3;
    const url = `http://${terminal.ip}/api/payment`;
    const response = await this.post(url, jsonPayment);

    if (response != undefined) {
      statusCode = response.status == 200 ? 4 : 3;
    }

    isSend = await repository.changeStatusPayment(
      payment.idtransaccionpago,
      statusCode,
      response == undefined
        ? `Terminal ${JSON.stringify(terminal)} no responde, validar conexión con sistema`
        : JSON.stringify(response.data),
    );
  } catch (error) {
    console.error(error);
    throw new Error("Error" + error.message);
  }
  return isSend;
};

exports.requestResponse = async (terminal, payment) => {
  let isSend = false;

  try {
    let statusCode = 4;
    const url = `http://${terminal.ip}/api/paymentbytransactionid?id=${payment.idtransaccionpago}`;
    const response = await this.get(url);
    if (response != undefined) {
      if (response.status == 200 || response.status == 201) {
        switch (response.data["content"]["status"].toLowerCase()) {
          case "refused":
            statusCode = 3;
            break;
          case "canceled":
            statusCode = 3;
            break;
          case "complete":
            statusCode = 2;
            break;
          case "approved":
            statusCode = 2;
            break;
          case "pending":
            break;
        }
      } else {
        statusCode = 3;
      }

      isSend = await repository.changeStatusPayment(
        payment.idtransaccionpago,
        statusCode,
        JSON.stringify(response.data),
      );
    }
  } catch (error) {
    console.error(error);
    throw new Error("Error" + error.message);
  }
  return isSend;
};

exports.post = async (endpoint, body) => {
  let response = undefined;
  try {
    let config = {
      method: "post",
      maxBodyLength: Infinity,
      timeout: 5000,
      url: endpoint,
      headers: {
        "Content-Type": "application/json",
      },
      validateStatus: function (status) {
        return true;
      },
      data: body,
    };

    response = await axios
      .request(config)
      .then((response) => {
        console.log(JSON.stringify(response.data));
        return response;
      })
      .catch((error) => {
        console.log(error);
      });
  } catch (error) {
    console.error(error);
  }
  return response;
};

exports.get = async (endpoint) => {
  let response = undefined;
  console.log(`Solicitud SMS a servicio: ${endpoint}`);
  try {
    let config = {
      method: "get",
      maxBodyLength: Infinity,
      timeout: 20000,
      url: endpoint,
      headers: {
        "Content-Type": "application/json",
      },
      validateStatus: function (status) {
        return true;
      },
    };

    response = await axios
      .request(config)
      .then((response) => {
        console.log(JSON.stringify(response.data));
        return response;
      })
      .catch((error) => {
        console.log(error);
      });
  } catch (error) {
    console.error(error);
  }
  return response;
};
