
const { requestNsx } = require("./requestNsx");
const config = require("../config");
const apiNsx = config.apiNsx;
const repository = require("../repositories/shiftRepository");


exports.openShift = async () => {


  const nsxposition = await repository.findFirstNSXPosition();
  if(nsxposition === 0){  
    console.log("No se encontró una posición NSX activa para abrir el turno");
    return false;
  }

  const endpoint = `${apiNsx}/Turno/AbrirTurno`;

  const pass = config.mac.substring((config.mac.length - 4));

  const body = {
    identificador: config.mac,
    idPosicion: nsxposition, // config.positionShift,
    documento: config.mac,
    password: pass,
  };
  return requestNsx("post", endpoint, body);
};


exports.closeShift = async () => {

  const nsxposition = await repository.findFirstNSXPosition();
  if(nsxposition === 0){  
    console.log("No se encontró una posición NSX activa para abrir el turno");
    return false;
  }

  const endpoint = `${apiNsx}/Turno/CerrarTurno`;
  const pass = config.mac.substring((config.mac.length - 4));

  const body = {
    identificador: config.mac,
    idPosicion: nsxposition,
    documento: config.mac,
    password: pass,
  };
  return requestNsx("post", endpoint, body);
};

