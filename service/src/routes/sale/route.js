const express = require("express");
const controller = require("../../controllers/sale/controller");

const router = express.Router();

router.get("/", controller.sale);
router.post("/bill", controller.bill);

module.exports = router;
