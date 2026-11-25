const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const { env } = require('./env');

const { registerRoutes } = require('../routes');
const { notFoundHandler, errorHandler } = require('../middlewares/error.middleware');

const publicDir = path.resolve(__dirname, '../public');


function createApp() {

  
  const app = express();

  app.disable('x-powered-by');
  // Este servidor corre por HTTP plano en la red local (sin certificado).
  // Los defaults de Helmet asumen HTTPS (CSP con upgrade-insecure-requests,
  // HSTS) y en Chrome eso rompe la carga de assets en cualquier origen que
  // no sea "localhost" (en una IP de LAN el navegador intenta subir todo a
  // https:// y falla con ERR_SSL_PROTOCOL_ERROR). Se desactivan esas dos.
  app.use(helmet({ contentSecurityPolicy: false, hsts: false }));
  app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'x-api-key', 'Authorization'],
  }));
  app.use(express.json({ limit: '1mb' }));
  app.use('/public',express.static(path.join(__dirname, '../public')));

  // static files
  app.use("/mediav", express.static(path.join(__dirname, "../public/video")));
  app.use("/mediai", express.static(path.join(__dirname, "../public/image")));
  app.use("/media", express.static(path.join(__dirname, "../public/audio")));
  app.use("/service", express.static(path.join(__dirname, "../services")));

  //webpage
  //app.use('/',require("../routes/index")); // APi para webpage administrativa 

  app.use(express.urlencoded({ extended: false }));
  app.use(morgan('dev'));
  app.use(express.static(publicDir));

  registerRoutes(app);

  app.use(notFoundHandler);
  app.use(errorHandler);

  app.set('port', env.port);
  app.set('views', path.join(__dirname, '../views'));
  app.set('view engine', 'ejs');

  return app;
}

module.exports = createApp;
