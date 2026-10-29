const express = require("express");
const controller = require("../../controllers/client/controller");
const { sellerAuth } = require("../../middlewares");

const router = express.Router();

router.post("/validation", controller.clientValidation);
router.post("/additional-information", controller.additionalInformation);
router.get("/validation-dian", controller.clienteValidationDian);

// Cliente con identificador; con token de vendedor la venta queda en su turno
router.post("/identifier/read", controller.readIdentifier);
router.post("/authorize", sellerAuth.optional, controller.authorizeClient);
router.get("/preset/:id", sellerAuth.optional, controller.getClientPreset);

module.exports = router;
