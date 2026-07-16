const axios = require("axios");
const repository = require("../repositories/repository");


exports.getTransactionRecordByStatus = async (status) =>{
  return await repository.getTransactionRecordByStatus(status);
}

exports.getRecordReturnBalance = async (status)=>{
  return await repository.getRecordReturnBalance(status);
}

exports.updateStatusTransactionPayment = async (record,msg,status) =>{
  return await repository.updateStatusTransactionPayment(record,msg,status);
}

exports.recordTelemetryNequi = async (record,rawJson, msg) =>{
  return await repository.recordTelemetryNequi(record,rawJson,msg);
}

exports.updateStatusReturnBalance = async (status, response,id) =>{
  return await repository.updateStatusReturnBalance(status, response,id);
}



exports.auth = async (endpoint, auth) => {
  let response = undefined;
  try {
    const config = {
      method: "post",
      maxBodyLength: Infinity,
      timeout: 15000,
      url: endpoint,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Basic ${auth}`,
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
    throw Error(error.message);
  }
  return response;
};

exports.post = async (endpoint, body, apikey,token) => {
  let response = undefined;
  try {
    let config = {
      method: "post",
      maxBodyLength: Infinity,
      timeout: 5000,
      url: endpoint,
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apikey,
        Authorization: token,
        
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
