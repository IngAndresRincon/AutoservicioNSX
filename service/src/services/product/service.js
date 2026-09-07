
const productRepository = require("../../repositories/product/repository");


exports.product = () =>{
  return productRepository.product();
}
exports.updateProduct = (nsxId, price) =>{
  return productRepository.updateProduct(nsxId, price);
}



