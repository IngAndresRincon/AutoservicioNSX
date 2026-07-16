require("./config");
const { loopAuthorization } = require("./workers/pendingAuthorizationWorker");
const { loopSyncModule } = require("./workers/syncModuleWorker");
const { loopSyncSale, syncSaleNSX } = require("./workers/saleAuthorizationWorker");
const { startProcessReturnBalance } = require("./workers/returnBalanceWorker");
const { loopTransactionPayments } = require("./workers/transactionPaymentWorker");
const { loopShifts } = require("./workers/shift");

async function startConsole() {
  loopSyncModule(); //Obtener configuración de NSX
  loopAuthorization(); // Obtener autorizaciones pendientes y enviar a NSX
  loopSyncSale(); // Obtener ventas confirmadas por NSX y registrar en lista de obtener información
  syncSaleNSX(); // Consultar la lista de programaciones enviadas y obtener la información de cada una de ellas desde NSX
  startProcessReturnBalance(); //Enviar a NSX el registro de consumo de QR usado para regresar saldo
  loopTransactionPayments();  //Procesar automáticamente las transacciones por lectura de código QR 
  loopShifts();  //Procesar automáticamente las transacciones por lectura de código QR 
}

startConsole();
