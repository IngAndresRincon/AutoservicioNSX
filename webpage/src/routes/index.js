// const express = require('express');
// const route = express.Router();
// const controller = require('../../controllers/web/controller');

// // route.get("/login", (req, res) => {
// //   res.render('login', { estilo: 'login', titulo: 'Login' });
// // });


// route.get("/",controller.index);
// route.post("/login",controller.login);
// route.get("/home",controller.home);
// route.get("/autorizaciones",controller.autorizaciones);
// route.get("/programaciones",controller.programaciones);
// route.get("/ventas",controller.ventas);
// route.post("/pagosautorizacion",controller.pagosautorizacion);
// route.post("/autorizardespacho",controller.autorizardespacho);
// route.post("/reportePagos",controller.reportePagos);
// route.get("/arqueo",controller.arqueo);
// route.get("/transferencia",controller.transferencias);
// route.post("/listarproductodisponible",controller.listarproductodisponible);
// route.post("/anularautorizacion",controller.anularautorizacion);
// route.post("/liberarsaldopendiente",controller.liberarsaldopendiente);

// // route.post("/cambioproducto",controller.cambioproducto);
// route.post("/verificatiocodesms",controller.verificatiocodesms);

// module.exports = route;


const webRoutes = require('../modules/page/page.routes');


function registerRoutes(app) {
  app.use('/api/nsx-autoservice/page', webRoutes);

}

module.exports = {
  registerRoutes
};
