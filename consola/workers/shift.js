const config = require("../config");
const { processShifts } = require("./processors/shiftProcessor");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

exports.loopShifts = async () => {
  while (true) {
    console.log("Worker shift");
    try {
      await processShifts();
    } catch (error) {
      // Un fallo de red no debe matar el ciclo: se reintenta en el siguiente
      console.error(`Error en worker de turnos: ${error.message}`);
    }
    await sleep(config.workers.shiftIntervalMs);
  }
};
