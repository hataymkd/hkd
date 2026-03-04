class PaymentCheckoutResultModel {
  const PaymentCheckoutResultModel({
    required this.paymentId,
    required this.provider,
    required this.status,
    this.checkoutUrl,
    this.instructions,
  });

  final String paymentId;
  final String provider;
  final String status;
  final String? checkoutUrl;
  final String? instructions;
}
