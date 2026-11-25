class PaymentResult {
  final bool success;
  final String message;
  final int? paymentId; // Agregamos esto

  PaymentResult({required this.success, required this.message, this.paymentId});
}