const logger = require("../../config/logger");
const AppError = require("../../errors/AppError");
const { client } = require("../../database/dbpostgres");

exports.validPresetId = async (id) => {
  try {
    const query = "SELECT * FROM public.autorizacion WHERE id_presetnsx = $1 LIMIT 1;";
    const result = await client.query(query, [id]);
    return result.rows[0] || null;
  } catch (error) {
    logger.error("Error validando preset NSX", error);
    throw new AppError("Error validando preset NSX", 502, { details: error.message });
  }
};


exports.getMethodPayment = async (id) => {
  try {
    const query = "SELECT * FROM public.forma_pago WHERE id = $1 LIMIT 1;";
    const result = await client.query(query, [id]);
    return result.rows[0] || null;
  } catch (error) {
    logger.error("Error validando preset NSX", error);
    throw new AppError("Error validando preset NSX", 502, { details: error.message });
  }
};



exports.saveRecordReturnBalanceNequi = async (id,item) =>{
    try {
    const query = `INSERT INTO public.devolucion_saldo 
    (id_autorizacion,id_forma_pago,monto,contacto,estado) VALUES($1,$2,$3,$4,$5) RETURNING *;`;
    const result = await client.query(query, [id,item.methodPaymentId,item.amount,item.contact,0]);
    return result.rows[0] || null;
  } catch (error) {
    logger.error("Error validando preset NSX", error);
    throw new AppError("Error validando preset NSX", 502, { details: error.message });
  }
}