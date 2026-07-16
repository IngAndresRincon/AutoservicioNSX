const systemRepository = require("../../repositories/system/repository");
const { getJson, postJson } = require("../../utils/http-client");
const apiNsx = process.env.API_NSX;

exports.synchronizeModule = async () => {
  return await systemRepository.synchronizeModule();
};

exports.synchronizeScreen = async (params) => {
  return await systemRepository.synchronizeScreen(params);
};


exports.updateVideoRoute = async (body) => {

  const listScreen = await systemRepository.getScreenList();
  if(!listScreen || listScreen.length === 0){
    throw new AppError("No se encontraron pantallas para actualizar la ruta del video", 404);
  }

  for (const screen of listScreen) {
    try {
      
    const url =`http://${screen.ip}/api/config/videos`;
    const result = await postJson(url, body);
    if(result.status !== 200){
      console.error(`Error actualizando la ruta del video en la pantalla con IP ${screen.ip}. Respuesta: ${result.status} - ${result.data}`);  
    } else {
      console.info(`Ruta del video actualizada correctamente en la pantalla con IP ${screen.ip}`);
    }
    } catch (error) {
      console.error(`Error actualizando la ruta del video en la pantalla con IP ${screen.ip}`, error);
    }
  }

}