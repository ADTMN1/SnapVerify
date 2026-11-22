import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/tailwind.dart';
import '../../domain/entities/subscription_checkout.dart';
import '../providers/subscription_provider.dart';

class PaymentPage extends ConsumerStatefulWidget {
  const PaymentPage({super.key});

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  final _referenceController = TextEditingController();

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checkoutState = ref.watch(subscriptionCheckoutProvider);
    final checkout = checkoutState.checkout;

    return Scaffold(
      backgroundColor: TwColors.primaryBg,
      appBar: AppBar(
        title: const Text(
          'Payment',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: TwColors.primaryBg,
        foregroundColor: TwColors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: ColoredBox(color: TwColors.slate700),
        ),
      ),
      body: checkout == null
          ? const Center(
              child: Text(
                'No payment selected',
                style: TextStyle(color: TwColors.slate400),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PaymentCard(checkout: checkout),
                    const SizedBox(height: 16),
                    const Text(
                      'Pay the amount above to the account shown, then paste the transaction reference.',
                      style: TextStyle(color: TwColors.slate400, fontSize: 12.5),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _referenceController,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(color: TwColors.white),
                      decoration: InputDecoration(
                        labelText: 'Transaction reference',
                        labelStyle: const TextStyle(color: TwColors.slate400),
                        filled: true,
                        fillColor: TwColors.cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: TwColors.slate700),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: TwColors.slate700),
                        ),
                      ),
                    ),
                    if (checkoutState.error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        checkoutState.error!,
                        style: const TextStyle(color: TwColors.red400, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: checkoutState.isLoading ? null : _verify,
                        style: FilledButton.styleFrom(
                          backgroundColor: TwColors.brightGreen,
                          foregroundColor: TwColors.slate900,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: checkoutState.isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Verify & activate',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _verify() async {
    final active = await ref
        .read(subscriptionCheckoutProvider.notifier)
        .verify(_referenceController.text.trim());
    if (!mounted || !active) return;
    ref.read(subscriptionCheckoutProvider.notifier).reset();
    Navigator.of(context).pop(true);
  }
}

class _PaymentCard extends StatelessWidget {
  final SubscriptionCheckout checkout;

  const _PaymentCard({required this.checkout});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TwColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TwColors.slate700),
      ),
      child: Column(
        children: [
          _PaymentRow(label: 'Plan', value: _labelForPlan(checkout.planName)),
          const SizedBox(height: 12),
          _PaymentRow(
            label: 'Amount',
            value: '${checkout.amount} ${checkout.currency}',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: TwColors.slate700, height: 1),
          ),
          _PaymentRow(
            label: 'Telebirr account',
            value: checkout.payToAccountNumber,
          ),
          if (checkout.payToAccountName != null) ...[
            const SizedBox(height: 12),
            _PaymentRow(
              label: 'Account name',
              value: checkout.payToAccountName!,
            ),
          ],
          const SizedBox(height: 12),
          _PaymentRow(label: 'Reference', value: checkout.reference),
        ],
      ),
    );
  }

  String _labelForPlan(String planName) {
    switch (planName.toLowerCase()) {
      case 'free':
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
      default:
        return planName
            .split(RegExp(r'[_\s]+'))
            .map((word) => word.isEmpty
                ? word
                : word[0].toUpperCase() + word.substring(1).toLowerCase())
            .join(' ');
    }
  }
}

class _PaymentRow extends StatelessWidget {
  final String label;
  final String value;

  const _PaymentRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: TwColors.slate400, fontSize: 12.5)),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: TwColors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
