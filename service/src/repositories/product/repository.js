const logger = require("../../config/logger");
const AppError = require("../../errors/AppError");
const { client } = require("../../database/dbpostgres");

exports.product = async () => {
  try {
    const query = `SELECT
      id,
      id_nsx_producto,
      nombre,
      precio,
      activo,
      fecha_registro
      FROM public.producto
      WHERE activo = true;`;
    const response = await client.query(query);
    return response.rowCount > 0 ? response.rows : [];
  } catch (error) {
    logger.error("Error obteniendo productos", error);
    throw new AppError("Error obteniendo productos", 502, { details: error.message });
  }
};

exports.updateProduct = async (nsxId, price) => {
  try {
    const query = "UPDATE public.producto SET precio = $1 WHERE id_nsx_producto = $2 RETURNING *;";
    const response = await client.query(query, [price, nsxId]);
    return response.rowCount > 0 ? response.rows[0] : null;
  } catch (error) {
    logger.error("Error actualizando producto", error);
    throw new AppError("Error actualizando producto", 502, { details: error.message });
  }
};
