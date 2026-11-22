class SubscriptionPlan {
  final String id;
  final String name;
  final int price;
  final String currency;
  final int? durationDays;
  final int? verificationLimit;
  final int? maxUsers;
  final int? maxDevices;
  final List<String> features;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    this.durationDays,
    this.verificationLimit,
    this.maxUsers,
    this.maxDevices,
    this.features = const [],
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: int.tryParse(json['price']?.toString() ?? '') ?? 0,
      currency: json['currency']?.toString() ?? 'ETB',
      durationDays: int.tryParse(json['durationDays']?.toString() ?? ''),
      verificationLimit: json['verificationLimit'] != null
          ? int.tryParse(json['verificationLimit'].toString())
          : null,
      maxUsers: json['maxUsers'] != null
          ? int.tryParse(json['maxUsers'].toString())
          : null,
      maxDevices: json['maxDevices'] != null
          ? int.tryParse(json['maxDevices'].toString())
          : null,
      features: (json['features'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
    );
  }

  String get durationLabel {
    if (durationDays == null) return 'No expiry';
    switch (durationDays) {
      case 30:
        return '1 month';
      case 90:
        return '3 months';
      case 180:
        return '6 months';
      case 360:
        return '1 year';
      default:
        return '$durationDays days';
    }
  }

  String get verificationLabel => verificationLimit == null
      ? 'Unlimited verifications'
      : '$verificationLimit verifications';

  String get summary => verificationLimit == null
      ? '$durationLabel · Unlimited'
      : '$verificationLabel · No expiry';
}
