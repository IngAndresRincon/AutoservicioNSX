const service = require("./terminal.service");

let terminals = [];

// Esperas de los ciclos (ms)
const TERMINAL_LIST_FIRST_RETRY_MS = 10000;
const TERMINAL_LIST_REFRESH_MS = 600000;
const PAYMENT_LOOP_MS = 500;
const STATUS_LOOP_MS = 1000;
const APPROVAL_LOOP_MS = 2000;
const NO_APPROVAL_WAIT_MS = 60000;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Atiende todas las terminales a la vez; un fallo en una no frena a las demas
async function forEachTerminal(list, handler) {
  const results = await Promise.allSettled(list.map(handler));
  results.forEach((r) => {
    if (r.status === "rejected") console.log(r.reason && r.reason.message ? r.reason.message : r.reason);
  });
}

exports.findAvailableTerminalList = async () =>{

  let timeout = TERMINAL_LIST_FIRST_RETRY_MS;
  while(true){
    try {
      const records = await service.findAvailableTerminalList();

      if(records){
        timeout = TERMINAL_LIST_REFRESH_MS;
        // Se cambia la lista de una vez: nunca queda vacia mientras se recarga
        terminals = records.slice();
      }else{
        console.error("No hay terminales disponibles");
      }
    } catch (error) {
      console.log(error.message);
    }
    await sleep(timeout);
  }

}

exports.TerminalPaymentProcess = async () =>{
  while(true){
    try {
      await forEachTerminal(terminals, async (terminal) => {
        const record = await service.findTransactionPayment({statusId:0,terminal:terminal});
        if(record){
          await service.generatePaymentRequets({terminal:terminal, payment:record});
        }
      });
    } catch (error) {
      console.log(error.message);
    }
    await sleep(PAYMENT_LOOP_MS);
  }
}



exports.TerminalStatusPayment = async ()=>{
   while(true){
    try {
      await forEachTerminal(terminals, async (terminal) => {
        const record = await service.findTransactionPayment({statusId:4,terminal:terminal});
        if(record){
          await service.generateStatusPaymentRequets({
            terminal:terminal,payment:record});
        }
      });
    } catch (error) {
        console.log(error.message);
    }
    await sleep(STATUS_LOOP_MS);
  }
}



exports.TerminalApprovePayment = async () =>{

  while(true){
    await sleep(APPROVAL_LOOP_MS);
    try {
      const terminal = terminals[0];
      if(!terminal) continue;
      if(!terminal.approval) {
        await sleep(NO_APPROVAL_WAIT_MS);
        continue;
      }
      const records = await service.findApprovePayment(terminal,0); //0 Es para aprobaciones con sincronización en 0
      if(records.length>0){
        console.log(records);
        await service.sendPaymentApproval(terminal, records);
      }
    } catch (error) {
      console.log(error.message);
    }
  }
}


exports.TerminalStatusApprovePayment = async () =>{

  while(true){
    await sleep(APPROVAL_LOOP_MS);
    try {
      const terminal = terminals[0];
      if(!terminal) continue;
      if(!terminal.approval) {
        await sleep(NO_APPROVAL_WAIT_MS);
        continue;
      }
      const records = await service.findApprovePayment(terminal,4);
      if(records.length>0){
        // console.log(records);
        await service.requestStatusApprovePayment(terminal, records);
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
