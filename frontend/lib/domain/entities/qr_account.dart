/// QR information for a payment account, as returned by the QR endpoints.
///
/// The account number is always masked by the backend; this model never holds
/// a full bank account number.
class QrAccountInfo {
  final String id;
  final String publicId;
  final String provider;
  final String? accountNumber;
  final String? accountHolderName;
  final String? suffix;
  final bool isActive;
  final String qrVersion;
  final String? qrUrl;
  final String? branchId;
  final String? branchName;
  final String? organizationName;
  final DateTime? createdAt;

  const QrAccountInfo({
    required this.id,
    required this.publicId,
    required this.provider,
    this.accountNumber,
    this.accountHolderName,
    this.suffix,
    required this.isActive,
    this.qrVersion = 'v1',
    this.qrUrl,
    this.branchId,
    this.branchName,
    this.organizationName,
    this.createdAt,
  });

  bool get hasQrUrl => qrUrl != null && qrUrl!.isNotEmpty;

  String get providerLabel {
    switch (provider.toUpperCase()) {
      case 'CBE':
        return 'CBE';
      case 'TELEBIRR':
        return 'Telebirr';
      case 'DASHEN':
        return 'Dashen';
      case 'ABYSSINIA':
        return 'Abyssinia';
      case 'CBEBIRR':
        return 'CBE Birr';
      case 'M_PESA':
        return 'M-Pesa';
      default:
        return provider;
    }
  }

  factory QrAccountInfo.fromJson(Map<String, dynamic> json) {
    final branch = json['branch'];
    final organization = json['organization'];
    return QrAccountInfo(
      id: json['id']?.toString() ?? '',
      publicId: json['publicId']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString(),
      accountHolderName: json['accountHolderName']?.toString(),
      suffix: json['suffix']?.toString(),
      isActive: json['isActive'] == true,
      qrVersion: json['qrVersion']?.toString() ?? 'v1',
      qrUrl: json['qrUrl']?.toString(),
      branchId: branch is Map ? branch['id']?.toString() : null,
      branchName: branch is Map ? branch['name']?.toString() : null,
      organizationName: organization is Map
          ? organization['name']?.toString()
          : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

/// Result of resolving a scanned QR identifier.
class QrScanResult {
  final QrAccountInfo account;
  final bool confirmedPayment;
  final String? notice;

  const QrScanResult({
    required this.account,
    this.confirmedPayment = false,
    this.notice,
  });

  factory QrScanResult.fromJson(Map<String, dynamic> json) {
    return QrScanResult(
      account: QrAccountInfo.fromJson(json),
      confirmedPayment: json['confirmedPayment'] == true,
      notice: json['notice']?.toString(),
    );
  }
}
