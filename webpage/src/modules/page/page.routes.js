const { Router } = require('express');
const controller = require('./page.controller');
const { requireAuth } = require('../../middlewares/auth.middleware');

const router = Router();

router.get('/',controller.isAlive);
router.get('/index',controller.index);
router.post('/authentication',controller.authentication);
router.get('/home',controller.home);
router.get('/theme',controller.theme);
router.get('/autorizaciones',controller.autorizaciones);
router.get('/autorizaciones/:id',controller.autorizacionDetalle);
router.post('/autorizaciones/:id/anular',requireAuth,controller.anularAutorizacion);
router.get('/programaciones',controller.programaciones);
router.get('/programaciones/:id',controller.programacionDetalle);
router.get('/ventas',controller.ventas);
router.get('/ventas/:id',controller.ventaDetalle);
router.get('/arqueo',controller.arqueo);
router.get('/transferencia',controller.transferencia);
router.post('/transferencia/:codigo/reimprimir',requireAuth,controller.reimprimirVuelto);
router.get('/reportespagos',controller.reportePagos);
router.post('/reportespagos/:id/aprobar',requireAuth,controller.aprobarPago);
router.get('/auditoria',controller.auditoria);

module.exports = router;
