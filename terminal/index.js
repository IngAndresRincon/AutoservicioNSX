const axios = require("axios");
const yaml = require("js-yaml");
const service = require("./services/service");

let terminalList = [];


async function startConsole() {

  await loadTerminalConfig();
  startProcessPaymentTerminal();
  startProcessResponseTerminal();
}


async function loadTerminalConfig(){

    const response = await service.getTerminalList();
    console.log(`Terminales disponisbles: ${JSON.stringify(response)}`);
    if(response.length ===0){
      console.error("No hay terminales de pago configuradas");
      exit();
    }

    terminalList = response;

}


async function startProcessPaymentTerminal(){

  while(terminalList.length>0){

    for(let i =0; i < terminalList.length;i++)
    {
      const payment = await service.getPendingPayment(terminalList[i],0);
      if(payment!= null){
        console.log(payment);
        await service.sendPayment(terminalList[i], payment);
      }
        await new Promise((resolve) => setTimeout(resolve, 1000)); // Esperar 1 segundo
    }

    await new Promise((resolve) => setTimeout(resolve, 1000)); // Esperar 1 segundo
  }
}


async function startProcessResponseTerminal(){

  while(terminalList.length>0){

    for(let i =0; i < terminalList.length;i++)
    {
      const payment = await service.getPendingPayment(terminalList[i],4);
      if(payment!= null){
        console.log(payment);
        await service.requestResponse(terminalList[i], payment);
      }
      await new Promise((resolve) => setTimeout(resolve, 1000)); // Esperar 1 segundo
    }

    await new Promise((resolve) => setTimeout(resolve, 5000)); // Esperar 5 segundos
  }
}

startConsole();