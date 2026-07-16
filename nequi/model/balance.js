const moment = require("moment");
const {env} = require('../config/env');
const { encrypter, desencrypter } = require("../utils/encrypter");

class Destination {
  constructor() {
    this.ServiceName = "DispersionService";
    this.ServiceOperation = "disperseFunds";
    this.ServiceRegion = "C001";
    this.ServiceVersion = "1.0.0";
  }
}

class RequestHeader {
  constructor(requestDate, messageID, clientID, destination) {
    this.Channel = "GLK06-C001";
    this.RequestDate = requestDate;
    this.MessageID = messageID;
    this.ClientID = clientID;
    this.Destination = destination;
  }
}

class DisperseFundsRQ {
  constructor(
    code,
    trackingID,
    phoneNumber,
    value,
    reference1,
    reference2,
    reference3
  ) {
    this.code = code;
    this.trackingID = trackingID;
    this.phoneNumber = phoneNumber;
    this.value = value;
    this.reference1 = reference1;
    this.reference2 = reference2;
    this.reference3 = reference3;
  }
}

class RequestBody {
  constructor(disperseFundsRQ) {
    this.any = {
      disperseFundsRQ: disperseFundsRQ,
    };
  }
}

class RequestMessage {
  constructor(requestHeader, requestBody) {
    this.RequestHeader = requestHeader;
    this.RequestBody = requestBody;
  }
}

class MainRequest {
  constructor(requestMessage) {
    this.RequestMessage = requestMessage;
  }
}

function createBalanceModel(item) {

  let model = null;

    try{
        let _trackingid = item.id.toString();
        let _messageid = item.id.toString();
        const lengthPrefix = env.station.prefix.length;

        while (_trackingid.length < (9-lengthPrefix)) _trackingid = "0" + _trackingid;
        const maxLengthMessageId = 16;


        while (_messageid.length < (maxLengthMessageId-lengthPrefix)) _messageid = "0" + _messageid;
        _trackingid = "DAN" + env.station.prefix + _trackingid;
        _messageid = env.station.prefix +_messageid;
        const _requestbody = new RequestBody(new DisperseFundsRQ(
          desencrypter(env.code_dispersion),
          _trackingid,
          item.contacto ,
          item.monto.toString(),
          "Recarga de saldo por diferencia de dinero",
          "",
          ""
        ));
      
        const _requestheader = new RequestHeader(
          moment().format("yyyy-MM-DD:hh:mm:ss"),
          _messageid,
          "",
          new Destination()
        );
      
        const _rootRequets = new MainRequest(new RequestMessage(
          _requestheader,
          _requestbody
        ))
      
        model = _rootRequets;

    }catch(error){
      console.error(error.message);
    }
    return model;
}


module.exports = {createBalanceModel}