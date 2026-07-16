const repository = require("../../repositories/shiftRepository");
const service = require("../../services/shiftService");
const logger = require("../../utils/logger");

exports.processShifts = async () => {
    const now = new Date();
    const today = now.toISOString().split("T")[0]; // YYYY-MM-DD
    const currentTime = now.toTimeString().split(" ")[0]; // HH:MM:SS

    console.log(`Verificando turnos para hoy ${today} a las ${currentTime}`);

    const currentDate = `${today} ${currentTime}`;
    const availableShift = await repository.getCurrentShiftAvailable(currentDate);
    if(!availableShift) return;

    if(!availableShift.activo){
        const shiftClose = await repository.getShiftToClose();
        if(shiftClose){
            logger.info(`Turno encontrado para cerrar  ${currentTime}`);
            const resultCloseService = await closeShiftNsx(shiftClose);
        };

        logger.info(`Turno encontrado para abrir  ${currentTime}`);
        const resultOpenService = await openShiftNsx(availableShift);

    }
    return true;
}


async function closeShiftNsx(shift) {
    const result = await service.closeShift();
    if(result.status === 200 && result.data && result.data.success) {
        logger.info(`Turno ${shift.id} cerrado correctamente en NSX`);
        await repository.closeShift(shift.id);
        return true;
    }
}

    
async function openShiftNsx(shift) {
    const result = await service.openShift();
    if(result.status === 200 && result.data && result.data.success) {
        const nsxShift = result.data.data;
        logger.info(`Turno ${shift.id} abierto correctamente en NSX`);
        //await repository.closeShift(shift.id);
        await repository.openShift(shift.id,nsxShift);
        return true;
    }else{
        console.log(`Error abriendo turno: ${JSON.stringfy(result.data)}`);
    }
}



//   try {
//     const pending = await repository.getPendingTransactionPayments();
//     return sync;
//   } catch (error) {
//     logger.error(`Error al procesar transacciones de pago: ${error.message}`);
//     return false;
//   }

