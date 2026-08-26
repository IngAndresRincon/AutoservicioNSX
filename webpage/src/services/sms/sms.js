
const axios = require("axios");

async function GetService(endpoint, param) {
  let response = undefined;
  console.log(`Solicitud SMS a servicio: ${endpoint}${param}`);
  try {
    const request = {
      method: "get",
      maxBodyLength: Infinity,
      timeout: 20000,
      url: `${endpoint}${param}`,
      headers: {
        "Content-Type": "application/json",
      },
      validateStatus: function (status) {
        return true;
      },
    };

    response = await axios
      .request(request)
      .then((response) => {
        return response;
      })
      .catch((error) => {
        console.error(error.message);
      });
  } catch (error) {
    console.error(error);
  }
  return response;
}


module.exports = { GetService };
