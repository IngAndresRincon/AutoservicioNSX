const express = require("express");
const controller = require("../../controllers/client/controller");

const router = express.Router();

router.post("/validation", controller.clientValidation);
router.post("/additional-information", controller.additionalInformation);
router.get("/validation-dian", controller.clienteValidationDian);

module.exports = router;
