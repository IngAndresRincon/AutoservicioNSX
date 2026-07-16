const { server, app } = require("./src/app");
const logger = require("./src/config/logger");

server.listen(app.get("port"), () => {
  logger.info("Server on port", app.get("port"));
});

module.exports = { server, app };

