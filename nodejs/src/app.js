const express = require("express");
const path = require("path");
const morgan = require("morgan");
const bodyParser = require("body-parser");
const http = require("http");
const { initSocketServer } = require("./sockets/socket-server");
const { apikey, notFound, errorHandler } = require("./middlewares");
const logger = require("./config/logger");

const clientRoute = require("./routes/client/route");
const mappingRoute = require("./routes/mapping/route");
const nsxRoute = require("./routes/nsx/route");
const productRoute = require("./routes/product/route");
const programmingRoute = require("./routes/programming/route");
const saleRoute = require("./routes/sale/route");
const systemRoute = require("./routes/system/route");
const terminalRoute = require("./routes/terminal/route");

const app = express();
const server = http.createServer(app);
const apiRouter = express.Router();

app.set("port", process.env.PORT || 5001);
app.set("views", path.join(__dirname, "../views"));
app.set("view engine", "ejs");

app.use(morgan("dev", { stream: logger.stream }));
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS");
  res.header(
    "Access-Control-Allow-Headers",
    "Origin, X-Requested-With, Content-Type, Accept, Authorization, x-api-key"
  );
  next();
});
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: false }));

app.use("/mediav", express.static(path.join(__dirname, "../public/video")));
app.use("/mediai", express.static(path.join(__dirname, "../public/img")));
app.use("/media", express.static(path.join(__dirname, "../public/audio")));
app.use(express.static(path.join(__dirname, "../public")));

app.use("/nsx-autoservice-api/V1/system", systemRoute);
app.use("/api", terminalRoute);

apiRouter.use(apikey);
apiRouter.use("/mapping", mappingRoute);
apiRouter.use("/product", productRoute);
apiRouter.use("/client", clientRoute);
apiRouter.use("/programming", programmingRoute);
apiRouter.use("/nsx", nsxRoute);
apiRouter.use("/sale", saleRoute);

app.use("/nsx-autoservice-api/V1", apiRouter);

app.use(notFound);
app.use(errorHandler);

initSocketServer(server);

module.exports = { app, server };

