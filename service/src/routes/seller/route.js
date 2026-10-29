const express = require("express");
const controller = require("../../controllers/seller/controller");
const { sellerAuth } = require("../../middlewares");

const router = express.Router();

router.post("/login", controller.login);

router.use(sellerAuth);
router.get("/positions", controller.positions);
router.post("/shift/open", controller.openShift);
router.post("/shift/close", controller.closeShift);
router.post("/preset", controller.createPreset);
router.post("/preset/cancel", controller.cancelPreset);
router.get("/preset/:id", controller.getPreset);
router.post("/sale/payments", controller.payments);
router.get("/sales", controller.sales);

module.exports = router;
