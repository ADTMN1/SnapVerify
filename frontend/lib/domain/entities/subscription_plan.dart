class SubscriptionPlan {
  final String id;
  final String name;
  final int price;
  final String currency;
  final int? durationDays;
  final int? durationMonths;
  final bool isLifetime;
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
    this.durationMonths,
    this.isLifetime = false,
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
      durationMonths: int.tryParse(json['durationMonths']?.toString() ?? ''),
      isLifetime: _parseBool(json['isLifetime']),
      verificationLimit: json['verificationLimit'] != null
          ? int.tryParse(json['verificationLimit'].toString())
          : null,
      maxUsers: json['maxUsers'] != null
          ? int.tryParse(json['maxUsers'].toString())
          : null,
      maxDevices: json['maxDevices'] != null
          ? int.tryParse(json['maxDevices'].toString())
          : null,
      features:
          (json['features'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
    );
  }

  String get durationLabel {
    if (isLifetime || (durationMonths == null && durationDays == null)) {
      return 'No expiry';
    }
    if (durationMonths != null) {
      return durationMonths == 1 ? '1 month' : '$durationMonths months';
    }
    final days = durationDays!;
    return days == 1 ? '1 day' : '$days days';
  }

  String get verificationLabel => verificationLimit == null
      ? 'Unlimited verifications'
      : '$verificationLimit verifications';

  String get summary => '$durationLabel · $verificationLabel';
}

bool _parseBool(Object? value) {
  if (value is bool) return value;
  if (value == null) return false;
  return value.toString().toLowerCase() == 'true';
}
