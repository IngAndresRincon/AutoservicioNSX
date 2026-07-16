const config = require("../config");

class Preset{
    constructor(idPosicion, numeroManguera, tipoProgramacion, valor, valorDinero,placa,km,formasPago, idTurno){
        this.identificador = config.identifier ;
        this.idPosicion = idPosicion;
        this.numeroManguera = numeroManguera;
        this.tipoProgramacion = tipoProgramacion;
        this.valor = valor;
        this.valorDinero = valorDinero;
        this.placa = placa;
        this.km = km;
        this.formasPago = formasPago;
        this.idTurno = idTurno;
    }
}

class FormaPago{
    constructor(idFormaPago, valor, identificador){
        this.idFormaPago = idFormaPago;
        this.valor = valor;
        this.identificador = identificador;
    }   
}

module.exports = {
    Preset,
    FormaPago
}
