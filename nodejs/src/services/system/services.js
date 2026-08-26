const systemRepository = require("../../repositories/system/repository");
const { getJson, postJson } = require("../../utils/http-client");
const apiNsx = process.env.API_NSX;
const net = require("net");
const env = require("../../config/env");


const ESC = "\x1B";
const GS = "\x1D";
// Funciones helper para formatear
const reboot = () => [0x1b, 0x40];
const alignLeft = () => [0x1b, 0x61, 0x0];
const alignRight = () => [0x1b, 0x61, 0x02];
const maxSize = () => [0x1b, 0x21, 0x12];
const alignCenter = () => [0x1b, 0x61, 0x01];
const newline = () => 0x0a;
const boldOn = () => [0x1b, 0x45, 0x01];
const boldOff = () => [0x1b, 0x45, 0x00];
const cutPaper = () => [0x1d, 0x56, 0x01];



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


exports.printcode =async (arrayPrint) =>{
  try {
    
 let arrayRows = [];
 

  for (let i = 0; i < arrayPrint.length; i++) {

    boldOff().forEach((element) => {
      arrayRows.push(element);
    });

    if (arrayPrint[i].Align == "center") {
      alignCenter().forEach((element) => {
        arrayRows.push(element);
      });
    }
    if (arrayPrint[i].Align == "left") {
      alignLeft().forEach((element) => {
        arrayRows.push(element);
      });
    }
    if (arrayPrint[i].Align == "right") {
      alignRight().forEach((element) => {
        arrayRows.push(element);
      });
    }

    const style = [
      0x1d,
      0x21,
      arrayPrint[i].Style == "0x01"
        ? 0x01
        : arrayPrint[i].Style == "0x02"
          ? 0x02
          : arrayPrint[i].Style == "0x06"
            ? 0x06
            : arrayPrint[i].Style == "0x08"
              ? 0x08
              : arrayPrint[i].Style == "0x09"
                ? 0x09
                : arrayPrint[i].Style == "0x10"
                  ? 0x10
                  : arrayPrint[i].Style == "0x11"
                    ? 0x11
                    : arrayPrint[i].Style == "0x12"
                      ? 0x12
                      : arrayPrint[i].Style == "0x13"
                        ? 0x13
                        : arrayPrint[i].Style == "0x14"
                          ? 0x14
                          : arrayPrint[i].Style == "0x15"
                            ? 0x0f
                            : 0x00,
    ];

    style.forEach((element) => {
      arrayRows.push(element);
    });

    arrayRows.push(...Buffer.from(arrayPrint[i].text));
    arrayRows.push(newline());
  }

    arrayRows.push(newline());
    arrayRows.push(newline());
    arrayRows.push(newline());
    arrayRows.push(newline());
    arrayRows.push(newline());
    arrayRows.push(newline());


  const client = new net.Socket();
  client.connect(env.printerport,env.printerip, () => {
    //console.log("Conectado a la impresora.");
    client.write(Buffer.from(arrayRows));
    client.write(Buffer.from(cutPaper()));
    client.end();
  });

  client.on("error", async (err) => {
    logger.error("Error:", err.message + item["id"]);
    await queryPg.StatusPrint(item["id"], err.message);
  });

    return true;

  } catch (error) {
    console.error(error.message);
  }

  return false;
}