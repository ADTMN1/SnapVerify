import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/subscription.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../widgets/sv_app_shell.dart';
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
        color: AppTokens.ice50,
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
                  color: AppTokens.ice200,
                  borderRadius: BorderRadius.circular(AppTokens.radiusXs),
                ),
              ),
            ),
            const SizedBox(height: AppTokens.spaceLg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppText.titleMedium.copyWith(color: AppTokens.ink),
                  ),
                ),
                if (canUseCamera)
                  const Padding(
                    padding: EdgeInsets.only(right: AppTokens.spaceSm),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: AppTokens.ink,
                      size: AppTokens.backButtonIconSize,
                      semanticLabel: 'Plan active',
                    ),
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  color: AppTokens.inkMuted,
                  iconSize: AppTokens.backButtonIconSize,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTokens.white,
                    side: const BorderSide(color: AppTokens.ice200),
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
              style: AppText.bodySmall.copyWith(color: AppTokens.inkMuted),
            ),
            if (subscription != null) ...[
              const SizedBox(height: AppTokens.spaceMd),
              _CurrentPlanChip(subscription: subscription),
            ],
            const SizedBox(height: AppTokens.spaceLg),
            if (!_showPlans && canUseCamera)
              Column(
                children: [
                  SvActionButton(
                    label: 'Continue to Camera',
                    icon: Icons.camera_alt_rounded,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                  const SizedBox(height: AppTokens.spaceSm),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _openPlanList,
                      icon: const Icon(
                        Icons.swap_horiz_rounded,
                        size: AppTokens.componentIconMd,
                      ),
                      label: const Text('Change Plan'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTokens.ink,
                        textStyle: AppText.labelLarge,
                      ),
                    ),
                  ),
                ],
              )
            else
              _PlanSelection(
                state: checkoutState,
                canPurchase: authState.role == UserRole.owner,
                hasActivePlan: canUseCamera,
                currentPlanId: subscription?.planName,
                onContinue: () => Navigator.of(context).pop(true),
                onSelect: _selectPlan,
                onRecheck: _recheck,
              ),
            if (checkoutState.error != null) ...[
              const SizedBox(height: AppTokens.spaceMd),
              SvSurfaceCard(
                padding: const EdgeInsets.all(AppTokens.spaceMd),
                color: AppTokens.dangerBg,
                borderColor: AppTokens.errorStrong.withValues(
                  alpha: AppTokens.alphaStrong,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppTokens.errorStrong,
                      size: AppTokens.componentIconMd,
                    ),
                    const SizedBox(width: AppTokens.spaceSm),
                    Expanded(
                      child: Text(
                        checkoutState.error!,
                        style: AppText.bodySmall.copyWith(
                          color: AppTokens.errorStrong,
                        ),
                      ),
                    ),
                  ],
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
    return SvSurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceMd,
      ),
      child: Row(
        children: [
          Container(
            width: AppTokens.statTileSize,
            height: AppTokens.statTileSize,
            decoration: BoxDecoration(
              color: AppTokens.ice100,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              size: AppTokens.componentIconMd,
              color: AppTokens.ink,
            ),
          ),
          const SizedBox(width: AppTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current: ${subscription.planLabel}',
                  style: AppText.labelLarge.copyWith(color: AppTokens.ink),
                ),
                const SizedBox(height: AppTokens.spaceXs),
                Text(
                  summary,
                  style: AppText.caption.copyWith(color: AppTokens.inkMuted),
                ),
              ],
            ),
          ),
          SvStatusPill(
            subscription.statusLabel,
            tone: SvTone.neutral,
            small: true,
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
  final String? currentPlanId;
  final VoidCallback onContinue;
  final ValueChanged<String> onSelect;
  final VoidCallback onRecheck;

  const _PlanSelection({
    required this.state,
    required this.canPurchase,
    required this.hasActivePlan,
    required this.currentPlanId,
    required this.onContinue,
    required this.onSelect,
    required this.onRecheck,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.plans.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppTokens.space3xl),
        child: Center(child: SvLoader.page(color: AppTokens.inkMuted)),
      );
    }

    if (state.plans.isEmpty) {
      return const SvEmptyState(
        icon: Icons.workspace_premium_outlined,
        title: 'No plans available',
        subtitle: 'Check back later or try again.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!canPurchase)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.spaceMd),
            child: SvSurfaceCard(
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              color: AppTokens.ice100,
              borderColor: AppTokens.ice200,
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: AppTokens.ink,
                    size: AppTokens.componentIconMd,
                  ),
                  const SizedBox(width: AppTokens.spaceSm),
                  Expanded(
                    child: Text(
                      'Only the owner can change plans.',
                      style: AppText.bodySmall.copyWith(color: AppTokens.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ...state.plans.map((plan) {
          final isCurrent = currentPlanId == plan.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.spaceSm),
            child: SvSurfaceCard(
              onTap: canPurchase && !state.isLoading
                  ? () => onSelect(plan.id)
                  : null,
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              borderColor: AppTokens.ice200,
              color: isCurrent ? AppTokens.ice100 : AppTokens.white,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                plan.name,
                                style: AppText.labelLarge.copyWith(
                                  color: AppTokens.ink,
                                ),
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: AppTokens.spaceSm),
                              const SvStatusPill(
                                'Current',
                                tone: SvTone.neutral,
                                small: true,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppTokens.spaceXs),
                        Text(
                          plan.summary,
                          style: AppText.caption.copyWith(
                            color: AppTokens.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceMd),
                  Text(
                    plan.price == 0 ? 'Free' : '${plan.price} ${plan.currency}',
                    style: AppText.labelLarge.copyWith(color: AppTokens.ink),
                  ),
                  const SizedBox(width: AppTokens.spaceSm),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: AppTokens.textLabel,
                    color: canPurchase && !state.isLoading
                        ? AppTokens.inkMuted
                        : AppTokens.ice200,
                  ),
                ],
              ),
            ),
          );
        }),
        if (hasActivePlan) ...[
          const SizedBox(height: AppTokens.spaceXs),
          SvActionButton(
            label: 'Keep current plan',
            icon: Icons.arrow_back_rounded,
            tone: SvTone.neutral,
            onPressed: onContinue,
          ),
        ],
        const SizedBox(height: AppTokens.spaceSm),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: state.isLoading ? null : onRecheck,
            icon: state.isLoading
                ? const SvLoader.inline(color: AppTokens.inkMuted)
                : const Icon(
                    Icons.refresh_rounded,
                    size: AppTokens.componentIconMd,
                  ),
            label: const Text('Already paid? Check again'),
            style: TextButton.styleFrom(
              foregroundColor: AppTokens.ink,
              textStyle: AppText.labelLarge,
            ),
          ),
        ),
      ],
    );
  }
}
