enum SubscriptionStatus { active, inactive, cancelled, expired, unknown }

class Subscription {
  final String id;
  final String organizationId;
  final String planName;
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime? endDate;
  final int? maxUsers;
  final int? maxDevices;
  final int? verificationLimit;
  final int verificationUsed;
  final int? verificationRemaining;
  final DateTime? usagePeriodStart;
  final DateTime? usagePeriodEnd;

  const Subscription({
    required this.id,
    required this.organizationId,
    required this.planName,
    required this.status,
    required this.startDate,
    this.endDate,
    this.maxUsers,
    this.maxDevices,
    this.verificationLimit,
    this.verificationUsed = 0,
    this.verificationRemaining,
    this.usagePeriodStart,
    this.usagePeriodEnd,
  });

  bool get isActive {
    if (status != SubscriptionStatus.active) return false;
    if (endDate == null) return true;
    return endDate!.isAfter(DateTime.now());
  }

  int? get daysLeft {
    if (endDate == null) return null;
    final days = endDate!.difference(DateTime.now()).inDays;
    return days > 0 ? days : 0;
  }

  bool get isQuotaExceeded =>
      verificationLimit != null && verificationUsed >= verificationLimit!;

  String get verificationSummary {
    if (verificationLimit == null) return 'Unlimited verifications';
    return '${verificationRemaining ?? 0} of $verificationLimit verifications left';
  }

  String get planLabel {
    switch (planName.toLowerCase()) {
      case 'free':
        return 'Free';
      case 'free_trial':
        return 'Free';
      case 'one_month':
        return '1 Month';
      case 'three_months':
        return '3 Months';
      case 'six_months':
        return '6 Months';
      case 'one_year':
        return '1 Year';
      case 'starter':
        return 'Starter';
      case 'business':
        return 'Business';
      case 'enterprise':
        return 'Enterprise';
      default:
        return planName
            .split(RegExp(r'[_\s]+'))
            .map(
              (word) => word.isEmpty
                  ? word
                  : word[0].toUpperCase() + word.substring(1).toLowerCase(),
            )
            .join(' ');
    }
  }

  String get statusLabel {
    switch (status) {
      case SubscriptionStatus.active:
        return isActive ? 'Active' : 'Expired';
      case SubscriptionStatus.inactive:
        return 'Inactive';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
      case SubscriptionStatus.expired:
        return 'Expired';
      case SubscriptionStatus.unknown:
        return 'Unknown';
    }
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id']?.toString() ?? '',
      organizationId: json['organizationId']?.toString() ?? '',
      planName: json['planName']?.toString() ?? 'Unknown Plan',
      status: _parseStatus(json['status']?.toString()),
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'].toString())
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'].toString())
          : null,
      maxUsers: json['maxUsers'] != null
          ? int.tryParse(json['maxUsers'].toString())
          : null,
      maxDevices: json['maxDevices'] != null
          ? int.tryParse(json['maxDevices'].toString())
          : null,
      verificationLimit: json['verificationLimit'] != null
          ? int.tryParse(json['verificationLimit'].toString())
          : null,
      verificationUsed:
          int.tryParse(json['verificationUsed']?.toString() ?? '') ?? 0,
      verificationRemaining: json['verificationRemaining'] != null
          ? int.tryParse(json['verificationRemaining'].toString())
          : null,
      usagePeriodStart: json['usagePeriodStart'] != null
          ? DateTime.tryParse(json['usagePeriodStart'].toString())
          : null,
      usagePeriodEnd: json['usagePeriodEnd'] != null
          ? DateTime.tryParse(json['usagePeriodEnd'].toString())
          : null,
    );
  }

  static SubscriptionStatus _parseStatus(String? value) {
    switch (value?.toLowerCase()) {
      case 'active':
        return SubscriptionStatus.active;
      case 'inactive':
        return SubscriptionStatus.inactive;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      case 'expired':
        return SubscriptionStatus.expired;
      default:
        return SubscriptionStatus.unknown;
    }
  }
}
