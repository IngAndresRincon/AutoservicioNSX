const repository = require("./terminal.repository");
const axios = require("axios");
const { env } = require("../config/env");
const {createItemPaymentNew} = require('../model/payment');


exports.findAvailableTerminalList = async ()  =>{
  return await repository.findAvailableTerminalList();
}

exports.findTransactionPayment = async ({statusId,terminal}) =>{
  return await repository.findTransactionPayment({statusId:statusId,terminal:terminal});
}


exports.generatePaymentRequets = async ({terminal,payment}) =>{
  try {

    const id = payment.id;
    const paymentRequest = createItemPaymentNew(terminal,payment);
    if(!paymentRequest){
      console.error(`Error generando modelo de pago para: ${JSON.stringify(payment)}`);
      return false;
    }
    //await repository.updateTransactionStatus(id,6,paymentRequest);

    const baseUrl = env.endpoints.url_payment.replaceAll('[urlbase]',terminal.ip);
    const response = await post(baseUrl,paymentRequest);

    let statusId = 3;
    if(response == undefined || !response){
      console.log("Servidor de terminal destino, no responde");
    }else{
      statusId = response.status == 200 ? 4 : 3;
    }

    const result = response == undefined? 'Terminal destino, no responde': response.data;

    await repository.updateTransactionStatus(id,statusId,result);

  } catch (error) {
    console.log(error.message);
  }

  return false;
}


exports.generateStatusPaymentRequets = async  ({terminal,payment})=>{
   try {

    const id = payment.id ;
    const baseUrl = `${env.endpoints.url_status_payment.replaceAll('[urlbase]',terminal.ip)}${id}`;
    const response = await get(baseUrl);

    let statusId = 3;
    if(response == undefined || !response){
      await repository.updateTransactionStatus(id,statusId,'Servidor destino no responde, valida la conexión con la terminal destino');
      return false;
    }

    if(response.status == 200 || response.status == 201){
      if(response.data.isError){
        await repository.updateTransactionStatus(id,statusId,JSON.stringify(response.data));
        return false;
      }

      statusId = 4;
      const statusResponse = response.data["content"][0]["status"].toLowerCase();
      switch(statusResponse){
        case "rejected":
          statusId = 5;
          break;  
        case "refused":
        case "canceled":
        case "error":
          statusId = 3
          break;
        case "complete":
        case "approved":
          statusId = 2
          break;
        case "pending":break;
      }
      await repository.updateTransactionStatus(id,statusId,JSON.stringify(response.data));
      return true;

    }else{
      await repository.updateTransactionStatus(id,statusId,JSON.stringify(response.data));
    }

  } catch (error) {
    console.log(error.message);
  }

  return false;
}






exports.findOverduePayment = async ()=>{
  return await repository.findOverduePayment();
}

exports.releasePayment = async (record) =>{
  return  await repository.releasePaymentById(record.id);
}





async function post(endpoint, body) {
  let response = undefined;
  try {
    let config = {
      method: "post",
      maxBodyLength: Infinity,
      timeout: 5000,
      url: endpoint,
      headers:{
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
}


async function get(endpoint) {
  let response = undefined;
  console.log(`Solicitud SMS a servicio: ${endpoint}`);
  try {
    let config = {
      method: "get",
      maxBodyLength: Infinity,
      timeout: 10000,
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
}