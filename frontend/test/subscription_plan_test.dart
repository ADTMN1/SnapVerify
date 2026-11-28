import 'package:flutter_test/flutter_test.dart';
import 'package:snapverify/domain/entities/subscription_plan.dart';

void main() {
  test('parses and displays a dynamic month-based duration', () {
    final plan = SubscriptionPlan.fromJson({
      'id': 'five_months',
      'name': '5 Months',
      'price': 60000,
      'currency': 'ETB',
      'durationDays': null,
      'durationMonths': 5,
      'isLifetime': false,
    });

    expect(plan.durationMonths, 5);
    expect(plan.durationLabel, '5 months');
    expect(plan.summary, contains('5 months'));
  });

  test('displays explicit lifetime plans as no expiry', () {
    final plan = SubscriptionPlan.fromJson({
      'id': 'lifetime_plan',
      'name': 'Lifetime',
      'price': 0,
      'currency': 'ETB',
      'durationDays': null,
      'durationMonths': null,
      'isLifetime': true,
    });

    expect(plan.durationLabel, 'No expiry');
    expect(plan.summary, contains('No expiry'));
  });

  test('displays legacy day-based durations', () {
    final plan = SubscriptionPlan.fromJson({
      'id': 'monthly',
      'name': 'Monthly',
      'price': 1500,
      'currency': 'ETB',
      'durationDays': 30,
      'durationMonths': null,
      'isLifetime': false,
    });

    expect(plan.durationDays, 30);
    expect(plan.durationLabel, '30 days');
  });

  test('summary always reflects the plan duration', () {
    final plan = SubscriptionPlan.fromJson({
      'id': 'five_months',
      'name': '5 Months',
      'price': 60000,
      'currency': 'ETB',
      'durationMonths': 5,
      'verificationLimit': 25,
      'isLifetime': false,
    });

    expect(plan.summary, '5 months · 25 verifications');
  });
}
