import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/subscription.dart';
import '../../theme/app_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../widgets/sv_loader.dart';
import 'payment_page.dart';

class SubscriptionSheet extends ConsumerStatefulWidget {
  const SubscriptionSheet({super.key, this.startOnPlanList = false});

  final bool startOnPlanList;

  @override
  ConsumerState<SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends ConsumerState<SubscriptionSheet> {
  bool _showPlans = false;

  @override
  void initState() {
    super.initState();
    _showPlans = widget.startOnPlanList;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(subscriptionCheckoutProvider.notifier);
      notifier.reset();

      final subscription = ref.read(authNotifierProvider).subscription;
      if (!widget.startOnPlanList &&
          subscription != null &&
          subscription.isActive &&
          !subscription.isQuotaExceeded) {
        return;
      }

      notifier.loadPlans();
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
    if (!mounted || ref.read(subscriptionCheckoutProvider).checkout == null) {
      return;
    }

    final paid = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<bool>(MaterialPageRoute(builder: (_) => const PaymentPage()));
    if (!mounted) return;

    notifier.reset();
    if (paid == true) {
      Navigator.of(context).pop(true);
      return;
    }

    await notifier.loadPlans();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final subscription = authState.subscription;
    final checkoutState = ref.watch(subscriptionCheckoutProvider);
    final isActive = subscription?.isActive ?? false;
    final canUseCamera = isActive && !(subscription?.isQuotaExceeded ?? false);
    final title = widget.startOnPlanList
        ? 'Change plan'
        : canUseCamera
        ? 'Plan active'
        : subscription?.isQuotaExceeded ?? false
        ? 'Limit reached'
        : 'Choose a plan';

    return Container(
      decoration: const BoxDecoration(
        color: AppTokens.headerBase,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radius2xl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppTokens.sheetHorizontalPadding,
        AppTokens.spaceLg,
        AppTokens.sheetHorizontalPadding,
        AppTokens.sheetHorizontalPadding +
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: AppTokens.handleWidth,
                height: AppTokens.handleHeight,
                decoration: BoxDecoration(
                  color: AppTokens.inkMuted,
                  borderRadius: BorderRadius.circular(AppTokens.radiusXs),
                ),
              ),
            ),
            const SizedBox(height: AppTokens.spaceLg),
            Row(
              children: [
                Text(
                  title,
                  style: AppTokens.manrope(
                    size: AppTokens.textSubtitle,
                    weight: FontWeight.w800,
                    color: AppTokens.white,
                  ),
                ),
                const Spacer(),
                if (canUseCamera)
                  const Padding(
                    padding: EdgeInsets.only(right: AppTokens.statTitleGap),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: AppTokens.accent,
                      size: AppTokens.backButtonIconSize,
                    ),
                  ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(false),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  child: const Padding(
                    padding: EdgeInsets.all(AppTokens.spaceXs),
                    child: Icon(
                      Icons.close_rounded,
                      size: AppTokens.backButtonIconSize,
                      color: AppTokens.ice400,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Text(
              canUseCamera
                  ? subscription!.verificationSummary
                  : subscription?.isQuotaExceeded ?? false
                  ? 'Upgrade to continue verifying.'
                  : 'Simple plans. Pay with Telebirr.',
              style: AppTokens.dmSans(
                size: AppTokens.textCaption,
                weight: FontWeight.w400,
                color: AppTokens.ice400,
              ),
            ),
            if (subscription != null) ...[
              const SizedBox(height: AppTokens.badgePaddingH),
              _CurrentPlanChip(subscription: subscription),
            ],
            const SizedBox(height: AppTokens.spaceLg),
            if (!_showPlans && canUseCamera)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(
                        Icons.camera_alt_rounded,
                        size: AppTokens.backButtonIconSize,
                      ),
                      label: const Text('Continue to Camera'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTokens.accent,
                        foregroundColor: AppTokens.obsidian950,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTokens.badgePaddingH,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusMd,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceXs),
                  TextButton.icon(
                    onPressed: _openPlanList,
                    icon: const Icon(
                      Icons.swap_horiz_rounded,
                      size: AppTokens.checkIconSize,
                    ),
                    label: const Text('Change Plan'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTokens.ice200,
                    ),
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
              const SizedBox(height: AppTokens.spaceMd),
              Text(
                checkoutState.error!,
                style: AppTokens.dmSans(
                  size: AppTokens.textLabel,
                  weight: FontWeight.w400,
                  color: AppTokens.error,
                ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.badgeSmallPaddingH,
      ),
      decoration: BoxDecoration(
        color: AppTokens.obsidian900,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.obsidian700),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            size: AppTokens.checkIconSize,
            color: AppTokens.accent,
          ),
          const SizedBox(width: AppTokens.spaceSm),
          Expanded(
            child: Text(
              'Current: ${subscription.planLabel}',
              style: AppTokens.manrope(
                size: AppTokens.textCaption,
                weight: FontWeight.w600,
                color: AppTokens.white,
              ),
            ),
          ),
          Text(
            summary,
            style: AppTokens.dmSans(
              size: AppTokens.textCaption,
              weight: FontWeight.w400,
              color: AppTokens.ice200,
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
        padding: EdgeInsets.symmetric(vertical: AppTokens.space3xl),
        child: Center(child: SvLoader.page()),
      );
    }

    if (state.plans.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.space3xl),
        child: Center(
          child: Text(
            'No plans available',
            style: AppTokens.dmSans(
              size: AppTokens.textLabel,
              weight: FontWeight.w400,
              color: AppTokens.ice400,
            ),
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
            margin: const EdgeInsets.only(bottom: AppTokens.spaceMd),
            padding: const EdgeInsets.all(AppTokens.spaceMd),
            decoration: BoxDecoration(
              color: AppTokens.warning.withValues(alpha: AppTokens.alphaSubtle),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(
                color: AppTokens.warning.withValues(
                  alpha: AppTokens.alphaStrong,
                ),
              ),
            ),
            child: Text(
              'Only the owner can change plans.',
              style: AppTokens.dmSans(
                size: AppTokens.textCaption,
                weight: FontWeight.w400,
                color: AppTokens.warning,
              ),
            ),
          ),
        ...state.plans.map(
          (plan) => InkWell(
            onTap: canPurchase && !state.isLoading
                ? () => onSelect(plan.id)
                : null,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: AppTokens.spaceSm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceMd,
                vertical: AppTokens.spaceMd,
              ),
              decoration: BoxDecoration(
                color: AppTokens.obsidian950,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(color: AppTokens.obsidian700),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: AppTokens.manrope(
                            size: AppTokens.textBodySmall,
                            weight: FontWeight.w700,
                            color: AppTokens.white,
                          ),
                        ),
                        const SizedBox(height: AppTokens.spaceXs),
                        Text(
                          plan.summary,
                          style: AppTokens.dmSans(
                            size: AppTokens.textOverline,
                            weight: FontWeight.w400,
                            color: AppTokens.ice400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTokens.badgeSmallPaddingH),
                  Text(
                    plan.price == 0 ? 'Free' : '${plan.price} ${plan.currency}',
                    style: AppTokens.manrope(
                      size: AppTokens.textLabel,
                      weight: FontWeight.w700,
                      color: AppTokens.accent,
                    ),
                  ),
                  const SizedBox(width: AppTokens.statTitleGap),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: AppTokens.textLabel,
                    color: AppTokens.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasActivePlan) ...[
          const SizedBox(height: AppTokens.spaceXs),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onContinue,
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: AppTokens.checkIconSize,
              ),
              label: const Text('Keep current plan'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTokens.obsidian700,
                foregroundColor: AppTokens.white,
                padding: const EdgeInsets.symmetric(
                  vertical: AppTokens.spaceMd,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppTokens.spaceXs),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: onRecheck,
            icon: const Icon(
              Icons.refresh_rounded,
              size: AppTokens.checkIconSize,
            ),
            label: const Text('Already paid? Check again'),
            style: TextButton.styleFrom(foregroundColor: AppTokens.ice200),
          ),
        ),
      ],
    );
  }
}
