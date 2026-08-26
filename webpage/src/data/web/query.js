const { client } = require("../connection");
const { loggerPg } = require("../../log/event_emitter");
// const config = require("../../services/sms/configuration").config;
// const service = require("../../services/sms/sms");
const encry = require("../../../utils/encrypter");
// const charactersCode ="0123456789";

const charactersCode =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

async function ValidateCodeLogin(code) {
  let isValid = false;
  try {
    //Verifica que el código de ingreso sea valido
    const query = `SELECT id FROM public.usuario WHERE logincode = '${encry.encrypter(
      code
    )}' and activo = true`;
    const response = await client.query(query);
    if (response.rowCount > 0) isValid = true;
  } catch (error) {
    console.log(error.message);
  }
  return isValid;
}

async function GetAvailableScreenId(serialid) {
  let isValid = false;
  try {
    // const query = `SELECT id FROM public.pantalla WHERE id = ${id}`;
    const query = `SELECT id FROM public.pantalla WHERE serial = '${serialid}'`;
    const response = await client.query(query);
    if (response.rowCount > 0) {
      isValid = true;
    }
  } catch (error) {
    loggerPg.error(error.message);
  }
  return isValid;
}

async function InsertLogAuditor(log) {
  try {
    const query = `INSERT INTO auditor (log) VALUES ('${log}'); `;
    await client.query(query);
  } catch (error) {
    loggerPg.error(error.message);
  }
}

async function ValidUserLogin(user, password, screenid) {
  let isValid = false;
  try {
    InsertLogAuditor(
      `Solicitud validar usuario: ${encry.encrypter(
        user
      )}, contraseña: ${encry.encrypter(password)}, pantalla: ${screenid}`
    );
    // const code = GenerateLoginCode();
    let query = `SELECT id, phonenumber
     FROM public.usuario 
     WHERE username =  TRIM('${encry.encrypter(
       user
     )}') and password = TRIM('${encry.encrypter(
      password
    )}') AND  activo = true;`;
    const response = await client.query(query);

    if (response.rowCount > 0) {
      InsertLogAuditor(
        `Acceso correcto para el usuario ${encry.encrypter(user)}`
      );
      isValid = true;
      //  query = `UPDATE public.usuario SET logincode = '${encry.encrypter(code)}' where id = ${response.rows[0].id};`;

      // const response1 = await client.query(query);
      // if (response1.rowCount > 0) {
      //   isValid = true;

      //   console.log(`JSON User: ${JSON.stringify(response1.rows)}`);

      //   // const _username = encry.desencrypter(config.username).trim();
      //   // const _password = encry.desencrypter(config.password);
      //   // const _phone_number = encry.desencrypter(response.rows[0].phonenumber).trim();

      //   // const smsrepsonse = await service.GetService(
      //   //   config.endpoint,
      //   //   `username=${_username}&password=${_password}&phonenumber=${_phone_number}&message=Código de ingreso a tu portal autoservicio ${code}`
      //   // );
      //   //.log(JSON.stringify(smsrepsonse.data));
      // }
    }
  } catch (error) {
    loggerPg.error(error.message);
  }
  return isValid;
}

async function GetPositionByScreen(id) {
  let row = [];
  try {
    //const query = `select fkidposicion as idposicion from  public.pantallaposicion where fkidpantalla = ${id}`;

    const query = `select fkidposicion as idposicion 
      from  public.pantallaposicion as pp
      inner join public.pantalla as p
      on pp.fkidpantalla = p.id
      where p.serial = '${id}'`;

    const response = await client.query(query);
    if (response.rowCount > 0) {
      row = response.rows;
    }
  } catch (error) {
    loggerPg.error(error.message);
  }
  return row;
}

async function GetLastAuthorizations(screendid) {
  let authorizations = [];
  try {
    const query = `select 
                        a.id as IdAutorizacion,
                        a.fkidposicion,
                        a.fkidmanguera,
                        p.numposicion,
                        m.nummanguera,
                        m.fkidproducto,
                        m.producto,
                        a.programacion,
                        a.valorabonado,
                        a.valorpendiente,
                        a.precio,
                        c.identificador,
                        TO_CHAR(a.fecharegistro, 'YYYY-MM-DD HH24:MI:SS') as fecharegistro,
                        COALESCE(a.fkidventa,-1) as IdVenta
                        from public.autorizacion as a 
                        inner join posicion as p
                        on a.fkidposicion = p.id
                        inner join manguera as m
                        on a.fkidmanguera = m.id
                        inner join cliente as c
                        on a.fkidcliente = c.id
                        where COALESCE(a.fkidventa,-1) = -1 and valorabonado = programacion and a.fkidposicion = ${screendid}
                        order by a.fecharegistro desc limit 100;`;
    const response = await client.query(query);
    if (response.rowCount > 0) {
      authorizations = response.rows;
    }
  } catch (error) {
    loggerPg.error(error.message);
  }
  return authorizations;
}

async function GetLastProgramations(id) {
  let authorizations = [];
  try {
    const query = `select 
                        a.id as IdAutorizacion,
                        p.numposicion,
                        m.nummanguera,
                        m.producto,
                        a.programacion,
                        a.valorabonado,
                        a.valorpendiente,
                        a.precio,
                        c.identificador,
                        TO_CHAR(a.fecharegistro, 'YYYY-MM-DD HH24:MI:SS') as fecharegistro
                        
                        --COALESCE(a.fkidventa,0) as IdVenta
                        from public.autorizacion as a 
                        inner join posicion as p
                        on a.fkidposicion = p.id
                        inner join manguera as m
                        on a.fkidmanguera = m.id
                        inner join cliente as c
                        on a.fkidcliente = c.id
                        where valorabonado != programacion and a.fkidventa is null and a.fkidposicion = ${id}
                        order by a.fecharegistro desc limit 20;`;

    const response = await client.query(query);
    if (response.rowCount > 0) {
      authorizations = response.rows;
    }
  } catch (error) {
    loggerPg.error(error.message);
  }
  return authorizations;
}

async function GetLastSale(id) {
  let sales = [];
  try {
    const query = `select 
                    v.id as idventa,
                    a.id as idautorizacion,
                    id_posicion as posicion,
                    grado as manguera,
                    preset as programacion,
                    m.producto,
                    COALESCE(venta_dinero,0) as dinero,
                    COALESCE(ROUND((venta_volumen / 1000.0)::numeric, 3), 0) as volumen,
                    case when sincro_m = 0 then 'Despachando' 
                    when sincro_m = 1 then 'Finalizado'
                    when sincro_m = 2 then 'Reportada'
                    when sincro_m = 3 then 'Error en el reporte'
                    when sincro_m = 4 then 'Venta Zero'
                    when sincro_m = 5 then 'Venta Facturada'
                    else 'Calibracion' end Estado,
                    TO_CHAR(fechainicial, 'YYYY-MM-DD HH24:MI:SS') as fechainicial,
                    TO_CHAR(fechafinal, 'YYYY-MM-DD HH24:MI:SS') as fechafinal
                    from venta_m  as v
                    inner join programacion as p
                    on v.id_preset = p.id
                    inner join autorizacion as a
                    on a.id = p.fkidautorizacion
                    inner join manguera as m
                    on a.fkidmanguera = m.id	
                    where sincro_m <> 4 and a.fkidposicion = ${id}
                    order by v.fechafinal desc limit 100;`;

    const response = await client.query(query);
    if (response.rowCount > 0) {
      sales = response.rows;
    }
  } catch (error) {
    loggerPg.error(error.message);
  }
  return sales;
}

async function GetPaymentByAuthorization(id) {
  let payment = [];
  try {
    const query = ` select 
                    tp.id as IdPago,
                    fkidautorizacion as IdAutorizacion,
                    a.programacion,
                    valor,
                    tp.fkidestadotransaccion idestado,
                    COALESCE (fp.formapago,tp.respuestapago) as formapago,
                    et.estado,
                    TO_CHAR(tp.fechatransaccion, 'YYYY-MM-DD HH24:MI:SS') as fechatransaccion
                    from transaccionpago as tp
                    inner join autorizacion as a
                    on a.id = tp.fkidautorizacion
                    left outer join public.formapago as fp
                    on fp.id = tp.fkidformapago and a.fkidposicion = fp.fkidposicion
                    inner join public.estadotransaccion as et
                    on et.id = tp.fkidestadotransaccion
                    where fkidautorizacion = ${id} and tp.fkidestadotransaccion = 2 order by fechatransaccion desc `;

    const response = await client.query(query);
    if (response.rowCount > 0) {
      payment = response.rows;
    }
  } catch (error) {
    loggerPg.error(error.message);
  }
  return payment;
}

async function AuthorizeFuelDispatch(data) {
  let payment = false;
  try {
    InsertLogAuditor(
      `Solicitud autorizar despacho con la siguiente información: ${JSON.stringify(
        data
      )}`
    );
    //Verifica que el código de ingreso sea valido
    const idValidCode = await ValidateCodeLogin(data.Codigo);
    if (!idValidCode) return;

    //Verifica si ya se ha realizado el intento de pago para la autorización
    query = `SELECT COUNT(id) as intentos FROM public.transaccionpago 
    WHERE fkidautorizacion = ${data.IdProgramacion} AND fkidformapago IN (1,2,3,6) AND fkidestadotransaccion IN (3,5);`;
    const response1 = await client.query(query);
    if (response1.rows[0]["intentos"] == 0) return;

    query = `
          UPDATE public.transaccionpago SET fkidestadotransaccion = 5, respuestapago = 'Transación anulada por panel administrativo para autorizar despacho por sistema' 
          WHERE fkidautorizacion = ${data.IdProgramacion} and fkidestadotransaccion <> 2;

        	INSERT INTO public.transaccionpago(
          fkidautorizacion, valor, respuestapago, fkidformapago, fkidestadotransaccion)
          SELECT id,programacion,'${data.Referencia}',${data.IdFormaPago},2 FROM public.autorizacion WHERE id = ${data.IdProgramacion}; 

          UPDATE public.autorizacion SET valorabonado = programacion, valorpendiente = 0, fkidventa = -1 where id = ${data.IdProgramacion};`;

    const response2 = await client.query(query);
    if (response2[1].rowCount > 0) {
      InsertLogAuditor(
        `Autorización de despacho realizada: ${JSON.stringify(data)}`
      );
      payment = true;
    }
  } catch (error) {
    loggerPg.error(error.message);
  }
  return payment;
}

async function GetAllPaymentById(datareport) {
  let listPayment = [];

  const id = datareport.MetodoPago;

  const idPaymen =
    id === 1 ? "1" : id === 2 ? "2" : id === 3 ? "3,6" : id === 4 ? "5" : 0;

  try {
    const query = `SELECT id as idpago,
        fkidautorizacion as idautorizacion,
        valor,
        respuestapago,
        TO_CHAR(fechatransaccion, 'YYYY-MM-DD HH24:MI:SS') as fechatransaccion        
          FROM transaccionpago 
          WHERE fkidestadotransaccion = 2 and fkidformapago IN(${idPaymen}) and fechatransaccion between '${datareport.FechaIni}' and '${datareport.FechaFin}'
          order by 1 desc limit 500;`;

    const response = await client.query(query);
    if (response.rowCount > 0) {
      listPayment = response.rows;
    }
  } catch (error) {
    loggerPg.error(error.message);
  }
  return listPayment;
}

async function GetArching() {
  let arqueo = [];

  try {
    let query = `select id,
        TO_CHAR(fechainicial, 'YYYY-MM-DD HH24:MI:SS') as fechainicial,
        TO_CHAR(fechafinal, 'YYYY-MM-DD HH24:MI:SS') as fechafinal
        from turnomodulo where activo = true and asyncdominus = false
        order by 1 desc limit 1;`;

    const response1 = await client.query(query);
    if (response1.rowCount > 0) {
      query = `
          select 
          v.id_posicion as idPosicion,
          m.producto,
          SUM(venta_dinero)as totaldinero,
          COALESCE(ROUND((SUM(venta_volumen) / 1000.0)::numeric, 3), 0) as totalvolumen
          from venta_m as v
          inner join autorizacion as a
          on a.fkidventa = v.id
          inner join manguera as m
          on m.fkidposicion = a.fkidposicion and  m.id = a.fkidmanguera
          where fechafinal between '${response1.rows[0].fechainicial}' and '${response1.rows[0].fechafinal}' and sincro_m IN (5,2)
          group by v.id_posicion,m.producto;`;

      const response2 = await client.query(query);
      if (response2.rowCount > 0) {
        arqueo = response2.rows;
      }
    }
  } catch (error) {
    loggerPg.error(error.message);
  }
  return arqueo;
}

async function GetTotalPayment(datareport) {
  let listPayment = [];

  const id = datareport.MetodoPago;

  const idPaymen =
    id === 1 ? "1" : id === 2 ? "2" : id === 3 ? "3,6" : id === 4 ? "5" : 0;

  try {
    // const query = `SELECT SUM(valor) as total, fp.formapago
    // FROM transaccionpago as tp
    // INNER JOIN autorizacion as a
    // ON tp.fkidautorizacion = a.id
    // INNER JOIN formapago as fp
    // ON tp.fkidformapago = fp.id and a.fkidposicion = fp.fkidposicion
    // WHERE fkidestadotransaccion = 2 and fkidformapago IN(${idPaymen}) and fechatransaccion between '${datareport.FechaIni }' and '${datareport.FechaFin }'
    // GROUP BY fp.formapago`;

    const query = `SELECT SUM(valor) as total
        FROM transaccionpago as tp
        INNER JOIN autorizacion as a
        ON tp.fkidautorizacion = a.id
        INNER JOIN formapago as fp
        ON tp.fkidformapago = fp.id and a.fkidposicion = fp.fkidposicion
        WHERE fkidestadotransaccion = 2 and fkidformapago IN(${idPaymen}) and fechatransaccion between '${datareport.FechaIni}' and '${datareport.FechaFin}';`;

    const response = await client.query(query);
    if (response.rowCount > 0) {
      listPayment = response.rows;
    }
  } catch (error) {
    loggerPg.error(error.message);
  }
  return listPayment;
}

async function GetAvailableProducto(item) {
  let listProducts = [];

  try {
    const query = `select id as idmanguera,fkidposicion,fkidproducto,producto 
    from manguera where fkidposicion = ${item.idposicion} and fkidproducto <> ${item.idproducto};`;

    const response = await client.query(query);
    if (response.rowCount > 0) {
      listProducts = response.rows;
    }
  } catch (error) {
    loggerPg.error(error.message);
  }
  return listProducts;
}

async function CancelAuthorization(id) {
  let isCancel = false;
  try {
    //Tener en cuenta que cuando se deja en fkidventa = -2 es porque se anuló desde pantalla
    const query =
      "UPDATE public.autorizacion SET fkidventa = -2 WHERE id = " + id + ";";
    const response = await client.query(query);
    if (response.rowCount > 0) {
      isCancel = true;
    }
  } catch (error) {
    console.log(error.message);
  }
  return isCancel;
}

async function ReleasePendingBalance(data) {
  let isRelease = false;
  try {
    const isValidCode = await ValidateCodeLogin(data.codigo);
    if (!isValidCode) return;

    // obtener el id cliente y autorizacion de transferencia de saldo
    let query =
      "SELECT id,valor,fkidautorizacion,fkidcliente FROM public.transferenciasaldo WHERE id = " +
      data.idtransferencia +
      " AND sincronizado = 6 ;";

    const response0 = await client.query(query);
    if (response0.rowCount === 0) return;

    // Verificar si el cliente ya existe en la tabla de clientes
    query = `SELECT id FROM public.cliente WHERE identificador= '${data.identificador}';`;
    const response1 = await client.query(query);
    if (response1.rowCount > 0) {
      query = `UPDATE public.transferenciasaldo SET fkidcliente = ${response1.rows[0].id} WHERE id = ${data.idtransferencia};
                UPDATE public.autorizacion SET fkidcliente = ${response1.rows[0].id} WHERE id = ${response0.rows[0].fkidautorizacion};`;
    } else {
      query = `UPDATE public.cliente SET identificador = '${data.identificador}' WHERE id = ${response0.rows[0].fkidcliente};`;
    }
    await client.query(query);

    query = `UPDATE public.transferenciasaldo 
      SET sincronizado = 0, fkidformapago = ${data.iddestino}
      WHERE sincronizado = 6 and id = ${data.idtransferencia};`;
    const response = await client.query(query);
    if (response.rowCount > 0) {
      isRelease = true;
    }
  } catch (error) {
    console.log(error.message);
  }
  return isRelease;
}

async function GetAdministratorInformation() {
  let data = [];
  try {
    const query = `SELECT id,username,phonenumber,correo FROM public.usuario WHERE activo = true;`;

    const response = await client.query(query);
    if (response.rowCount > 0) {
      data = response.rows;
    }
  } catch (error) {
    loggerPg.error(error.message);
  }
  return data;
}

async function UpdateLoginCodeAdministrator(id, code) {
  let isUpdate = false;
  try {
    const query = `UPDATE public.usuario SET logincode = '${encry.encrypter(
      code
    )}' WHERE activo = true and id = ${id};`;
    const response = await client.query(query);
    if (response.rowCount > 0) {
      isUpdate = true;
    }
  } catch (error) {
    console.log(error.message);
  }
  return isUpdate;
}

// async function ChangeProductToAuthorization(item) {
//   let isChange = false;

//   try {
//     InsertLogAuditor(
//       `Solicitud cambio de producto con la siguiente información: ${JSON.stringify(
//         item
//       )}`
//     );

//     let query = `SELECT id FROM public.usuario WHERE logincode = '${item.codigo}'`;

//     const response = await client.query(query);
//     if (response.rowCount > 0) {
//       query = `
//                   select fkidposicion as idposicion,
//                   id as idmanguera,
//                   fkidproducto as idproducto,
//                   precio
//                   from manguera where id = ${item.idmanguera};`;

//       const response1 = await client.query(query);
//       if (response1.rowCount > 0) {
//         const _hose = response1.rows[0];
//         query = `
//           UPDATE public.autorizacion SET fkidventa = 0 WHERE id = ${item.idautorizacion};
//           INSERT INTO public.autorizacion(
//           fkidposicion, fkidmanguera, fkidproducto, idterminal, precio, programacion, valorabonado, valorpendiente, fkidcliente, fecharegistro)
//           SELECT ${_hose.idposicion}, ${_hose.idmanguera}, ${_hose.idproducto}, idterminal,${_hose.precio},programacion,0,programacion ,fkidcliente, now() FROM autorizacion where id =${item.idautorizacion}
//           RETURNING Id;`;

//         const response2 = await client.query(query);
//         if (response2[1].rowCount > 0) {
//           const newId = response2[1].rows[0].id;

//           InsertLogAuditor(
//             `Solicitud cambio de producto autorizada con el id = ${newId}`
//           );

//           query = `

//               UPDATE public.autorizacion SET valorabonado=programacion,valorpendiente = 0,fkidventa=-1 WHERE id = ${newId};

//               UPDATE public.transaccionpago SET fkidautorizacion = ${newId} WHERE fkidautorizacion = ${item.idautorizacion};`;

//           const response3 = await client.query(query);
//           if (response3[0].rowCount > 0) {
//             InsertLogAuditor(`Solicitud cambio de producto completada`);
//             isChange = true;
//           }
//         }
//       }
//     } else {
//       InsertLogAuditor(`Código ${item.codigo} de ingreso no valido.`);
//     }
//   } catch (error) {
//     loggerPg.error(error.message);
//   }
//   return isChange;
// }

async function GetBalanceTransfer(id) {
  let listBalance = [];
  try {
    // const query = `select
    //               v.id as Venta,
    //               a.programacion,
    //               v.venta_dinero as Dinero,
    //               ts.valor as Saldo,
    //               ts.id as IdTransferencia,
    //               c.identificador,
    //               fp.formapago,
    //               ts.sincronizado,
    //               TO_CHAR(ts.fecharegistro, 'YYYY-MM-DD HH24:MI:SS') as fecharegistro
    //               from public.transferenciasaldo as ts
    //               inner join public.autorizacion as a
    //               on ts.fkidautorizacion = a.id
    //               inner join public.venta_m as v
    //               on v.id = a.fkidventa
    //               inner join public.cliente as c
    //               on c.id = ts.fkidcliente
    //               inner join public.formapago as fp
    //               on a.fkidposicion = fp.fkidposicion and fp.id = ts.fkidformapago
    //               where a.fkidposicion = ${id} order by 1 desc limit 10;`;

    const query = `
                      select  
                      vs.id as Venta,
                      a.programacion,
                      fp_tp.formapago as formapagoorigen, 
                      tp.valor as valortransaccion,
                      v.venta_dinero as Dinero,
                      ts.valor as Saldo,
                      ts.id as IdTransferencia,
                      c.identificador,
                      fp.formapago,
                      ts.sincronizado,
                      TO_CHAR(ts.fecharegistro, 'YYYY-MM-DD HH24:MI:SS') as fecharegistro                      
                      from public.transferenciasaldo as ts
                      inner join public.autorizacion as a
                      on ts.fkidautorizacion = a.id
                      inner join public.venta_sistema as vs
                      on vs.id = a.fkidventa
                      inner join public.venta_m as v
                      on vs.id_venta_m = v.id
                      inner join public.cliente as c
                      on c.id = ts.fkidcliente
                      inner join public.formapago as fp
                      on a.fkidposicion = fp.fkidposicion and fp.id = ts.fkidformapago
                      inner join public.transaccionpago as tp
                      on tp.fkidautorizacion = a.id 
                      inner join public.formapago as fp_tp
                      on fp_tp.id = tp.fkidformapago and fp_tp.fkidposicion = a.fkidposicion and tp.fkidestadotransaccion = 2
                      where a.fkidposicion = ${id} order by 1 desc limit 50;`;

    const response = await client.query(query);
    if (response.rowCount > 0) {
      listBalance = response.rows;
    }
  } catch (error) {
    loggerPg.error(error.message);
  }
  return listBalance;
}

module.exports = {
  GetAvailableScreenId,
  GetPositionByScreen,
  ///
  ValidUserLogin,
  GetLastAuthorizations,
  GetLastProgramations,
  GetLastSale,
  GetPaymentByAuthorization,
  AuthorizeFuelDispatch,
  GetAllPaymentById,
  GetTotalPayment,
  GetArching,
  GetAvailableProducto,
  CancelAuthorization,
  ReleasePendingBalance,
  //ChangeProductToAuthorization,
  GetAdministratorInformation,
  UpdateLoginCodeAdministrator,
  GetBalanceTransfer,
};
