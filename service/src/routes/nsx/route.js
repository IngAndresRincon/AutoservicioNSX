const express = require("express");
const controller = require("../../controllers/nsx/controller");

const router = express.Router();

router.get("/print-sale", controller.printSale);
router.get("/last-sale/:dispenserId/:sideId", controller.getLastSale);
router.get("/sale/preset/:presetId", controller.getSalebyPresetId);
router.get("/change/:code", controller.checkChangeCode);
router.get("/status-position/:position", controller.getStatusPosition);

router.post("/change", controller.generateChange);
router.post("/change/register", controller.registerReturnChange);
router.post("/shift/validate-seller", controller.validateSeller);
router.post("/fidelity", controller.fidelity);
router.post("/fidelity/validate-customer", controller.validateCustomer);

module.exports = router;
