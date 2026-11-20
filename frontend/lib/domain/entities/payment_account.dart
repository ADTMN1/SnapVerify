enum PaymentProvider { CBE, TELEBIRR, DASHEN, ABYSSINIA, CBEBIRR, M_PESA }

/// Human-readable label for a provider (used in selection UI and logs).
extension PaymentProviderLabel on PaymentProvider {
  String get label => switch (this) {
        PaymentProvider.CBE => 'CBE',
        PaymentProvider.TELEBIRR => 'Telebirr',
        PaymentProvider.DASHEN => 'Dashen',
        PaymentProvider.ABYSSINIA => 'Abyssinia',
        PaymentProvider.CBEBIRR => 'CBE Birr',
        PaymentProvider.M_PESA => 'M-Pesa',
      };
}

/// Map an OCR-extracted provider label (e.g. "Telebirr", "CBE Birr",
/// "M-Pesa", "CBEBirr") to a canonical [PaymentProvider].
///
/// Returns null when detection is uncertain/unknown so callers can request
/// explicit user selection instead of guessing. CBE Birr (CBEBIRR) is kept
/// distinct from CBE and Telebirr.
PaymentProvider? paymentProviderFromOcrLabel(String? label) {
  final normalized = label
      ?.trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_-]+'), '');
  switch (normalized) {
    case 'telebirr':
      return PaymentProvider.TELEBIRR;
    case 'cbe':
      return PaymentProvider.CBE;
    case 'dashen':
      return PaymentProvider.DASHEN;
    case 'abyssinia':
      return PaymentProvider.ABYSSINIA;
    case 'cbebirr':
      return PaymentProvider.CBEBIRR;
    case 'mpesa':
      return PaymentProvider.M_PESA;
  }
  return null;
}

class PaymentAccount {
  final String id;
  final String organizationId;
  final String? publicId;
  final PaymentProvider provider;
  final String? accountNumber;
  final String? suffix;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentAccount({
    required this.id,
    required this.organizationId,
    this.publicId,
    required this.provider,
    this.accountNumber,
    this.suffix,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentAccount.fromJson(Map<String, dynamic> json) {
    return PaymentAccount(
      id: json['id'] as String,
      organizationId: json['organizationId'] as String,
      publicId: json['publicId'] as String?,
      provider: PaymentProvider.values.firstWhere(
        (e) => e.name == json['provider'],
        orElse: () => PaymentProvider.CBE,
      ),
      accountNumber: json['accountNumber'] as String?,
      suffix: json['suffix'] as String?,
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationId': organizationId,
      'publicId': publicId,
      'provider': provider.name,
      'accountNumber': accountNumber,
      'suffix': suffix,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  PaymentAccount copyWith({
    String? id,
    String? organizationId,
    String? publicId,
    PaymentProvider? provider,
    String? accountNumber,
    String? suffix,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentAccount(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      publicId: publicId ?? this.publicId,
      provider: provider ?? this.provider,
      accountNumber: accountNumber ?? this.accountNumber,
      suffix: suffix ?? this.suffix,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
