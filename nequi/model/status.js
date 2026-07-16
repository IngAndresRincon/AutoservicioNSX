const moment = require("moment");
const { env } = require("../config/env");

class QRStatusPayment {
  constructor(RequestMessage) {
    this.RequestMessage = RequestMessage;
  }
}

class RequestMessage {
  constructor(RequestHeader, RequestBody) {
    this.RequestHeader = RequestHeader;
    this.RequestBody = RequestBody;
  }
}

class RequestHeader {
  constructor(RequestDate, MessageID, ClientID, Destination) {
    this.Channel = "PQR03-C001";
    this.RequestDate = RequestDate;
    this.MessageID = MessageID;
    this.ClientID = ClientID;
    this.Destination = Destination;
  }
}

class Destination {
  constructor() {
    this.ServiceName = "PaymentsService";
    this.ServiceOperation = "getStatusPayment";
    this.ServiceRegion = "C001";
    this.ServiceVersion = "1.0.0";
  }
}

class RequestBody {
  constructor(any) {
    this.any = any;
  }
}
class any {
  constructor(getStatusPaymentRQ) {
    this.getStatusPaymentRQ = getStatusPaymentRQ;
  }
}

class getStatusPaymentRQ {
  constructor(qrValue) {
    this.qrValue = qrValue;
  }
}

//Original

// class getStatusPaymentRQ{
//     constructor(codeQR) {
//         this.codeQR = codeQR;
//     }
// }

exports.generateRequestStatus = (data) => {
  let model = null;
  try {
    let messageId = data.idtransaccionpago.toString();
    let qrcode = data.message.toString().replaceAll(" ", "");

    const maxlength = 10;
    const prefixlength = env.station.prefix.length;

    while (messageId.length < maxlength - prefixlength)
      messageId = "0" + messageId;
    messageId = env.station.prefix + messageId;

    let getstatuspaymentrq = new getStatusPaymentRQ(qrcode);
    let _any = new any(getstatuspaymentrq);
    let requestbody = new RequestBody(_any);

    let destination = new Destination();
    let requestheader = new RequestHeader(
      moment().format("yyyy-MM-DD:hh:mm:ss"),
      messageId,
      "",
      destination,
    );
    let requestmessage = new RequestMessage(requestheader, requestbody);

    model = new QRStatusPayment(requestmessage);
  } catch (error) {
    console.log(error.message);
    throw Error(error.message);
  }
  return model || null;
};
