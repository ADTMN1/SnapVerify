import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/sv_app_shell.dart';
import '../widgets/sv_loader.dart';

class BusinessSwitcherScreen extends ConsumerWidget {
  final bool isInitialSelection;

  const BusinessSwitcherScreen({super.key, this.isInitialSelection = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final authNotifier = ref.read(authNotifierProvider.notifier);

    final memberships = authState.availableOrganizations;
    final isLoading = authState.status == AuthStatus.loading;

    final greeting = authState.pendingUser?.fullName != null
        ? 'Hello, ${authState.pendingUser!.fullName}! 👋'
        : authState.user?.fullName != null
        ? 'Hello, ${authState.user!.fullName}! 👋'
        : 'Welcome! 👋';

    return SvAppShell(
      title: isInitialSelection ? 'Choose Business' : 'Switch Business',
      subtitle: isInitialSelection
          ? 'Select a business to continue.'
          : 'Select a business to switch to.',
      showBack: !isInitialSelection,
      scrollable: false,
      child: isLoading
          ? const Center(child: SvLoader.page(color: AppTokens.inkMuted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  greeting,
                  style: AppText.titleLarge.copyWith(color: AppTokens.ink),
                ),
                const SizedBox(height: AppTokens.spaceXl),
                Expanded(
                  child: ListView.separated(
                    itemCount: memberships.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppTokens.spaceMd),
                    itemBuilder: (context, index) {
                      final m = memberships[index];
                      final isSelected =
                          !isInitialSelection &&
                          authState.organization?.id == m.organizationId;
                      return _BusinessCard(
                        membership: m,
                        isSelected: isSelected,
                        onTap: () async {
                          if (isInitialSelection) {
                            await authNotifier.selectBusiness(m.organizationId);
                          } else {
                            await authNotifier.switchBusiness(m.organizationId);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
                if (authState.status == AuthStatus.error) ...[
                  const SizedBox(height: AppTokens.spaceLg),
                  SvSurfaceCard(
                    color: AppTokens.dangerBg,
                    borderColor: AppTokens.danger,
                    padding: const EdgeInsets.all(AppTokens.errorPadding),
                    child: Text(
                      authState.errorMessage ?? 'An error occurred',
                      style: AppText.bodySmall.copyWith(
                        color: AppTokens.danger,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final UserBusinessMembership membership;
  final bool isSelected;
  final VoidCallback onTap;

  const _BusinessCard({
    required this.membership,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SvSurfaceCard(
      onTap: onTap,
      color: isSelected ? AppTokens.ice100 : AppTokens.white,
      borderColor: AppTokens.ice200,
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      child: Row(
        children: [
          Container(
            width: AppTokens.statTileSize,
            height: AppTokens.statTileSize,
            decoration: BoxDecoration(
              color: AppTokens.surfaceLight,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: AppTokens.ink,
              size: AppTokens.componentIconLg,
            ),
          ),
          const SizedBox(width: AppTokens.spaceLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  membership.organizationName,
                  style: AppText.titleSmall.copyWith(color: AppTokens.ink),
                ),
                const SizedBox(height: AppTokens.spaceSm),
                Row(
                  children: [
                    SvStatusPill(
                      membership.role.label,
                      tone: _roleTone(membership.role),
                      small: true,
                    ),
                    if (membership.branchId != null) ...[
                      const SizedBox(width: AppTokens.spaceSm),
                      const Icon(
                        Icons.location_on_outlined,
                        size: AppTokens.componentIconSm,
                        color: AppTokens.inkMuted,
                      ),
                      const SizedBox(width: AppTokens.spaceXs),
                      Text(
                        'Branch',
                        style: AppText.caption.copyWith(
                          color: AppTokens.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.spaceSm),
          Icon(
            isSelected
                ? Icons.check_circle_rounded
                : Icons.chevron_right_rounded,
            color: isSelected ? AppTokens.ink : AppTokens.inkMuted,
            size: AppTokens.componentIconLg,
          ),
        ],
      ),
    );
  }

  SvTone _roleTone(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return SvTone.warning;
      case UserRole.manager:
        return SvTone.info;
      case UserRole.cashier:
        return SvTone.success;
      case UserRole.waiter:
        return SvTone.info;
      case UserRole.unknown:
        return SvTone.neutral;
    }
  }
}
