
const {env} = require('../config/env');
const moment = require("moment");

class QRPayment {
    constructor(RequestMessage){
            this.RequestMessage = RequestMessage;
    }
}

class RequestMessage{
    constructor(RequestHeader,RequestBody) {
        this.RequestHeader = RequestHeader;
        this.RequestBody = RequestBody;

    }
}


class RequestHeader{
    constructor(RequestDate,MessageID,ClientID,Destination){
        this.Channel = "PQR03-C001";
        this.RequestDate = RequestDate;
        this.MessageID = MessageID;
        this.ClientID = ClientID;
        this.Destination = Destination;
    }
}


class Destination{
    constructor(){
        this.ServiceName = "PaymentsService";
        this.ServiceOperation = "generateCodeQR";
        this.ServiceRegion = "C001";
        this.ServiceVersion =  "1.2.0";
    }
}

class RequestBody{
    constructor(any){
        this.any = any;
    }
}
class any{
    constructor(generateCodeQRRQ){
        this.generateCodeQRRQ = generateCodeQRRQ;
    }
}

class generateCodeQRRQ{
    constructor(code,value,reference1,reference2,reference3) {
        this.code = code;
        this.value = value;
        this.reference1 = reference1;
        this.reference2 = reference2;
        this.reference3 = reference3;
    }
}



exports.generateModelQrPayment = (data)=> {

  let qrpayment = null;

    try{
        let messageId = data.idtransaccionpago.toString();
        const value = Number(data.monto).toString();
        const maxlength = 10;
        const prefixlength = env.station.prefix.length;
        while (messageId.length < (maxlength-prefixlength)) messageId = "0" + messageId;
        messageId = env.station.prefix + messageId;
    
        const generatecodeqrrq = new generateCodeQRRQ("",value,`Generar código QR IdTransacciónPago ${data.idtransaccionpago}`,"","");
        const _any = new any(generatecodeqrrq);
        const requestbody = new RequestBody(_any);
    
        const destination = new Destination();
        const requestheader = new RequestHeader(moment().format("yyyy-MM-DD:hh:mm:ss"),messageId,"",destination);
    
        const requestmessage = new RequestMessage(requestheader,requestbody);
        qrpayment = new QRPayment(requestmessage);

    }catch(error){
        throw Error(error.message);
    }    
    return qrpayment

}