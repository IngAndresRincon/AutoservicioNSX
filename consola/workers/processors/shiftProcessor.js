const repository = require("../../repositories/shiftRepository");
const service = require("../../services/shiftService");
const logger = require("../../utils/logger");


function getFechaHoraColombia() {
    const fecha = new Date();

    const partes = new Intl.DateTimeFormat("sv-SE", {
        timeZone: "America/Bogota",
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
        hour12: false
    }).format(fecha);

    return partes.replace(" ", " ");
}


exports.processShifts = async () => {
    const now = new Date();
    let currentDate = getFechaHoraColombia();
    console.log(`Verificando turnos para hoy ${currentDate}`);
    //currentDate = '2026-07-24 13:01:00';
    const availableShift = await repository.getCurrentShiftAvailable(currentDate);
    if(!availableShift) return;

    if(availableShift.activo){

        const dateValidity = await repository.dateValidity(currentDate);
        if(!dateValidity){
            //Cerrar turno y abrir uno nuevo
            const shiftClose = await repository.getShiftToClose();
            if(shiftClose){
                logger.info(`Turno encontrado para cerrar  ${currentDate}`);
                const resultCloseService = await closeShiftNsx(shiftClose);
            };

        }
    }


    if(!availableShift.activo){
        const shiftClose = await repository.getShiftToClose();
        if(shiftClose){
            logger.info(`Turno encontrado para cerrar  ${currentTime}`);
            const resultCloseService = await closeShiftNsx(shiftClose);
        };
        logger.info(`Turno encontrado para abrir  ${JSON.stringify(availableShift)}`);
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


    // //const result = await service.openShift();
    //  const nsxShift = {idTurno:123456};
    //     logger.info(`Turno ${shift.id} abierto correctamente en NSX`);
    //     //await repository.closeShift(shift.id);
    //     await repository.openShift(shift,nsxShift);
    //     return true;


//---------------------------------------------

    const result = await service.openShift();
    if(result.status === 200 && result.data && result.data.success) {
        const nsxShift = result.data.data;
        logger.info(`Turno ${shift.id} abierto correctamente en NSX`);
        //await repository.closeShift(shift.id);
        await repository.openShift(shift,nsxShift);
        return true;
    }else{
        console.log(`Error abriendo turno: ${JSON.stringify(shift)}`);
    }
}



//   try {
//     const pending = await repository.getPendingTransactionPayments();
//     return sync;
//   } catch (error) {
//     logger.error(`Error al procesar transacciones de pago: ${error.message}`);
//     return false;
//   }

