class ApprovalModel {
  constructor(
    serial,
    saleId,
    receiptId,
    datetime,
    amount,
    bodyCredibanco,
   
  ) {
    this.serial = serial;
    this.saleId = saleId;
    this.receiptId = receiptId;
    this.datetime = datetime;
    this.amount = amount;
    this.bodyCredibanco = bodyCredibanco;
  }
}


class BodyCredibanco{
  constructor(Monto,Iva,TotalIva){
    this.Monto = Monto;
    this.Iva = Iva;
    this.TotalIva = TotalIva;
  }
}

exports.createItemApprovalPayment = (terminal,payment) =>{
    try {
        const approval = new ApprovalModel(
            terminal.serial,
            payment.saleid,
            payment.receiptid,
            '',
            payment.amount,
            new BodyCredibanco(
                payment.amount.toString(),
                "0",
                "0"
            )
        );

        return approval;
    } catch (error) {
        console.error(error.message);
    }

    return null;
}