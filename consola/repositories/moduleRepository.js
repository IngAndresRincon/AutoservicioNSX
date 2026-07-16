const { client } = require("../database/dbpostgres");
const logger = require("../utils/logger");

exports.consultSyncRequest = async () => {
  let isSync = false;
  try {
    let query = `SELECT  id FROM public.modulo  WHERE sincronizar = true;`;
    const res0 = await client.query(query);
    if (res0.rowCount > 0) {
      isSync = true;
    }
  } catch (e) {
    logger.error(e);
    throw new Error("Error:" + e.message);
  }

  return isSync;
};

exports.syncModule = async () => {
  let isSync = false;
  try {
    let query = `UPDATE public.modulo  SET  sincronizar = false,  fecha_sincronizacion = NOW();`;
    const res0 = await client.query(query);
    if (res0.rowCount > 0) {
      isSync = true;
    }
  } catch (e) {
    logger.error(e);
    throw new Error("Error:" + e.message);
  }

  return isSync;
};

exports.registerProducts = async (data) => {
  let sync = false;
  try {
    let query = `UPDATE public.producto SET activo = false;`;
    await client.query(query);

    for (let i = 0; i < data.length; i++) {
      query = `SELECT id FROM public.producto WHERE id_nsx_producto = ${data[i].idProducto};`;
      const res0 = await client.query(query);
      if (res0.rowCount == 0) {
        query = `INSERT INTO public.producto (id_nsx_producto, nombre,precio) VALUES (${data[i].idProducto}, '${data[i].nombreProducto}', ${data[i].precio});`;
      } else {
        query = `UPDATE public.producto SET nombre = '${data[i].nombreProducto}', precio = ${data[i].precio}, activo = true
        WHERE id_nsx_producto = ${data[i].idProducto};`;
      }
      await client.query(query);
    }

    sync = true;
  } catch (e) {
    logger.error(e);
    throw new Error("Error al registrar los productos:" + e.message);
  }

  return sync;
};

exports.recordStationData = async (params) => {
  let sync = false;
  try {
    let query = `SELECT id FROM public.estacion LIMIT 1;`;
    const res0 = await client.query(query);
    if (res0.rowCount == 0) {
      query = `INSERT INTO public.estacion (nombre,id_bandera,bandera,valor_max_vueltos) 
      VALUES('${params.nombreEDS}', ${params.bandera.id},'${params.bandera.petrolera}', ${params.maximoVueltos });`;
    } else {
      query = `UPDATE public.estacion 
                SET nombre = '${params.nombreEDS}', 
                    id_bandera =  ${params.bandera.id},
                    bandera = '{${params.bandera.petrolera}}',
                    valor_max_vueltos = ${params.maximoVueltos }
                WHERE id = ${res0.rows[0]["id"]};`;
    }
    const res1 = await client.query(query);
    if (res1.rowCount > 0) {
      sync = true;
    }
  } catch (e) {
    logger.error(e);
    throw new Error("Error al registrar los productos:" + e.message);
  }
  return sync;
};

exports.recordSpeedDial = async (params) => {
  let sync = false;
  try {
    let query = `TRUNCATE TABLE public.marcacion RESTART IDENTITY;`;
    await client.query(query);

    for (let i = 0; i < params.dinero.length; i++) {
      query = `INSERT INTO public.marcacion (valordinero,valorvolumen) 
                VALUES(${params.dinero[i]}, ${params.volumen[i]});`;
      await client.query(query);
    }

    sync = true;
  } catch (e) {
    logger.error(e);
    throw new Error("Error al registrar los productos:" + e.message);
  }
  return sync;
};

exports.recordDispenserMapping = async (params) => {
  let sync = false;
  try {
    let query = `
      TRUNCATE TABLE public.dispensador RESTART IDENTITY CASCADE;
      TRUNCATE TABLE public.posicion RESTART IDENTITY CASCADE;
      TRUNCATE TABLE public.manguera RESTART IDENTITY CASCADE;
      `;
    await client.query(query);

    for (let i = 0; i < params.length; i++) {
      query = `INSERT INTO public.dispensador (id_nsx_dispensador,marca,tipo) VALUES(${params[i].idDispensador},'ZC',${params[i].tipoDispensador}) RETURNING *;`;
      const res1 = await client.query(query);
      if (res1.rowCount > 0) {
        const idDispenser = res1.rows[0].id;
        const listDispenserSide = params[i].caras;

        for (let j = 0; j < listDispenserSide.length; j++) {
          const idDispenserSide = listDispenserSide[j].numeroCara;
          const listPositions = listDispenserSide[j].posiciones;
          for (let k = 0; k < listPositions.length; k++) {
            query = `INSERT INTO public.posicion (id_dispensador,cara,id_nsx_posicion,
            mangueras,formato_dinero,formato_volumen,formato_precio,codigo_tankio)
                    VALUES (
                    ${idDispenser}, 
                    ${idDispenserSide}, 
                    ${listPositions[k].idPosicion},
                    ${listPositions[k].mangueras.length},
                    ${listPositions[k].formato.formatoDinero},
                    ${listPositions[k].formato.formatoVolumen},
                    ${listPositions[k].formato.formatoPrecio},
                    '${listPositions[k].codigoTankio}') RETURNING *`;

            const res2 = await client.query(query);
            if (res2.rowCount > 0) {
              const listHose = listPositions[k].mangueras;
              const idPosition = res2.rows[0].id;
              for (let m = 0; m < listHose.length; m++) {
                query = `INSERT INTO public.manguera (id_posicion,numero_manguera,id_nsx_producto,lado,unidad_medida,color,max_valor)
                  VALUES (
                        ${idPosition},
                        ${listHose[m].numero},
                        ${listHose[m].producto.idProducto},
                        '${listHose[m].lado}',
                        '${listHose[m].producto.unidadMedida}',
                        '${listHose[m].color}',
                        ${listHose[m].producto.maximoPreset});`;
                await client.query(query);
              }
            }
          }
        }
      }
    }

    sync = true;
  } catch (e) {
    logger.error(e);
    throw new Error("Error al registrar los productos:" + e.message);
  }
  return sync;
};

exports.recordMethodPayment = async (params) => {
  let sync = false;
  try {
    let query = `TRUNCATE TABLE public.forma_pago RESTART IDENTITY CASCADE;`;
    await client.query(query);

    for (let i = 0; i < params.length; i++) {
      query = `INSERT INTO public.forma_pago (id_nsx_forma_pago,nombre,activo,logo) 
              VALUES($1,$2,$3,$4) RETURNING *;`;
      await client.query(query, [
        params[i].idFormaPagoSistema,
        params[i].nombre,
        true,
        `${params[i].nombre.toLowerCase()}.png`,
      ]);
    }
    sync = true;
  } catch (e) {
    logger.error(e);
    throw new Error("Error al registrar los productos:" + e.message);
  }
  return sync;
};

exports.recordShift = async (params) => {
  try {
    let query = `TRUNCATE TABLE public.turno RESTART IDENTITY CASCADE;`;
    await client.query(query);

    for (let i = 0; i < params.length; i++) {
      query = `INSERT INTO public.turno (hora_inicial,hora_final) VALUES($1,$2) RETURNING *;`;
      await client.query(query, [params[i].horaInicio, params[i].horaFin]);
    }
    return true;
  } catch (error) {
    logger.error(error);
    throw new Error("Error al registrar los turnos:" + error.message);
  }
};

exports.recordFidelity = async (params) => {
  try {
    let query = `TRUNCATE TABLE public.fidelidad RESTART IDENTITY CASCADE;`;
    await client.query(query);

    for (let i = 0; i < params.length; i++) {
      query = `INSERT INTO public.fidelidad (id_fidelidad_nsx,fidelidad) VALUES($1,$2) RETURNING *;`;
      await client.query(query, [params[i].idFidelidad, params[i].nombre]);
    }
    return true;
  } catch (error) {
    logger.error(error);
    throw new Error("Error al registrar datos de fidelidad:" + error.message);
  }
};





