const express = require("express");
const controller = require("../../controllers/terminal/controller");

const router = express.Router();

router.get("/terminaldataphonevalidate", controller.synchronizeTerminal);

module.exports = router;
