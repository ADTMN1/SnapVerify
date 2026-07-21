enum QRStatus { active, inactive, disabled }

class QRCode {
  final String id;
  final String branchId;
  final String branchName;
  final String qrData;
  final QRStatus status;
  final DateTime createdAt;
  final DateTime? lastUpdated;
  final int timesUsedToday;
  final DateTime? lastScanTime;

  QRCode({
    required this.id,
    required this.branchId,
    required this.branchName,
    required this.qrData,
    this.status = QRStatus.active,
    required this.createdAt,
    this.lastUpdated,
    this.timesUsedToday = 0,
    this.lastScanTime,
  });

  QRCode copyWith({
    String? id,
    String? branchId,
    String? branchName,
    String? qrData,
    QRStatus? status,
    DateTime? createdAt,
    DateTime? lastUpdated,
    int? timesUsedToday,
    DateTime? lastScanTime,
  }) {
    return QRCode(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      qrData: qrData ?? this.qrData,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      timesUsedToday: timesUsedToday ?? this.timesUsedToday,
      lastScanTime: lastScanTime ?? this.lastScanTime,
    );
  }
}
