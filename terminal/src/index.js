const controller = require('./terminal.controller');


console.log("Servicio datafono versión 3.0.0 Rev 15/10/2026");
controller.findAvailableTerminalList();
controller.TerminalPaymentProcess();
controller.TerminalStatusPayment();
controller.TerminalReleasePayment();