const path = require('path');
const service = require('./page.service');

const appIndex = path.join(__dirname, '../../public/app/index.html');

exports.isAlive = async (req, res, next) => {
  try {
    return res.status(200).json({
      message: "Server is alive",
    });
  } catch (error) {
    return next(error);
  }
};


exports.index = async (req, res, next) => {
    res.sendFile(appIndex);
};

exports.authentication = async (req, res, next) => {
    try {
        const { user, password } = req.body;
        const result = await service.authenticate(user, password);

        if (!result.success) {
            return res.status(401).json({ success: false, message: result.message });
        }

        res.json({ success: true, usuario: result.usuario, token: result.token });
    } catch (error) {
        next(error);
    }
};

exports.theme = async (req, res, next) => {
    try {
        const theme = await service.getTheme();
        res.json(theme);
    } catch (error) {
        next(error);
    }
};

exports.autorizaciones = async (req, res, next) => {
    try {
        res.json(await service.getAutorizaciones());
    } catch (error) {
        next(error);
    }
};

exports.autorizacionDetalle = async (req, res, next) => {
    try {
        const detalle = await service.getAutorizacionDetalle(req.params.id);
        if (!detalle) {
            return res.status(404).json({ message: 'Autorización no encontrada' });
        }
        res.json(detalle);
    } catch (error) {
        next(error);
    }
};

exports.anularAutorizacion = async (req, res, next) => {
    try {
        const cancelada = await service.cancelAutorizacion(req.params.id, req.user);
        if (!cancelada) {
            return res.status(409).json({
                success: false,
                message: 'La autorización ya no está disponible para anular (puede que ya tenga una venta asociada).',
            });
        }
        res.json({ success: true });
    } catch (error) {
        next(error);
    }
};

exports.programaciones = async (req, res, next) => {
    try {
        res.json(await service.getProgramaciones());
    } catch (error) {
        next(error);
    }
};

exports.programacionDetalle = async (req, res, next) => {
    try {
        const detalle = await service.getProgramacionDetalle(req.params.id);
        if (!detalle) {
            return res.status(404).json({ message: 'Programación no encontrada' });
        }
        res.json(detalle);
    } catch (error) {
        next(error);
    }
};

exports.ventas = async (req, res, next) => {
    try {
        res.json(await service.getVentas());
    } catch (error) {
        next(error);
    }
};

exports.ventaDetalle = async (req, res, next) => {
    try {
        const detalle = await service.getVentaDetalle(req.params.id);
        if (!detalle) {
            return res.status(404).json({ message: 'Venta no encontrada' });
        }
        res.json(detalle);
    } catch (error) {
        next(error);
    }
};

exports.arqueo = async (req, res, next) => {
    try {
        res.json(await service.getArqueo());
    } catch (error) {
        next(error);
    }
};

exports.transferencia = async (req, res, next) => {
    try {
        res.json(await service.getTransferenciaSaldos());
    } catch (error) {
        next(error);
    }
};

exports.reimprimirVuelto = async (req, res, next) => {
    try {
        const result = await service.reimprimirVuelto(req.params.codigo, req.user);
        res.json({ success: result.success, message: result.message });
    } catch (error) {
        next(error);
    }
};

exports.reportePagos = async (req, res, next) => {
    try {
        const { from, to, q, page, pageSize } = req.query;
        const result = await service.getReportePagos({
            from,
            to,
            q,
            page: Number(page) || 1,
            pageSize: Number(pageSize) || 25,
        });
        res.json(result);
    } catch (error) {
        next(error);
    }
};

exports.aprobarPago = async (req, res, next) => {
    try {
        const result = await service.approvePago(req.params.id, req.user);

        if (result.notFound) {
            return res.status(404).json({ success: false, message: 'Pago no encontrado.' });
        }
        if (result.alreadyApproved) {
            return res.status(409).json({ success: false, message: 'Este pago ya está completado.' });
        }
        res.json({ success: true });
    } catch (error) {
        next(error);
    }
};

exports.auditoria = async (req, res, next) => {
    try {
        res.json(await service.getAuditoria());
    } catch (error) {
        next(error);
    }
};

exports.home = async (req, res, next) => {
    res.sendFile(appIndex);
};



