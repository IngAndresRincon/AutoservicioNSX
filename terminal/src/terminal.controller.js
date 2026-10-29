const service = require("./terminal.service");

let terminals = [];

exports.findAvailableTerminalList = async () =>{

  let timeout = 10000;
  while(true){
    const records = await service.findAvailableTerminalList();
    
    if(records){
      timeout = 600000;
      terminals = [];
      for(let i = 0; i< records.length; i++){
        terminals.push(records[i]);
        await new Promise((resolve) => setTimeout(resolve, 5000)); // Esperar 5 segundos
      }
    }else{
      console.error("No hay terminales disponibles");
    }
    await new Promise((resolve) => setTimeout(resolve, timeout)); // Esperar 10 segundos
  }

}

exports.TerminalPaymentProcess = async () =>{
  while(true){
    try {
      for(let i=0; i<terminals.length; i++){
        const terminal = terminals[i];
        const record = await service.findTransactionPayment({statusId:1,terminal:terminal});
        if(record){
          await service.generatePaymentRequets({terminal:terminals[i], payment:record});
        }
        await new Promise((resolve) => setTimeout(resolve, 2000)); // Esperar 10 segundos
      }
    } catch (error) {
      console.log(error.message);
    }
    await new Promise((resolve) => setTimeout(resolve,5000)); // Esperar 10 segundos
  }
}



exports.TerminalStatusPayment = async ()=>{
   while(true){
    try {
      for(let i=0; i<terminals.length; i++){
        const terminal = terminals[i];
        const record = await service.findTransactionPayment({statusId:4,terminal:terminal});
        if(record){
          await service.generateStatusPaymentRequets({
            terminal:terminals[i],payment:record});
        }
        await new Promise((resolve) => setTimeout(resolve, 5000)); // Esperar 10 segundos
      }
    } catch (error) {
        console.log(error.message);
    }
    await new Promise((resolve) => setTimeout(resolve, 2000)); // Esperar 10 segundos
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
