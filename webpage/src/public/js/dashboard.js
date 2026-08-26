window.addEventListener("load", () => {
  const formReportPayment = document.getElementById("formReportePayment");
  formReportPayment.style.display = "none";
  const formReportSale = document.getElementById("formReporteSale");
  formReportSale.style.display = "none";
});

function toggleMenu() {
  const menu = document.getElementById("menuContent");
  menu.classList.toggle("d-none");
}

document
  .getElementById("formReportePayment")
  .addEventListener("submit", function (e) {
    e.preventDefault();
    const fechaIni = formatFechaHora(
      document.getElementById("fechaInicial").value
    );
    const fechaFin = formatFechaHora(
      document.getElementById("fechaFinal").value
    );
    const idmetodo = document.getElementById("metodoPago").value;

    const dataReport = {
      FechaIni: fechaIni,
      FechaFin: fechaFin,
      MetodoPago: parseInt(idmetodo),
    };

    reportePagos(dataReport);
  });

document
  .getElementById("formReporteSale")
  .addEventListener("submit", function (e) {
    e.preventDefault();
    const fechaIni = formatFechaHora(
      document.getElementById("fechaInicial").value
    );
    const fechaFin = formatFechaHora(
      document.getElementById("fechaFinal").value
    );
    const idmetodo = document.getElementById("metodoPago").value;

    const dataReport = {
      FechaIni: fechaIni,
      FechaFin: fechaFin,
      MetodoPago: parseInt(idmetodo),
    };

    reportePagos(dataReport);
  });

async function cargarModulo(modulo) {
  const contenedor = document.getElementById("contenidoDinamico");
  contenedor.innerHTML = "<p>Cargando...</p>";
  const formReportPayment = document.getElementById("formReportePayment");
  formReportPayment.style.display = "none";
  const formReportSale = document.getElementById("formReporteSale");
  formReportSale.style.display = "none";
  const contenedorReport = document.getElementById("resultadoReporte");
  contenedorReport.innerHTML = "";
  const position = parseInt(document.getElementById("idposicion").innerText);

  try {
    if (modulo === "reportespagos") {
      formReportPayment.style.display = "flex";
      contenedor.innerHTML = '<h2 class="mb-4">Reporte Pagos</h2>';
      return;
    }

    if (modulo === "reportesventas") {
      formReportSale.style.display = "flex";
      contenedor.innerHTML = '<h2 class="mb-4">Reporte Ventas</h2>';
      return;
    }

    const res = await fetch(`/${modulo}?id=${position}`);
    const data = await res.json();
    console.log(data);

    if (modulo === "autorizaciones") {
      let html = `<h2>Autorizaciones</h2>


        <div clas="row" style="overflow: scroll; width: 100%;height:600px ">
          <table class="table table-striped table-hover">
            <thead>
            <tr style="text-align:center;font-size:small">
            <th>Autorización</th>           
            <th>Producto</th>
            <th>Programación</th>
            <th>Valor Abonado</th>
            <th>Precio</th>
            <th>Identificador</th>
            <th>Fecha Registro</th>
            <th>Pagos</th>
            <th>Anular</th>
            </tr>
            </thead>
        <tbody style="font-size:small">`;
      // <th>Cambiar Producto</th>
      data.forEach((item) => {
        html += `<tr style="font-size:small; text-align:center">
            <td>${item.idautorizacion}</td>
            <td>${item.producto}</td>
            <td>$ ${item.programacion}</td>
            <td>$ ${item.valorabonado}</td>
          
            <td>$ ${item.precio}</td>
            <td>${item.identificador}</td>
            <td>${item.fecharegistro}</td>
            <td><button class="btn btn-success" onclick="verpagosautorizacion(${item.idautorizacion})">Ver</button></td>
            <td><button class="btn btn-danger" onclick="mostrarModalCancelarAutorizacion(${item.idautorizacion})">Anular</button></td>
          </tr>`;
        //<td><button class="btn btn-info" onclick="cambiarproducto(${item.fkidposicion}, ${item.fkidproducto}, ${item.idautorizacion})">Cambiar</button></td>
      });

      html += `</tbody></table></div>`;
      contenedor.innerHTML = html;
    }

    if (modulo === "programaciones") {
      let html = `<h2>Programaciones pendientes</h2>

        <div clas="row" style="overflow: scroll; width: 100%;height:600px ">
          <table class="table table-striped table-hover">
            <thead>
            <tr style="text-align:center;font-size:small">
            <th>Autorización</th>
            <th>Producto</th>
            <th>Programación</th>
            <th>Valor Abonado</th>
            <th>Valor Pendiente</th>
            <th>Precio</th>
            <th>Identificador</th>
            <th>Fecha Registro</th>
            <th>Autorizar</th>
            </tr>
            </thead>
        <tbody style="font-size:small">`;

      data.forEach((item) => {
        html += `<tr style="text-align:center;font-size:small">
            <td>${item.idautorizacion}</td>
            <td>${item.producto}</td>
            <td>$ ${item.programacion}</td>
            <td>$ ${item.valorabonado}</td>
            <td>$ ${item.valorpendiente}</td>
            <td>$ ${item.precio}</td>
            <td>${item.identificador}</td>
            <td>${item.fecharegistro}</td>
            <td><button class="btn btn-success" onclick="confirmarAutorizacion(${item.idautorizacion})">Autorizar</button></td>
          </tr>`;
      });

      html += `</tbody></table></div>`;
      contenedor.innerHTML = html;
    }

    if (modulo === "ventas") {
      let html = `<h2>Últimas ventas</h2>

        <div clas="row" style="overflow: scroll; width: 100%;height:600px ">
          <table class="table table-striped table-hover">
            <thead>
            <tr style="text-align:center;font-size:small">
            <th>Venta</th>
            <th>Producto</th>
            <th>Programación</th>
            <th>Dinero</th>
            <th>Volumen</th>
            <th>Estado</th>
            <th>Fecha Inicial</th>
            <th>Fecha Final</th>
            <th>Pagos</th>
            </tr>
            </thead>
        <tbody style="font-size:small">`;

      data.forEach((item) => {
        html += `<tr style="text-align:center;font-size:small">
            <td>${item.idventa}</td>
            <td>${item.producto}</td>
            <td>$ ${item.programacion}</td>
            <td>$ ${item.dinero}</td>
            <td>${item.volumen} G</td>
            <td>${item.estado}</td>
            <td>${item.fechainicial}</td>
            <td>${item.fechafinal}</td>
            <td><button class="btn btn-success" onclick="verpagosautorizacion(${item.idautorizacion})">Ver</button></td>
          </tr>`;
      });

      html += `</tbody></table></div>`;
      contenedor.innerHTML = html;
    }

    if (modulo === "arqueo") {
      let html = `<h2>Arqueo</h2>

        <div clas="row" style="overflow: scroll; width: 100%;">
          <table class="table table-striped table-hover">
            <thead>
            <tr style="text-align:center;font-size:small">
            <th>Producto</th>
            <th>Total Dinero</th>
            <th>Total Volumen</th>
            </tr>
            </thead>
        <tbody style="font-size:small">`;

      data.forEach((item) => {
        html += `<tr>
            <td>${item.producto}</td>
            <td>$ ${item.totaldinero}</td>
            <td>${item.totalvolumen} G</td>
          </tr>`;
      });

      html += `</tbody></table></div>`;
      contenedor.innerHTML = html;
    }

    if (modulo === "transferencia") {
      let html = `<h2>Transferencia Saldos</h2>

        <div clas="row" style="overflow: scroll; width: 100%;">
          <table class="table table-striped table-hover">
            <thead>
            <tr style="text-align:center;font-size:small">
            <th>Venta</th>
            <th>Programación</th>
            <th>Forma Pago</th>
            <th>Valor Transacción</th>
            <th>Dinero</th>
            <th>Saldo</th>
            <th>Número Contacto</th>
            <th>Cuenta</th>
            <th>Estado</th>
            <th>FechaRegistro</th>
            <th>Liberar saldo</th>
            </tr>
            </thead>
        <tbody style="font-size:small">`;

      let idTransactionBalance = 0;

      data.forEach((item) => {
        idTransactionBalance = item.sincronizado;
console.log(JSON.stringify(item));
        const isSend =
        idTransactionBalance == 0
            ? "En espera de envío":
          idTransactionBalance == 1
            ? "Pendiente"
            : idTransactionBalance == 2
            ? "Enviado"
            : idTransactionBalance == 3
            ? "Error en el envio"
            : idTransactionBalance == 4
            ? "Saldo reportado"
            : idTransactionBalance == 6
            ? "Saldo pendiente por enviar"
            : "Error en el reporte";

        html += `<tr style="font-size:small;text-align:center ;color:${
          idTransactionBalance == 6 ? "#B32104FF" : "black"
        }">
            <td>${item.venta}</td>
            <td>$ ${item.programacion}</td>
            <td>$ ${item.formapagoorigen}</td>
            <td>$ ${item.valortransaccion}</td>
            <td>$ ${item.dinero} </td>
            <td>$ ${item.saldo} </td>
            <td>${item.identificador} </td>
            <td>${item.formapago} </td>
            <td>${isSend} </td>
            <td>${item.fecharegistro} </td>
            <td><button class="btn btn-primary" style="visibility:${idTransactionBalance==6?'visible':'hidden'}"
             onclick="liberarsaldopendiente(${item.idtransferencia},${item.saldo},${item.identificador})">Liberar</button></td>
          </tr>`;
      });

      html += `</tbody></table></div>`;
      contenedor.innerHTML = html;
    }
    // Aquí puedes agregar lógica para usuarios, pagos, etc.
  } catch (err) {
    contenedor.innerHTML = "<p>Error al cargar el módulo.</p>";
    console.error(err);
  }
}

let idSeleccionado = 0;

async function confirmarAutorizacion(id) {
  idSeleccionado = id;
  console.log(`ID seleccionado para autorizar: ${idSeleccionado}`);
  const modalcode = new bootstrap.Modal(
    document.getElementById("modalloadingcode")
  );
  modalcode.show();

  await requestSendVerificationCode().then((e) => {
    console.log(e);
    modalcode.hide();
    console.log("Código de verificación enviado");
    document.getElementById("modalIdAutorizacion").innerText = id;
    document.getElementById("logincodeAuthorization").value = "";
    const modal = new bootstrap.Modal(
      document.getElementById("modalConfirmarAutorizacion")
    );
    modal.show();
  });
}





async function requestSendVerificationCode() {
  try {
    const res = await fetch("/verificatiocodesms", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: null,
    });

    const result = await res.json();

    if (result.success) {
      console.log(JSON.stringify(result));
    } else {
      alert("Error al confirmar autorización");
    }
  } catch (error) {
    alert("Error de red o servidor");
    console.error(error);
  }
}

// async function cambiarproducto(idpos,idprod,idauto) {
//   idSeleccionado = idauto;
//   const contenedor = document.getElementById('resultadoReporte');
//   contenedor.innerHTML = "";
//   const spinner = document.getElementById('spinnerloading');
//   spinner.style.display = "block";
//   const ddl = document.getElementById('ddlproductocontent');
//   const fieldautorizacion = document.getElementById('idautorizacion');
//   document.getElementById("logincodecp").value= "";
//   try {
//     const res = await fetch('/listarproductodisponible', {
//       method: 'POST',
//       headers: { 'Content-Type': 'application/json' },
//       body: JSON.stringify({ item: {idposicion:idpos,idproducto:idprod} })
//     });

//     const data = await res.json();

//       let html = `<select id="productodisponible" class="form-select" required>`;
//               data.forEach(item=>{
//                 html +=`<option value="${item.idmanguera}"> ${item.producto}</option>`;
//               });
//             html += `</select>`;

//       ddl.innerHTML = html;
//       const modal = new bootstrap.Modal(document.getElementById("modalCambioProducto"));
//       modal.show();

//       fieldautorizacion.innerText = idSeleccionado;

//   } catch (error) {
//     alert('Error de red o servidor');
//     console.error(error);
//   }
//   finally{
//    spinner.style.display = "none";
//   }

// }

let idAutorizacionCancelar = 0;
async function mostrarModalCancelarAutorizacion(id) {
  idAutorizacionCancelar = id;
  console.log(`ID seleccionado para autorizar: ${idSeleccionado}`);
  document.getElementById("idautorizacioncancelar").innerText = id;
  const modalcode = new bootstrap.Modal(
    document.getElementById("modalCancelarAutorizacion")
  );
  modalcode.show();
}





async function anularautorizacion() {
  const contenedor = document.getElementById("contenidoDinamico");
  const spinner = document.getElementById("spinnerloading");
  contenedor.style.display = "none";
  spinner.style.display = "block";
  try {
    const res = await fetch("/anularautorizacion", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id: idAutorizacionCancelar }),
    });

    const data = await res.json();
    alert(data.message);
    cargarModulo("autorizaciones");
  } catch (error) {
    alert("Error de red o servidor");
    console.error(error);
  } finally {
    const modal = bootstrap.Modal.getInstance(
      document.getElementById("modalCancelarAutorizacion")
    );
    modal.hide();
    contenedor.style.display = "block";
    spinner.style.display = "none";
  }
}



let idTransferenciaSaldo = 0;
let saldoTransferencia = 0;
let identificadorTransferencia = 0;

async function liberarsaldopendiente(id,saldo,identificador) {
  idTransferenciaSaldo = id;
  saldoTransferencia = saldo;
  identificadorTransferencia = identificador;

  console.log(`ID seleccionado para transferencia : ${idTransferenciaSaldo}`);
  const modalcode = new bootstrap.Modal(
    document.getElementById("modalloadingcode")
  );
  modalcode.show();


  
  await requestSendVerificationCode().then((e) => {
    console.log(e);
    modalcode.hide();
    console.log("Código de verificación enviado");
    document.getElementById("telefonotransferencia").value =identificador ;
    document.getElementById("saldotransferencia").value = saldo;
    document.getElementById("logincodeBalance").value = "";
    const modal = new bootstrap.Modal(
      document.getElementById("modalLiberarSaldo")
    );
    modal.show();
  });
}


async function enviarLiberacionSaldo(){


  const idDestinationBalance = document.getElementById('billeteradestino').value;
  if(idDestinationBalance == 0) return;

  const bodyrequest = {
    idtransferencia: idTransferenciaSaldo,
    iddestino : idDestinationBalance,
    identificador:document.getElementById("telefonotransferencia").value,
    codigo: document.getElementById("logincodeBalance").value,
  };

  try {
    const res = await fetch("/liberarsaldopendiente", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(bodyrequest),
    });

    const result = await res.json();

    if (result.success) {
      alert("Saldo liberado con éxito, su saldo será enviado en los próximos 5 minutos");
      const modal = bootstrap.Modal.getInstance(
        document.getElementById("modalLiberarSaldo")
      );
      modal.hide();
      cargarModulo("transferencia"); // recarga tabla
    } else {
      alert("Error al liberar el saldo pendiente");
    }
  } catch (error) {
    alert("Error de red o servidor");
    console.error(error);
  }


}

async function verpagosautorizacion(id) {
  const contenedor = document.getElementById("contenidoDinamico");
  const spinner = document.getElementById("spinnerloading");

  contenedor.style.display = "none";
  spinner.style.display = "block";

  try {
    const res = await fetch("/pagosautorizacion", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id: id }),
    });

    const data = await res.json();

    let html = `
        <div clas="row" style="overflow: scroll; width: 100%; height:200px">
          <table class="table table-striped table-hover">
            <thead>
            <tr>
            <th>Pago</th>
            <th>Valor</th>
            <th>Forma pago</th>
            <th>Estado</th>
            <th>Fecha Transaccion</th>
            </tr>
            </thead>
        <tbody>`;

    data.forEach((item) => {
      const bgcolor = item.idestado === 3 ? "red" : "#f8f9fa";
      const color = item.idestado === 3 ? "white" : "black";
      html += `<tr style="background-color: ${bgcolor}; color: ${color}">
            <td>${item.idpago}</td>
            <td>$ ${item.valor}</td>
            <td>${item.formapago}</td>
            <td>${item.estado}</td>
            <td>${item.fechatransaccion}</td>
          </tr>`;
    });

    html += `</tbody></table></div>`;

    document.getElementById("bodylistpayment").innerHTML = html;
    const modal = new bootstrap.Modal(document.getElementById("modalpayment"));
    modal.show();
  } catch (error) {
    alert("Error de red o servidor");
    console.error(error);
  } finally {
    contenedor.style.display = "block";
    spinner.style.display = "none";
  }
}

async function enviarConfirmacionAutorizacion() {
  const idformapago = document.getElementById("formapagoprogramacion").value;
  const referencia = document.getElementById("referencia");

  if (referencia.selectedIndex == 0 || idformapago == 0) {
    alert("Referencia de pago o forma de pago no seleccionada");
    return;
  }

  const textReferencia = referencia.options[referencia.selectedIndex].text;
  const code = document.getElementById("logincodeAuthorization").value;

  const bodyrequest = {
    IdProgramacion: idSeleccionado,
    IdFormaPago: idformapago,
    Referencia: textReferencia,
    Codigo: code,
  };

  try {
    const res = await fetch("/autorizardespacho", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(bodyrequest),
    });

    const result = await res.json();

    if (result.success) {
      alert("Autorización confirmada con éxito");
      const modal = bootstrap.Modal.getInstance(
        document.getElementById("modalConfirmarAutorizacion")
      );
      modal.hide();
      cargarModulo("autorizaciones"); // recarga tabla
    } else {
      alert("Error al confirmar autorización");
    }
  } catch (error) {
    alert("Error de red o servidor");
    console.error(error);
  }
}

// async function confirmacambioproducto() {

//   const ddlmanguera = parseInt(document.getElementById('productodisponible').value);

//   const code = document.getElementById('logincodecp').value;

//   console.log(ddlmanguera);

//    try {
//     const res = await fetch('/cambioproducto', {
//       method: 'POST',
//       headers: { 'Content-Type': 'application/json' },
//       body: JSON.stringify({ item: {idautorizacion:idSeleccionado,idmanguera: ddlmanguera,codigo: code} })
//     });

//     const result = await res.json();

//     if (result.success) {
//       alert('Cambio de producto realizado con éxito');
//       const modal = bootstrap.Modal.getInstance(document.getElementById("modalCambioProducto"));
//       modal.hide();
//       cargarModulo('autorizaciones'); // recarga tabla
//     } else {
//       alert('Error al confirmar autorización');
//     }

//   } catch (error) {
//     alert('Error de red o servidor');
//     console.error(error);
//   }
// }

async function reportePagos(datarequest) {
  const contenedor = document.getElementById("resultadoReporte");
  contenedor.innerHTML = "";
  const spinner = document.getElementById("spinnerloading");
  spinner.style.display = "block";

  try {
    const res = await fetch("/reportePagos", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ data: datarequest }),
    });

    const result = await res.json();

    if (result.success) {
      const _data = result.content.listpayment;
      console.log(result.content.listpayment);

      let html = `
        <div class="row" style="text-alig:center;margin:auto">
          <div class="col col-lg-12">
          <h2>Total pagos: $${result.content.totalpayment[0].total}</h2>
          </div>
        

            <div clas="col col-lg-12" style="overflow: scroll; width: 100%; height:500px">
              <table class="table table-striped table-hover">
                <thead>
                <tr>
                <th>Pago</th>
                <th>Autorizacion</th>
                <th>Valor</th>
                <th>Fecha Transacción</th>
                </tr>
                </thead>
            <tbody>`;

      _data.forEach((item) => {
        html += `<tr>
                <td>${item.idpago}</td>
                <td>${item.idautorizacion}</td>
                <td>$ ${item.valor}</td>
                <td>${item.fechatransaccion}</td>
              </tr>`;
      });

      html += `</tbody></table></div>`;
      html += `</div>`;
      contenedor.innerHTML = html;
    } else {
      alert("Error en la consulta, no se encuentra información");
    }
  } catch (error) {
    alert("Error de red o servidor");
    console.error(error);
  } finally {
    spinner.style.display = "none";
  }
}

function formatFechaHora(datetimeValue) {
  const date = new Date(datetimeValue);
  const dd = String(date.getDate()).padStart(2, "0");
  const mm = String(date.getMonth() + 1).padStart(2, "0"); // Meses comienzan en 0
  const yyyy = date.getFullYear();
  const hh = String(date.getHours()).padStart(2, "0");
  const mi = String(date.getMinutes()).padStart(2, "0");
  const ss = "00"; // No hay segundos disponibles directamente

  return `${yyyy}-${mm}-${dd} ${hh}:${mi}:${ss}`;
}
