const express = require("express");
const controller = require("../../controllers/nsx/controller");

const router = express.Router();

router.get("/print-sale", controller.printSale);
router.get("/last-sale/:dispenserId/:sideId", controller.getLastSale);
router.get("/sale/preset/:presetId", controller.getSalebyPresetId);
router.get("/change/:code", controller.checkChangeCode);
router.post("/change", controller.generateChange);
router.post("/change/register", controller.registerReturnChange);
router.post("/shift/validate-seller", controller.validateSeller);
router.get("/status-position/:position", controller.getStatusPosition);

module.exports = router;
