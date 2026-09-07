const AppError = require("../../errors/AppError");
const mappingService = require("../../services/mapping/service");

exports.mapping = async (req, res, next) => {
  try {
    const { screenid } = req.query;

    if (!screenid || Number.isNaN(Number(screenid))) {
      throw new AppError("El parametro screenid es obligatorio y debe ser numerico", 400);
    }

    const stationData = await mappingService.getStationData();
    console.log("stationData", stationData);
    const listproducthose = await mappingService.producthoses(Number(screenid));
    console.log("listproducthose", listproducthose);
    const listmethodpayment = await mappingService.methodpayment();
    console.log("listmethodpayment", listmethodpayment);
    const listspeeddial = await mappingService.speeddial();
    console.log("listspeeddial", listspeeddial);
    const listFidelity = await mappingService.fidelity();
    console.log("listFidelity", listFidelity);

    // if (!listproducthose.length || !listmethodpayment.length || !listspeeddial.length) {
    //   throw new AppError("No hay informacion de mapeo", 404);
    // }

    return res.status(200).json({
      isError: false,
      message: "Informacion del conector consultada",
      content: {
        mapping: {
          station: stationData,
          productHoses: listproducthose,
          methodPayment: listmethodpayment,
          speedDial: listspeeddial,
          fidelity: listFidelity
        },
      },
    });
  } catch (error) {
    return next(error);
  }
};
