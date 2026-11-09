
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
    
    const amount = parseInt(payment.amount).toString();

    const propertie = new properties(amount,"0","0","0","0","0","0","1");// Este dato se deja en uno para que Redeban no pida confirmación de datos 
    const redeban = new Redeban(new BodyRedeban(1, propertie));
    const credibanco = new Credibanco(terminal.breb,terminal.approval,new BodyCredibanco(amount,"0","0"));
    const paymentInformation = new PaymentInformation(credibanco,redeban);

    const paymentModel = new PaymentModel(
      terminal.serial,
      _isReply,
      payment.programmingid,
      payment.id  ,
      payment.positionid ,
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
