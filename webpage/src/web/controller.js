const querypg = require("../../data/web/query");
const path = require("path");
const fs = require("fs");
const encry = require("../../../utils/encrypter");
const service = require("../services/sms/sms");
const config = require("../services/sms/configuration").config;
const charactersCode =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
const email = require("../services/email/email");

const login = async (req, res) => {
  const { user, password, screenid } = req.body;

  console.log("Datos recibidos:", { user, password, screenid });
  // Simulación de validación (puedes consultar base de datos aquí)
  const userValido = await querypg.ValidUserLogin(user, password, screenid);
  const isValidScreenId = await querypg.GetAvailableScreenId(screenid);

  console.log("Validación:", { userValido, isValidScreenId });
  if (userValido && isValidScreenId) {
    res.json({ success: true });
  } else {
    res.json({ success: false });
  }
};

const index = async (req, res) => {
  const { id } = req.query;
  res.render("index", { estilo: "login", titulo: "Index", idpantalla: id });
};

const home = async (req, res) => {
  const { id } = req.query;

  const isValidScreenId = await querypg.GetPositionByScreen(id);

  if (!isValidScreenId) {
    return res.render("index", {
      estilo: "login",
      titulo: "Index",
      idpantalla: id,
    });
  }
  console.log("Llamando página homecon id pantalla:", id);
  res.render("home", {
    estilo: "dashboard",
    titulo: "Dashboard",
    usuario: "Administrador",
    idposicion: isValidScreenId[0].idposicion,
  }); // Puedes pasar datos dinámicos aquí
};

const autorizaciones = async (req, res) => {
  const { id } = req.query;
  const list = await querypg.GetLastAuthorizations(id);
  console.log(JSON.stringify(list));
  res.json(list);
};

const programaciones = async (req, res) => {
  const { id } = req.query;
  const list = await querypg.GetLastProgramations(id);
  console.log(JSON.stringify(list));
  res.json(list);
};

const ventas = async (req, res) => {
  const { id } = req.query;
  const list = await querypg.GetLastSale(id);
  console.log(JSON.stringify(list));
  res.json(list);
};

const pagosautorizacion = async (req, res) => {
  const { id } = req.body;
  const list = await querypg.GetPaymentByAuthorization(id);
  console.log(JSON.stringify(list));
  res.json(list);
};

const autorizardespacho = async (req, res) => {
  try {
    const bodyAuth = req.body;
    console.log("Autorización confirmada:", bodyAuth.IdProgramacion);

    const isUpdate = await querypg.AuthorizeFuelDispatch(bodyAuth);
    res.json({ success: isUpdate });
  } catch (error) {
    console.log(error);
  }
};

const reportePagos = async (req, res) => {
  const { data } = req.body;
  console.log("Autorización confirmada:", data);

  const lisPayment = await querypg.GetAllPaymentById(data);
  console.log(JSON.stringify(lisPayment));

  const totalPayment = await querypg.GetTotalPayment(data);

  if (lisPayment.length > 0) {
    return res.json({
      success: true,
      content: { listpayment: lisPayment, totalpayment: totalPayment },
    });
  }

  res.json({ success: false });
};

const arqueo = async (req, res) => {
  const { id } = req.query;
  const listSale = await querypg.GetArching();
  console.log(JSON.stringify(listSale));
  res.json(listSale);
};

const transferencias = async (req, res) => {
  const { id } = req.query;
  const listSale = await querypg.GetBalanceTransfer(id);
  console.log(JSON.stringify(listSale));
  res.json(listSale);
};

const listarproductodisponible = async (req, res) => {
  const { item } = req.body;
  console.log("Autorización confirmada:", item);
  const availableProduct = await querypg.GetAvailableProducto(item);

  res.json(availableProduct);
};

const anularautorizacion = async (req, res) => {
  const { id } = req.body;

  const isDeleted = await querypg.CancelAuthorization(id);
  res.json({
    success: isDeleted,
    message: isDeleted
      ? "Autorización anulada correctamente."
      : "No se pudo anular la autorización.",
  });
};

const liberarsaldopendiente = async (req, res) => {
  const dataBalance = req.body;

  const isReleased = await querypg.ReleasePendingBalance(dataBalance);
  res.json({
    success: isReleased,
    message: isReleased
      ? "Saldo pendiente liberado correctamente."
      : "No se pudo liberar el saldo pendiente.",
  });
};

const verificatiocodesms = async (req, res) => {
  const response = await querypg.GetAdministratorInformation();
  if (response.rowCount === 0) return res.json({ success: false });

  const code = GenerateLoginCode();

  const isUpdate = await querypg.UpdateLoginCodeAdministrator(
    response[0].id,
    code,
  );
  if (!isUpdate) return res.json({ success: false });

  const _username = encry.desencrypter(config.username).trim();
  const _password = encry.desencrypter(config.password);
  const _phone_number = encry.desencrypter(response[0].phonenumber).trim();

  try {
    const smsresponse = await service.GetService(
      config.endpoint,
      `username=${_username}&password=${_password}&phonenumber=${_phone_number}&message=Código de ingreso a tu portal autoservicio ${code}`,
    );
    console.log(JSON.stringify(smsresponse.data));

    if (smsresponse == undefined) return res.json({ success: false });
  } catch (error) {
    console.error(`Error notificación SMS: ${error.message}`);
  }

  try {
    await email.emailNotification(
      encry.desencrypter(response[0].correo).trim(),
      code,
    );
    console.log("Notificación via email, enviada");
  } catch (error) {
    console.error(`Error notificación email: ${error.message}`);
  }

  res.json({ success: true });
};

function GenerateLoginCode() {
  let logincode = "";

  try {
    for (let i = 0; i < 8; i++) {
      logincode += charactersCode.charAt(
        Math.floor(Math.random() * charactersCode.length),
      );
    }
  } catch (error) {
    console.error(error.message);
  }
  return logincode;
}

// const cambioproducto = async (req, res) => {
//     const { item } = req.body;
//     console.log("Autorización confirmada:", item);
//     const isChange = await querypg.ChangeProductToAuthorization(item);

//     res.json({ success: isChange, });

// };

module.exports = {
  index,
  login,
  home,
  autorizaciones,
  programaciones,
  ventas,
  pagosautorizacion,
  autorizardespacho,
  reportePagos,
  arqueo,
  listarproductodisponible,
  anularautorizacion,
  liberarsaldopendiente,
  // cambioproducto,
  verificatiocodesms,
  transferencias,
};
