import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/tailwind.dart';
import '../../domain/entities/subscription.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import 'payment_page.dart';

class SubscriptionSheet extends ConsumerStatefulWidget {
  const SubscriptionSheet({super.key});

  @override
  ConsumerState<SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends ConsumerState<SubscriptionSheet> {
  bool _showPlans = false;

  @override
  void initState() {
    super.initState();
    ref.read(subscriptionCheckoutProvider.notifier).reset();
    final subscription = ref.read(authNotifierProvider).subscription;
    if (subscription != null &&
        subscription.isActive &&
        !subscription.isQuotaExceeded) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(subscriptionCheckoutProvider.notifier).loadPlans();
      }
    });
  }

  void _openPlanList() {
    setState(() => _showPlans = true);
    ref.read(subscriptionCheckoutProvider.notifier).loadPlans();
  }

  Future<void> _selectPlan(String planId) async {
    final notifier = ref.read(subscriptionCheckoutProvider.notifier);

    if (planId == 'free') {
      final activated = await notifier.activateFree();
      if (activated && mounted) Navigator.of(context).pop(true);
      return;
    }

    await notifier.startCheckout(planId);
    if (!mounted ||
        ref.read(subscriptionCheckoutProvider).checkout == null) {
      return;
    }

    final paid = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<bool>(MaterialPageRoute(builder: (_) => const PaymentPage()));
    if (!mounted) return;

    notifier.reset();
    if (paid == true) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final subscription = authState.subscription;
    final checkoutState = ref.watch(subscriptionCheckoutProvider);
    final isActive = subscription?.isActive ?? false;
    final canUseCamera = isActive && !(subscription?.isQuotaExceeded ?? false);

    return Container(
      decoration: const BoxDecoration(
        color: TwColors.primaryBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom + MediaQuery.of(context).padding.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: TwColors.slate600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  canUseCamera
                      ? 'Plan active'
                      : subscription?.isQuotaExceeded ?? false
                          ? 'Limit reached'
                          : 'Choose a plan',
                  style: const TextStyle(
                    color: TwColors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (canUseCamera)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.check_circle_rounded,
                        color: TwColors.brightGreen, size: 18),
                  ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(false),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: TwColors.slate400),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              canUseCamera
                  ? subscription!.verificationSummary
                  : subscription?.isQuotaExceeded ?? false
                      ? 'Upgrade to continue verifying.'
                      : 'Simple plans. Pay with Telebirr.',
              style: TextStyle(
                color: TwColors.slate400,
                fontSize: 12.5,
              ),
            ),
            if (subscription != null) ...[
              const SizedBox(height: 14),
              _CurrentPlanChip(subscription: subscription),
            ],
            const SizedBox(height: 16),
            if (!_showPlans && canUseCamera)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Continue to Camera'),
                      style: FilledButton.styleFrom(
                        backgroundColor: TwColors.brightGreen,
                        foregroundColor: TwColors.slate950,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: _openPlanList,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('Change Plan'),
                    style: TextButton.styleFrom(
                        foregroundColor: TwColors.slate300),
                  ),
                ],
              )
            else
              _PlanSelection(
                state: checkoutState,
                canPurchase: authState.role == UserRole.owner,
                hasActivePlan: canUseCamera,
                onContinue: () => Navigator.of(context).pop(true),
                onSelect: _selectPlan,
                onRecheck: _recheck,
              ),
            if (checkoutState.error != null) ...[
              const SizedBox(height: 12),
              Text(
                checkoutState.error!,
                style: const TextStyle(color: TwColors.red400, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _recheck() async {
    final subscription = await ref
        .read(authNotifierProvider.notifier)
        .refreshSubscription();
    if (subscription != null &&
        subscription.isActive &&
        !subscription.isQuotaExceeded &&
        mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _CurrentPlanChip extends StatelessWidget {
  final Subscription subscription;

  const _CurrentPlanChip({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final summary = subscription.verificationLimit == null
        ? 'Unlimited'
        : '${subscription.verificationRemaining ?? 0}/${subscription.verificationLimit} left';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TwColors.slate800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TwColors.slate700),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded,
              size: 16, color: TwColors.brightGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Current: ${subscription.planLabel}',
              style: const TextStyle(
                color: TwColors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            summary,
            style: const TextStyle(
              color: TwColors.slate300,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanSelection extends StatelessWidget {
  final SubscriptionCheckoutState state;
  final bool canPurchase;
  final bool hasActivePlan;
  final VoidCallback onContinue;
  final ValueChanged<String> onSelect;
  final VoidCallback onRecheck;

  const _PlanSelection({
    required this.state,
    required this.canPurchase,
    required this.hasActivePlan,
    required this.onContinue,
    required this.onSelect,
    required this.onRecheck,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.plans.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: TwColors.brightGreen)),
      );
    }

    if (state.plans.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            'No plans available',
            style: TextStyle(color: TwColors.slate400, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!canPurchase)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TwColors.amber400.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TwColors.amber400.withValues(alpha: 0.35)),
            ),
            child: const Text(
              'Only the owner can change plans.',
              style: TextStyle(color: TwColors.amber300, fontSize: 12.5),
            ),
          ),
        ...state.plans.map(
          (plan) => InkWell(
            onTap: canPurchase && !state.isLoading
                ? () => onSelect(plan.id)
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: TwColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TwColors.slate700),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: const TextStyle(
                            color: TwColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          plan.summary,
                          style: const TextStyle(
                            color: TwColors.slate400,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    plan.price == 0 ? 'Free' : '${plan.price} ${plan.currency}',
                    style: const TextStyle(
                      color: TwColors.brightGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: TwColors.slate500,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasActivePlan) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Keep current plan'),
              style: FilledButton.styleFrom(
                backgroundColor: TwColors.slate700,
                foregroundColor: TwColors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: onRecheck,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Already paid? Check again'),
            style: TextButton.styleFrom(foregroundColor: TwColors.slate300),
          ),
        ),
      ],
    );
  }
}
