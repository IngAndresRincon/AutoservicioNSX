const service = require("./terminal.service");

let terminals = [];

exports.findAvailableTerminalList = async () =>{

  while(true){
    const records = await service.findAvailableTerminalList();
    if(records){
      for(let i = 0; i< records.length; i++){
        terminals.push(records[i]);
        await new Promise((resolve) => setTimeout(resolve, 5000)); // Esperar 5 segundos
      }
    }
    await new Promise((resolve) => setTimeout(resolve, 600000)); // Esperar 10 segundos
  }

}

exports.TerminalPaymentProcess = async () =>{
  while(true){
    try {
        await new Promise((resolve) => setTimeout(resolve, 2000)); // Esperar 10 segundos
        if(terminals.length === 0) continue;

        for(let i=0; i<terminals.length; i++){
          const record = await service.findTransactionPayment({statusId:1,terminal:terminals[i]});
          if(record){
            await service.generatePaymentRequets({item:record,terminal:terminals[i]});
          }
          
          await new Promise((resolve) => setTimeout(resolve, 5000)); // Esperar 10 segundos
        }
    } catch (error) {
        console.log(error.message);
    }
  }
}



exports.TerminalStatusPayment = async ()=>{
   while(true){
    try {
        await new Promise((resolve) => setTimeout(resolve, 2000)); // Esperar 10 segundos
        if(terminals.length === 0) continue;

        for(let i=0; i<terminals.length; i++){
          const record = await service.findTransactionPayment({statusId:4,terminal:terminals[i]});
          if(record){
            await service.generateStatusRequets({item:record,terminal:terminals[i]});
          }
          await new Promise((resolve) => setTimeout(resolve, 5000)); // Esperar 10 segundos
        }
    } catch (error) {
        console.log(error.message);
    }
  }
}


exports.TerminalReleasePayment = async () => {
  while (true) {
    try {
      const records = await service.findOverduePayment();
      if (records.length > 0) {
        for (let i = 0; i < records.length; i++) {
          const item = records[i];
          const result = await service.releasePayment(item);
          console.log(`Transacción de pago liberada: ${JSON.stringify(result)}`);
          await new Promise((resolve) => setTimeout(resolve, 10000)); // Esperar 15 segundos
        }
      }
    } catch (error) {
      console.log(error.message);
    }
    await new Promise((resolve) => setTimeout(resolve, 60000)); // Esperar 15 segundos
  }
};
