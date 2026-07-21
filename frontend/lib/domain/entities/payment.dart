enum PaymentStatus { verified, flagged, failed, pending }

class PaymentVerification {
  final String id;
  final String paymentId;
  final String? transactionId;
  final String? customerName;
  final String? customerPhone;
  final String bankName;
  final double amount;
  final String verifiedByStaffId;
  final String verifiedByStaffName;
  final String branchId;
  final String branchName;
  final DateTime timestamp;
  final PaymentStatus status;
  final double riskScore;
  final String? notes;

  PaymentVerification({
    required this.id,
    required this.paymentId,
    this.transactionId,
    this.customerName,
    this.customerPhone,
    required this.bankName,
    required this.amount,
    required this.verifiedByStaffId,
    required this.verifiedByStaffName,
    required this.branchId,
    required this.branchName,
    required this.timestamp,
    this.status = PaymentStatus.verified,
    this.riskScore = 0.0,
    this.notes,
  });

  PaymentVerification copyWith({
    String? id,
    String? paymentId,
    String? transactionId,
    String? customerName,
    String? customerPhone,
    String? bankName,
    double? amount,
    String? verifiedByStaffId,
    String? verifiedByStaffName,
    String? branchId,
    String? branchName,
    DateTime? timestamp,
    PaymentStatus? status,
    double? riskScore,
    String? notes,
  }) {
    return PaymentVerification(
      id: id ?? this.id,
      paymentId: paymentId ?? this.paymentId,
      transactionId: transactionId ?? this.transactionId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      bankName: bankName ?? this.bankName,
      amount: amount ?? this.amount,
      verifiedByStaffId: verifiedByStaffId ?? this.verifiedByStaffId,
      verifiedByStaffName: verifiedByStaffName ?? this.verifiedByStaffName,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      riskScore: riskScore ?? this.riskScore,
      notes: notes ?? this.notes,
    );
  }
}
