enum VerificationStatus {
  verified,
  pending,
  failed,
  alreadyVerified,
  needsReview,
  providerUnavailable,
  quotaExhausted,
  providerConfigError,
  paymentAccountNotConfigured,
  providerUndetected,
  unsupportedProvider,
}

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

  bool get isProviderOutage =>
      status == VerificationStatus.providerUnavailable ||
      status == VerificationStatus.quotaExhausted ||
      status == VerificationStatus.providerConfigError;

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] as String? ?? '').toUpperCase();
    // Explicit backend-status mapping. Provider outages/quota/config errors are
    // surfaced distinctly and must never be presented as an invalid receipt or
    // invalid transaction. Unknown statuses map to `pending`.
    final status = switch (rawStatus) {
      'VERIFIED' => VerificationStatus.verified,
      'FAILED' => VerificationStatus.failed,
      'DUPLICATE_TRANSACTION' ||
      'ALREADY_VERIFIED' => VerificationStatus.alreadyVerified,
      'NEEDS_REVIEW' || 'MANUAL_REVIEW' => VerificationStatus.needsReview,
      'PROVIDER_UNAVAILABLE' ||
      'SERVICE_UNAVAILABLE' => VerificationStatus.providerUnavailable,
      'QUOTA_EXHAUSTED' => VerificationStatus.quotaExhausted,
      'PROVIDER_CONFIG_ERROR' => VerificationStatus.providerConfigError,
      'PAYMENT_ACCOUNT_NOT_CONFIGURED' =>
        VerificationStatus.paymentAccountNotConfigured,
      'PAYMENT_PROVIDER_UNDETECTED' => VerificationStatus.providerUndetected,
      'UNSUPPORTED_PAYMENT_PROVIDER' => VerificationStatus.unsupportedProvider,
      'PENDING' || _ => VerificationStatus.pending,
    };

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
