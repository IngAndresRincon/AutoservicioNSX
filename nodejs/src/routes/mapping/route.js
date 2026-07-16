const express = require("express");
const controller = require("../../controllers/mapping/controller");

const router = express.Router();

router.get("/", controller.mapping);

module.exports = router;
