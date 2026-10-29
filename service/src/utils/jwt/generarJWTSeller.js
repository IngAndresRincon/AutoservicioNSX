const jwt = require("jsonwebtoken");
const env = require("../../config/env");

function generarJWTSeller(seller) {
  const payload = {
    role: "seller",
    document: seller.document,
    sellerId: seller.sellerId,
    name: seller.name,
  };

  return jwt.sign(payload, env.jwtSecret, { expiresIn: `${env.sellerTokenHours}h` });
}

module.exports = { generarJWTSeller };
