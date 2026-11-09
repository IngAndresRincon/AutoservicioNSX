const repository = require("./terminal.repository");
const axios = require("axios");
const { env } = require("../config/env");
const {createItemPaymentNew} = require('../model/payment');
const {createItemApprovalPayment} = require('../model/approval');



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
      await repository.updateTransactionStatus(id,statusId,response.data);
      return true;

    }else{
      await repository.updateTransactionStatus(id,statusId,response.data);
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


exports.findApprovePayment = async (terminal, syncId) => {
  return await repository.findApprovePayment(terminal, syncId);
};




exports.sendPaymentApproval = async (terminal, records) => {
  try {
    for (let i = 0; i < records.length; i++) {
      const record = records[0];
      const result = await createRequestApproval(terminal, record);
      await new Promise((resolve) => setTimeout(resolve, 1000)); // Esperar 5 segundos
    }
  } catch (error) {
    console.log(error.message);
  }
};



async function createRequestApproval(terminal, record) {
  try {
    const id = record.id;
    const approvalPayment = createItemApprovalPayment(terminal, record);
    if (!approvalPayment) {
      console.error(
        `Error creando la solicitud de aprobación : ${JSON.stringify(record)}`,
      );
      return false;
    }

    console.log(`Solicitud de aprobación: ${approvalPayment}`);
    let statusId = 1; // Código de confirmación de proceso;
    await repository.updateApprovePayment(id, 1, approvalPayment);

    const url = env.endpoints.url_pledge.replace('[urlbase]',terminal.ip);

    const response = await put(url, approvalPayment);

    statusId = 3;
    if (response == undefined || !response) {
      console.error(
        `No hay respuesta de la terminal destino: ${JSON.stringify(terminal)}`,
      );
    } else {
      console.log(`Response approve status: ${JSON.stringify(response.data)}`);
      if (response.status == 200) {
        statusId = 4; 
      }
    }

    const result =
      response == undefined
        ? "Respuesta del servidor destino no valida, verifique la terminal destino"
        : response.data;

    await repository.updateApprovePayment(id, statusId, result);

  } catch (error) {
    console.error(error.message);
  }
}








exports.requestStatusApprovePayment = async (terminal, records) =>{
  try {

  for(let i = 0; i< records.length; i++){
      const record = records[0];
      const response = await createRequestStatusApproval(terminal,record);
      if(!response){
        console.log("Error obteniendo el estado de la aprobación de pago");
      }
      await new Promise((resolve) => setTimeout(resolve, 1000)); // Esperar 5 segundos
    }

  } catch (error) {
    console.error(error.message);
  }
  return false;
}



async function createRequestStatusApproval(terminal, record) {
  try {
    

    const id = record.id;
    const url = `${env.endpoints.url_pledge.replace('[urlbase]',terminal.ip)}${record.receiptid}`;
    //  `http://${terminal.ip}/api/approve/payment/${record.receiptid }`;     
    let statusId = 3;
    const response = await get(url);
    if(response == undefined || !response){
        console.error("Respuesta de servidor estado de aprobación no valida.");
    }else{
      console.log(`Response status approve: ${JSON.stringify(response.data)}`);
      if(response. status == 200){
         switch(response.data['content'][0]['status']){
          case 'approved': statusId = 2; break;
          case 'rejected': statusId = 5; break;
          case 'canceled':
          case 'error':
            statusId = 3;
            break;
          default:
            statusId = 4;
            break;
        }
      }
    }

    const result = response == undefined? 'No hay respuesta del servidor destino, valida la comunicación con la terminal de pago' : response.data;

    const updated = await repository.updateApprovePayment(id,statusId,result);
    if(updated) return true;

  } catch (error) {
    console.error(error.message);
  }

  return false;
}











async function put(endpoint, body) {
  let response = undefined;
  try {
    let config = {
      method: "put",
      maxBodyLength: Infinity,
      timeout: 60000,
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