const logger = require("../../config/logger");
const AppError = require("../../errors/AppError");
const { client } = require("../../database/dbpostgres");

exports.mapping = async () => {
  return [];
};

exports.getStationData = async () => {
  const station = await getStationData();
  if (!station) {
    throw new AppError("No hay informacion de la estacion", 404);
  }

  const colorsFlag = await getColorsFlagStation(station.id);
  return { data: station, colors: colorsFlag };
};

async function getStationData() {
  const query = `SELECT id, nombre as name, id_bandera as flagid, bandera as flag, valor_max_vueltos as maximum_change_amount
                 FROM public.estacion
                 LIMIT 1;`;
  const result = await client.query(query);
  return result.rows[0] || null;
}

async function getColorsFlagStation(id) {
  const query = `SELECT color
                 FROM public.bandera_color
                 WHERE id_estacion = $1 AND activo = true
                 ORDER BY id;`;
  const result = await client.query(query, [id]);
  return result.rows || [];
}

exports.producthoses = async (screenid) => {
  try {
    const query = `
      SELECT
        d.id_nsx_dispensador as dispenserid,
        d.hibrido as hybrid,
        p.cara as dispenserside,
        p.id as positionid,
        p.id_nsx_posicion as nsxpositionid,
        m.id as hoseid,
        numero_manguera as hosenumber,
        pro.id as productid,
        pro.id_nsx_producto as nsxproductid,
        pro.nombre as product,
        pro.precio as price,
        m.precio_publico as publicprice,
        p.formato_dinero as moneyformat,
        p.formato_precio as priceformat,
        p.formato_volumen as volumeformat,
        p.maximo_dinero as maxmoney,
        lado as side,
        unidad_medida as unitofmeasurement,
        color as color,
        m.max_valor,
        p.codigo_tankio,
        m.activo as activehose,
        p.activo as activeposition
      FROM public.manguera as m
      INNER JOIN public.posicion as p ON m.id_posicion = p.id
      INNER JOIN public.dispensador as d ON d.id = p.id_dispensador
      INNER JOIN public.producto as pro ON m.id_nsx_producto = pro.id_nsx_producto
      INNER JOIN public.pantalla_posicion as pp ON pp.id_posicion = p.id
      WHERE pp.id_pantalla = $1;`;

    const response = await client.query(query, [screenid]);
    return response.rowCount > 0 ? response.rows : [];
  } catch (error) {
    logger.error("Error obteniendo modulos", error);
    throw new AppError("Error obteniendo modulos", 502, { details: error.message });
  }
};

exports.methodpayment = async () => {
  try {
    const query = `
      SELECT id as idmethopayment,
             id_nsx_forma_pago as nxspaymentid,
             nombre as name,
             logo
      FROM public.forma_pago
      WHERE activo = true;`;
    const response = await client.query(query);
    return response.rowCount > 0 ? response.rows : [];
  } catch (error) {
    logger.error("Error obteniendo formas de pago", error);
    throw new AppError("Error obteniendo modulos", 502, { details: error.message });
  }
};

exports.speeddial = async () => {
  try {
    const query = `
      SELECT id as idspeeddial,
             valordinero as moneyvalue,
             valorvolumen as volumevalue
      FROM public.marcacion
      WHERE activo = true;`;
    const response = await client.query(query);
    return response.rowCount > 0 ? response.rows : [];
  } catch (error) {
    logger.error("Error obteniendo marcaciones rapidas", error);
    throw new AppError("Error obteniendo modulos", 502, { details: error.message });
  }
};

exports.identifiers = async () => {
  try {
    const query = `SELECT id_nsx_identificador as identifierid, nombre as name
                   FROM public.identificador_cliente
                   ORDER BY id_nsx_identificador;`;
    const response = await client.query(query);
    return response.rows;
  } catch (error) {
    logger.error("Error obteniendo identificadores de cliente", error);
    throw new AppError("Error obteniendo identificadores de cliente", 502, { details: error.message });
  }
};

exports.sellerPaymentMethods = async () => {
  try {
    const query = `SELECT id_nsx_forma_pago as nsxpaymentid, nombre as name
                   FROM public.forma_pago_vendedor
                   ORDER BY id_nsx_forma_pago;`;
    const response = await client.query(query);
    return response.rows;
  } catch (error) {
    logger.error("Error obteniendo formas de pago del vendedor", error);
    throw new AppError("Error obteniendo formas de pago del vendedor", 502, { details: error.message });
  }
};

exports.fidelity = async () => {
  try {
    const query = `SELECT 
    id as fidelity_id,
    id_fidelidad_nsx as nsx_fidelity_id,
    fidelidad as fidelity_name
    FROM public.fidelidad`;
    const response = await client.query(query);
    return response.rowCount > 0 ? response.rows : [];
  } catch (error) {
    logger.error("Error obteniendo marcaciones rapidas", error);
    throw new AppError("Error obteniendo modulos", 502, { details: error.message });
  }
};

