const express = require("express");
const controller = require("../../controllers/product/controller");

const router = express.Router();

router.get("/", controller.product);
router.patch("/price", controller.updateProductPrice);

module.exports = router;
