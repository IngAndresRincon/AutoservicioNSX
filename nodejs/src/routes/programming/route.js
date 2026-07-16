const express = require("express");
const controller = require("../../controllers/programming/controller");

const router = express.Router();

router.post("/", controller.createProgramming);
router.post("/create-payment", controller.createPayment);
router.get("/pending-programming", controller.pendingProgramming);
router.get("/pending-authorization", controller.pendingAuthorization);
router.patch("/resend-authorization", controller.resendAuthorization);
router.patch("/authorize-programming/:clientId/:programmingId", controller.authorizeProgramming);


module.exports = router;
