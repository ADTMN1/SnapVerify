class SubscriptionCheckout {
  final String id;
  final String planName;
  final int amount;
  final String currency;
  final String provider;
  final String reference;
  final String status;
  final DateTime expiresAt;
  final String payToAccountNumber;
  final String? payToAccountName;

  const SubscriptionCheckout({
    required this.id,
    required this.planName,
    required this.amount,
    required this.currency,
    required this.provider,
    required this.reference,
    required this.status,
    required this.expiresAt,
    required this.payToAccountNumber,
    this.payToAccountName,
  });

  factory SubscriptionCheckout.fromJson(Map<String, dynamic> json) {
    final payTo = json['payTo'] as Map<String, dynamic>? ?? const {};
    return SubscriptionCheckout(
      id: json['id']?.toString() ?? '',
      planName: json['planName']?.toString() ?? '',
      amount: int.tryParse(json['amount']?.toString() ?? '') ?? 0,
      currency: json['currency']?.toString() ?? 'ETB',
      provider: json['provider']?.toString() ?? 'TELEBIRR',
      reference: json['reference']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString()) ??
                DateTime.now().add(const Duration(minutes: 30))
          : DateTime.now().add(const Duration(minutes: 30)),
      payToAccountNumber: payTo['accountNumber']?.toString() ?? '',
      payToAccountName: payTo['accountName']?.toString(),
    );
  }
}
