const axios = require("axios");
const yaml = require("js-yaml");
const service = require("./services/service");
const { env } = require("./config/env");
const controller = require("./controller/controller");

let listPendingPayment = [];
let pendingPaymentIds = new Set();
let tokenNequi = null;
async function startConsole() {
  console.log(env);
  //generateToken();
  while (tokenNequi == null) {
    console.log("Esperando confirmación de token");
    await new Promise((resolve) => setTimeout(resolve, 5000)); // Esperar 30 minutos
  }
  getPendingPayment();
  getStatusPayment();
  getPendingBalance();
  requestStatusPayment();
}

async function generateToken() {
  while (true) {
    try {
      const response = await controller.generateToken();
      console.log(JSON.stringify(response.data));
      if (response == undefined) throw Error("Error generando token");

      if (response.status === 200) {
        tokenNequi = `${response.data.token_type} ${response.data.access_token}`;
      }
    } catch (e) {
      console.error(e.message);
      throw Error(e.message);
    }

    await new Promise((resolve) => setTimeout(resolve, 1800000)); // Esperar 30 minutos
  }
}

//#region Payment

async function getPendingPayment() {
  while (true) {
    if (tokenNequi == null) continue;

    const pendingPayment = await controller.getTransactionRecordByStatus(0);
    if (pendingPayment != null) {
      const result = await controller.generateQr(tokenNequi, pendingPayment);
    }
    await new Promise((resolve) => setTimeout(resolve, 5000)); // Esperar 5 segundos
  }
}

async function getStatusPayment() {
  while (true) {
    if (tokenNequi == null) continue;

  const pendingPayment = await controller.getTransactionRecordByStatus(4);
  if (pendingPayment != null) {
      const pendingPaymentId = pendingPayment.idtransaccionpago;
      const exist = pendingPaymentIds.has(pendingPaymentId);
      if (!exist) {
        listPendingPayment.push({ item: pendingPayment, attempts: 0 });
        pendingPaymentIds.add(pendingPaymentId);
      }
    }
    await new Promise((resolve) => setTimeout(resolve, 5000)); // Esperar 5 segundos
  }
}

async function requestStatusPayment() {
  const limitCounter = 60;

  while (true) {
    while (listPendingPayment.length > 0) {


      try{

      for (let i = listPendingPayment.length - 1; i >= 0; i--) {
        const paymentItem = listPendingPayment[i];
        const result = await controller.requestStatusPayment(
          paymentItem.item,
          tokenNequi,
        );

        if (result == null) continue;

        if (result.status == 200) {
          const statusCode =
            result.data.ResponseMessage.ResponseHeader.Status.StatusCode;
          const statusPayment =
            result.data.ResponseMessage.ResponseBody.any.getStatusPaymentRS.status;
          if (statusCode == "0" && statusPayment == "35") {
            await service.updateStatusTransactionPayment(
              paymentItem.item,
              JSON.stringify(result.data),
              2,
            );
            listPendingPayment.splice(i, 1);
            pendingPaymentIds.delete(paymentItem.item.idtransaccionpago);
            continue;
          }

          paymentItem.attempts++;

          if (paymentItem.attempts >= limitCounter) {
            await service.updateStatusTransactionPayment(
              paymentItem.item,
              `Tiempo de consulta excedido, número de intentos ${limitCounter} data: ${JSON.stringify(result.data)} `,
              3,
            );
            listPendingPayment.splice(i, 1); // Eliminar el item procesado del array
            pendingPaymentIds.delete(paymentItem.item.idtransaccionpago);
          }
        } else {
          await service.updateStatusTransactionPayment(
            paymentItem.item,
            JSON.stringify(result.data),
            3,
          );
          listPendingPayment.splice(i, 1);
          pendingPaymentIds.delete(paymentItem.item.idtransaccionpago);
        }
      }


      }catch(e){
        console.error(`Error obteniendo estado del pago: ${e.message}`);
      }

      await new Promise((resolve) => setTimeout(resolve, 5000)); // Esperar 5 segundos
    }

    await new Promise((resolve) => setTimeout(resolve, 2500)); // Esperar 2.5 segundos
  }
}

//#endregion Payment

//#region Balance


async function getPendingBalance() {
  while (true) {
    if (tokenNequi == null) continue;
    await controller.getRecordReturnBalance(tokenNequi,0);
 
    await new Promise((resolve) => setTimeout(resolve, 10000)); // Esperar 5 segundos
  }
}

startConsole();
