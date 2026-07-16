const express = require("express");
const controller = require("../../controllers/system/controller");

const router = express.Router();

router.get("/", controller.root);
router.post("/upload-video", controller.uploadVideoMiddleware, controller.uploadVideo);
router.patch("/synchronize-module", controller.synchronizeModule);
router.post("/synchronize-screen", controller.synchronizeScreen);

module.exports = router;
