enum PaymentProvider {
  CBE,
  TELEBIRR,
  DASHEN,
  ABYSSINIA,
  CBEBIRR,
  M_PESA,
}

class PaymentAccount {
  final String id;
  final String organizationId;
  final PaymentProvider provider;
  final String? accountNumber;
  final String? suffix;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentAccount({
    required this.id,
    required this.organizationId,
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
      provider: provider ?? this.provider,
      accountNumber: accountNumber ?? this.accountNumber,
      suffix: suffix ?? this.suffix,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
