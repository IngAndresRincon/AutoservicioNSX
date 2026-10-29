const AppError = require("../../errors/AppError");
const sellerService = require("../../services/seller/service");

const isNumber = (value) => value !== undefined && value !== null && value !== "" && !Number.isNaN(Number(value));

const requireNumbers = (body, fields) => {
  const invalid = fields.find((field) => !isNumber(body[field]));
  if (invalid) {
    throw new AppError(`El campo ${invalid} es obligatorio y debe ser numerico`, 400);
  }
};

exports.login = async (req, res, next) => {
  try {
    const { document, password } = req.body;
    if (!document || !password) {
      throw new AppError("Los campos document y password son obligatorios", 400);
    }

    const content = await sellerService.login({ document: String(document), password: String(password) });
    return res.status(200).json({ isError: false, message: "Sesion de vendedor iniciada", content });
  } catch (error) {
    return next(error);
  }
};

const shift = (action, message) => async (req, res, next) => {
  try {
    const { password } = req.body;
    if (!password) {
      throw new AppError("El campo password es obligatorio", 400);
    }
    requireNumbers(req.body, ["positionId"]);

    const content = await sellerService[action]({
      document: req.seller.document,
      password: String(password),
      positionId: Number(req.body.positionId),
    });
    return res.status(200).json({ isError: false, message, content });
  } catch (error) {
    return next(error);
  }
};

exports.openShift = shift("openShift", "Turno abierto");
exports.closeShift = shift("closeShift", "Turno cerrado");

exports.createPreset = async (req, res, next) => {
  try {
    const body = req.body;
    requireNumbers(body, ["positionId", "hoseNumber", "programmingType"]);

    const programmingType = Number(body.programmingType);
    if (![1, 2, 3].includes(programmingType)) {
      throw new AppError("programmingType debe ser 1 (lleno), 2 (dinero) o 3 (volumen)", 400);
    }
    if (programmingType !== 1) {
      requireNumbers(body, ["value"]);
    }

    const content = await sellerService.createPreset({
      document: req.seller.document,
      positionId: Number(body.positionId),
      hoseNumber: Number(body.hoseNumber),
      programmingType,
      value: programmingType === 1 ? 0 : Number(body.value),
      plate: body.plate || null,
      km: isNumber(body.km) ? Math.round(Number(body.km)) : null,
    });
    return res.status(201).json({ isError: false, message: "Preset del vendedor registrado", content });
  } catch (error) {
    return next(error);
  }
};

exports.cancelPreset = async (req, res, next) => {
  try {
    requireNumbers(req.body, ["positionId"]);

    const content = await sellerService.cancelPreset({
      document: req.seller.document,
      positionId: Number(req.body.positionId),
    });
    return res.status(200).json({ isError: false, message: "Preset cancelado", content });
  } catch (error) {
    return next(error);
  }
};

exports.getPreset = async (req, res, next) => {
  try {
    requireNumbers(req.params, ["id"]);

    const content = await sellerService.getPreset({ id: Number(req.params.id), document: req.seller.document });
    return res.status(200).json({ isError: false, message: "Preset del vendedor consultado", content });
  } catch (error) {
    return next(error);
  }
};

exports.payments = async (req, res, next) => {
  try {
    const { paymentMethods } = req.body;
    requireNumbers(req.body, ["saleId"]);

    if (!Array.isArray(paymentMethods) || paymentMethods.length === 0) {
      throw new AppError("paymentMethods debe ser una lista con al menos una forma de pago", 400);
    }
    paymentMethods.forEach((item) => requireNumbers(item, ["paymentMethodId", "amount"]));

    const content = await sellerService.payments({
      document: req.seller.document,
      saleId: Number(req.body.saleId),
      paymentMethods: paymentMethods.map((item) => ({
        paymentMethodId: Number(item.paymentMethodId),
        amount: Number(item.amount),
        reference: item.reference ?? null,
      })),
    });
    return res.status(200).json({ isError: false, message: "Formas de pago ancladas", content });
  } catch (error) {
    return next(error);
  }
};

exports.sales = async (req, res, next) => {
  try {
    const content = await sellerService.shiftSales({ document: req.seller.document });
    return res.status(200).json({ isError: false, message: "Ventas del turno", content: { sales: content } });
  } catch (error) {
    return next(error);
  }
};

exports.positions = async (req, res, next) => {
  try {
    requireNumbers(req.query, ["screenId"]);

    const content = await sellerService.positions({ screenId: Number(req.query.screenId), document: req.seller.document });
    return res.status(200).json({ isError: false, message: "Estado de las posiciones", content: { positions: content } });
  } catch (error) {
    return next(error);
  }
};
