

// const isReply = false;
// class PaymentModel {
//   constructor(
//     SerialId,
//     Reply,
//     IdAuthorization,
//     IdTransaction,
//     IdPosition,
//     Value,
//     Programation,
//     IdStatus,
//     PaymentReference,
//     Status,
//     PaymentInformation
//   ) {
//     this.SerialId = SerialId;
//     this.Reply = Reply;
//     this.IdAuthorization = IdAuthorization;
//     this.IdTransaction = IdTransaction;
//     this.IdPosition = IdPosition;
//     this.Value = Value;
//     this.Programation = Programation;
//     this.IdStatus = IdStatus;
//     this.PaymentReference = PaymentReference;
//     this.Status = Status;
//     this.PaymentInformation = PaymentInformation;
//   }
// }

// class PaymentInformation {
//   constructor(BodyCredibanco, BodyRedeban) {
//     this.BodyCredibanco = BodyCredibanco;
//     this.BodyRedeban = BodyRedeban;
//   }
// }

// class BodyCredibanco {
//   constructor(Monto, Iva, TotalIva) {
//     this.Monto = Monto;
//     this.Iva = Iva;
//     this.TotalIva = TotalIva;
//   }
// }

// class BodyRedeban {
//   constructor(TipoTransaccion, properties) {
//     this.TipoTransaccion = TipoTransaccion;
//     this.properties = properties;
//   }
// }

// class properties {
//   constructor(monto, iva, inc, montobaseiva, montobaseinc, basedevolucion,propina,flagconfirmvalues) {
//     this.monto = monto;
//     this.iva = iva;
//     this.inc = inc;
//     this.montobaseiva = montobaseiva;
//     this.montobaseinc = montobaseinc;
//     this.basedevolucion = basedevolucion;
//     this.propina = propina,
//     this.flagconfirmvalues = flagconfirmvalues;
//   }
// }

// function createItemPayment(terminal,payment) {

// let _paymentModel = null;

//   try {
    
//     let _propertiesredeban = new properties(
//       parseInt(payment.monto).toString(),
//       "0",
//       "0",
//       "0",
//       "0",
//       "0",
//       "0",
//       "1"  // Este dato se deja en uno para que Redeban no pida confirmación de datos 
//     );
//     let _bodyredeban = new BodyRedeban(1, _propertiesredeban);
//     let _bodycredibanco = new BodyCredibanco(
//       parseInt(payment.monto).toString(),
//       "0",
//       "0"
//     );
//     const _paymentinformation = new PaymentInformation(
//       _bodycredibanco,
//       _bodyredeban
//     );

//     _paymentModel = new PaymentModel(
//       terminal.serial,
//       isReply,
//       payment.idprogramacion ,
//       payment.idtransaccionpago,
//       payment.idposicion,
//       parseInt(payment.monto).toString(),
//       parseInt(payment.totalmonto).toString(),  
//       payment.idestado,
//       "",
//       "pending",
//       _paymentinformation
//     );
    
//   } catch (error) {
//     logger.error(`Error CreateItemPayment: ${error.message}`);
//   }
//   return _paymentModel;
// }

// module.exports = { createItemPayment, isReply };




const _isReply = false;
const _breb= false;
const _hospitality = false;
class PaymentModel {
  constructor(
    serial,
    reply,
    authorizationId,
    transactionId,
    position,
    amount,
    status,
    PaymentInformation,
  ) {
    this.serial = serial;
    this.reply = reply;
    this.authorizationId = authorizationId;
    this.transactionId = transactionId;
    this.position = position;
    this.amount = amount;
    this.status = status;
    this.PaymentInformation = PaymentInformation;
  }
}

class PaymentInformation {
  constructor(Credibanco, Redeban) {
    this.Credibanco = Credibanco;
    this.Redeban = Redeban;
  }
}

class Credibanco {
  constructor(breb,hospitality, BodyCredibanco) {
    this["bre-b"] = breb;
    this.hospitality = hospitality;
    this.BodyCredibanco = BodyCredibanco;
  }
}

class BodyCredibanco{
  constructor(Monto,Iva,TotalIva){
    this.Monto = Monto;
    this.Iva = Iva;
    this.TotalIva = TotalIva;
  }
}



class Redeban {
  constructor(BodyRedeban) {
    this.BodyRedeban = BodyRedeban;
  }
}


class BodyRedeban {
  constructor(TipoTransaccion, properties) {
    this.TipoTransaccion = TipoTransaccion;
    this.properties = properties;
  }
}

class properties {
  constructor(monto, iva, inc, montobaseiva, montobaseinc, basedevolucion,propina,flagconfirmvalues) {
    this.monto = monto;
    this.iva = iva;
    this.inc = inc;
    this.montobaseiva = montobaseiva;
    this.montobaseinc = montobaseinc;
    this.basedevolucion = basedevolucion;
    this.propina = propina,
    this.flagconfirmvalues = flagconfirmvalues;
  }
}


function createItemPaymentNew(terminal,payment) {

  try {
    
    const amount = parseInt(payment.monto).toString();

    const propertie = new properties(amount,"0","0","0","0","0","0","1");// Este dato se deja en uno para que Redeban no pida confirmación de datos 
    const redeban = new Redeban(new BodyRedeban(1, propertie));
    const credibanco = new Credibanco(_breb,_hospitality,new BodyCredibanco(amount,"0","0"));
    const paymentInformation = new PaymentInformation(credibanco,redeban);

    const paymentModel = new PaymentModel(
      terminal.serial,
      _isReply,
      payment.idprogramacion,
      payment.idtransaccionpago  ,
      payment.idposicion  ,
      amount,
      "pending",
      paymentInformation
    );
    
    return paymentModel;

  } catch (error) {
    console.error(`Error CreateItemPayment: ${error.message}`);
  }
  return null;
}

module.exports = { createItemPaymentNew, _isReply };
