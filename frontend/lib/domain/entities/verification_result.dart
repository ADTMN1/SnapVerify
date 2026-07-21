enum VerificationStatus { verified, pending, failed, alreadyVerified }

class VerificationResult {
  final bool verified;
  final VerificationStatus status;
  final String paymentId;
  final double amount;
  final String currency;
  final String transactionId;
  final String? senderName;
  final String? receiverName;
  final int riskScore;
  final String message;

  const VerificationResult({
    required this.verified,
    required this.status,
    required this.paymentId,
    required this.amount,
    required this.currency,
    required this.transactionId,
    this.senderName,
    this.receiverName,
    required this.riskScore,
    required this.message,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] as String? ?? '').toUpperCase();
    final status = rawStatus == 'VERIFIED'
        ? VerificationStatus.verified
        : rawStatus == 'FAILED'
            ? VerificationStatus.failed
            : rawStatus == 'ALREADY_VERIFIED'
                ? VerificationStatus.alreadyVerified
                : VerificationStatus.pending;

    return VerificationResult(
      verified: json['verified'] as bool? ?? false,
      status: status,
      paymentId: json['paymentId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'ETB',
      transactionId: json['transactionId'] as String? ?? '',
      senderName: json['senderName'] as String?,
      receiverName: json['receiverName'] as String?,
      riskScore: json['riskScore'] as int? ?? 0,
      message: json['message'] as String? ?? '',
    );
  }
}
