/// Real reporting data returned by `GET /reports/summary`.
class ReportSummary {
  final ReportRange range;
  final ReportTotals summary;
  final List<ReportStatusRow> byStatus;
  final List<ReportProviderRow> byProvider;
  final List<ReportStaffRow> byStaff;
  final List<ReportDailyRow> daily;
  final List<ReportPaymentRow> recent;
  final List<ReportPaymentRow> highRiskPayments;

  const ReportSummary({
    required this.range,
    required this.summary,
    required this.byStatus,
    required this.byProvider,
    required this.byStaff,
    required this.daily,
    required this.recent,
    required this.highRiskPayments,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    return ReportSummary(
      range: ReportRange.fromJson(
        json['range'] as Map<String, dynamic>? ?? const {},
      ),
      summary: ReportTotals.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
      byStatus: _rows(json['byStatus'], ReportStatusRow.fromJson),
      byProvider: _rows(json['byProvider'], ReportProviderRow.fromJson),
      byStaff: _rows(json['byStaff'], ReportStaffRow.fromJson),
      daily: _rows(json['daily'], ReportDailyRow.fromJson),
      recent: _rows(json['recent'], ReportPaymentRow.fromJson),
      highRiskPayments: _rows(
        json['highRiskPayments'],
        ReportPaymentRow.fromJson,
      ),
    );
  }

  static List<T> _rows<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

class ReportRange {
  final String from;
  final String to;
  const ReportRange({required this.from, required this.to});

  factory ReportRange.fromJson(Map<String, dynamic> json) => ReportRange(
    from: json['from'] as String? ?? '',
    to: json['to'] as String? ?? '',
  );
}

class ReportTotals {
  final int total;
  final int verified;
  final int failed;
  final int rejected;
  final int pending;
  final double totalAmount;
  final double verifiedAmount;
  final double averageAmount;
  final int highRisk;
  final double highRiskAmount;
  final String currency;

  const ReportTotals({
    required this.total,
    required this.verified,
    required this.failed,
    required this.rejected,
    required this.pending,
    required this.totalAmount,
    required this.verifiedAmount,
    required this.averageAmount,
    required this.highRisk,
    required this.highRiskAmount,
    required this.currency,
  });

  factory ReportTotals.fromJson(Map<String, dynamic> json) => ReportTotals(
    total: _int(json['total']),
    verified: _int(json['verified']),
    failed: _int(json['failed']),
    rejected: _int(json['rejected']),
    pending: _int(json['pending']),
    totalAmount: _double(json['totalAmount']),
    verifiedAmount: _double(json['verifiedAmount']),
    averageAmount: _double(json['averageAmount']),
    highRisk: _int(json['highRisk']),
    highRiskAmount: _double(json['highRiskAmount']),
    currency: json['currency'] as String? ?? 'ETB',
  );

  static int _int(dynamic value) => value is num ? value.toInt() : 0;
  static double _double(dynamic value) => value is num ? value.toDouble() : 0;
}

class ReportStatusRow {
  final String status;
  final int count;
  final double amount;
  const ReportStatusRow({
    required this.status,
    required this.count,
    required this.amount,
  });

  factory ReportStatusRow.fromJson(Map<String, dynamic> json) =>
      ReportStatusRow(
        status: json['status'] as String? ?? 'UNKNOWN',
        count: ReportTotals._int(json['count']),
        amount: ReportTotals._double(json['amount']),
      );
}

class ReportProviderRow {
  final String provider;
  final int count;
  final double amount;
  const ReportProviderRow({
    required this.provider,
    required this.count,
    required this.amount,
  });

  factory ReportProviderRow.fromJson(Map<String, dynamic> json) =>
      ReportProviderRow(
        provider: json['provider'] as String? ?? 'unknown',
        count: ReportTotals._int(json['count']),
        amount: ReportTotals._double(json['amount']),
      );
}

class ReportStaffRow {
  final String userId;
  final String name;
  final int count;
  final double amount;
  const ReportStaffRow({
    required this.userId,
    required this.name,
    required this.count,
    required this.amount,
  });

  factory ReportStaffRow.fromJson(Map<String, dynamic> json) => ReportStaffRow(
    userId: json['userId'] as String? ?? '',
    name: json['name'] as String? ?? 'Unknown',
    count: ReportTotals._int(json['count']),
    amount: ReportTotals._double(json['amount']),
  );
}

class ReportDailyRow {
  final String date;
  final int count;
  final double amount;
  final int verifiedCount;
  final double verifiedAmount;
  const ReportDailyRow({
    required this.date,
    required this.count,
    required this.amount,
    required this.verifiedCount,
    required this.verifiedAmount,
  });

  factory ReportDailyRow.fromJson(Map<String, dynamic> json) => ReportDailyRow(
    date: json['date'] as String? ?? '',
    count: ReportTotals._int(json['count']),
    amount: ReportTotals._double(json['amount']),
    verifiedCount: ReportTotals._int(json['verifiedCount']),
    verifiedAmount: ReportTotals._double(json['verifiedAmount']),
  );
}

class ReportPaymentRow {
  final String id;
  final double amount;
  final String currency;
  final String status;
  final String? paymentMethod;
  final String? transactionId;
  final String? senderName;
  final String? receiverName;
  final int? riskScore;
  final DateTime createdAt;
  final String? verifiedByName;

  const ReportPaymentRow({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    this.paymentMethod,
    this.transactionId,
    this.senderName,
    this.receiverName,
    this.riskScore,
    required this.createdAt,
    this.verifiedByName,
  });

  factory ReportPaymentRow.fromJson(Map<String, dynamic> json) {
    final verifiedBy = json['verifiedBy'] as Map<String, dynamic>?;
    return ReportPaymentRow(
      id: json['id'] as String? ?? '',
      amount: ReportTotals._double(json['amount']),
      currency: json['currency'] as String? ?? 'ETB',
      status: json['status'] as String? ?? 'UNKNOWN',
      paymentMethod: json['paymentMethod'] as String?,
      transactionId: json['transactionId'] as String?,
      senderName: json['senderName'] as String?,
      receiverName: json['receiverName'] as String?,
      riskScore: json['riskScore'] is num
          ? (json['riskScore'] as num).toInt()
          : null,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      verifiedByName: verifiedBy?['name'] as String?,
    );
  }
}
