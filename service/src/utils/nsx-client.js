const AppError = require("../errors/AppError");
const nsxRepository = require("../repositories/nsx/repository");
const { postJson } = require("./http-client");

const apiNsx = process.env.API_NSX;

// Devuelve data del API o lanza AppError con el mensaje real (401 credenciales, 404, 409, 400 validacion)
exports.callNsx = async (path, body, timeoutMs) => {
  const response = await postJson(`${apiNsx}${path}`, body, timeoutMs);
  const data = response.data;

  if (response.status >= 500 || !data) {
    throw new AppError("El servidor NSX no respondio correctamente", 502, { details: data });
  }

  if (response.status === 401) {
    throw new AppError(data.message || "Credenciales invalidas", 401);
  }

  if (data.success !== true) {
    const reason = Array.isArray(data.errors) && data.errors.length > 0 ? data.errors.join(" ") : data.message;
    const status = response.status === 404 || response.status === 409 ? response.status : 400;
    throw new AppError(reason || "NSX rechazo la solicitud", status, { details: data.errors });
  }

  return data.data;
};

exports.getModuleIdentifier = async () => {
  const module = await nsxRepository.findModuleIdentifier();
  if (!module) {
    throw new AppError("No se encuentra el identificador del módulo", 404);
  }
  return module.identificador;
};
