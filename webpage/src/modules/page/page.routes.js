const { Router } = require('express');
const controller = require('./page.controller');

const router = Router();

router.get('/',controller.isAlive);
router.get('/index',controller.index);
router.post('/authentication',controller.authentication);
router.get('/home',controller.home);

module.exports = router;
