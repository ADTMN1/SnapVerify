import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import 'home_tab.dart';
import 'history_tab.dart';
import 'camera_tab.dart';
import 'manage/payment_account_management_screen.dart';
import 'manage_tab.dart';
import 'subscription_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _activeTabIndex = 0;
  bool _planSheetOpen = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isWaiter = authState.role == UserRole.waiter;
    final canManage = authState.role.canManage;
    final cameraIdx = isWaiter ? 1 : 2;

    final children = <Widget>[
      if (!isWaiter)
        HomeTab(
          onNavigate: _switchTab,
          onScan: () => _handleCameraTap(cameraIdx),
        ),
      const HistoryTab(),
      CameraTab(isActive: _activeTabIndex == cameraIdx),
      const PaymentAccountManagementScreen(isTab: true),
      if (canManage) const ManageTab(),
    ];

    // Reset active tab if it's now out of bounds
    if (_activeTabIndex >= children.length) {
      _activeTabIndex = 0;
    }

    return Scaffold(
      backgroundColor: AppTokens.obsidian950,
      body: SafeArea(
        child: IndexedStack(index: _activeTabIndex, children: children),
      ),
      bottomNavigationBar: _buildBottomNavBar(
        isWaiter: isWaiter,
        canManage: canManage,
        cameraIdx: cameraIdx,
      ),
    );
  }

  Widget _buildBottomNavBar({
    required bool isWaiter,
    required bool canManage,
    required int cameraIdx,
  }) {
    // Waiter layout: History, Camera, Accounts
    // Other roles: Home, History, Camera, Accounts, [Manage]
    final int historyIdx = isWaiter ? 0 : 1;
    final int accountsIdx = isWaiter ? 2 : 3;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space2xl,
        vertical: AppTokens.spaceLg,
      ),
      decoration: BoxDecoration(
        color: AppTokens.obsidian900,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTokens.navBarRadius),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!isWaiter) _buildNavItem(0, Icons.home_rounded, 'Home'),
          _buildNavItem(historyIdx, Icons.history_rounded, 'History'),
          _activeTabIndex == cameraIdx
              ? const SizedBox(width: AppTokens.navCameraSize)
              : _buildCameraButton(cameraIdx),
          _buildNavItem(
            accountsIdx,
            Icons.account_balance_wallet_outlined,
            'Accounts',
          ),
          if (canManage) _buildNavItem(4, Icons.settings_rounded, 'Manage'),
        ],
      ),
    );
  }

  void _switchTab(int index, {bool closePlanSheet = true}) {
    if (closePlanSheet) _dismissPlanSheet();
    setState(() {
      _activeTabIndex = index;
    });
  }

  void _dismissPlanSheet() {
    if (!_planSheetOpen || !mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) navigator.pop(false);
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _activeTabIndex == index;
    final navColor = isActive
        ? AppTokens.accent
        : AppTokens.white.withValues(alpha: AppTokens.alphaSecondary);
    return GestureDetector(
      onTap: () => _switchTab(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: navColor, size: AppTokens.navIconSize),
          const SizedBox(height: AppTokens.spaceXs),
          Text(
            label,
            style:
                (isActive
                        ? AppText.navLabelActive
                        : AppText.navLabelInactive)
                    .copyWith(color: navColor),
          ),
        ],
      ),
    );
  }

  void _handleCameraTap(int cameraIdx) {
    if (!mounted) return;
    final subscription = ref.read(authNotifierProvider).subscription;
    if (subscription != null &&
        subscription.isActive &&
        !subscription.isQuotaExceeded) {
      _switchTab(cameraIdx, closePlanSheet: false);
      return;
    }
    _showPlanSheet(cameraIdx: cameraIdx);
  }

  Future<void> _showPlanSheet({int? cameraIdx}) async {
    if (_planSheetOpen || !mounted) return;
    _planSheetOpen = true;
    final container = ProviderScope.containerOf(context);
    final canOpenCamera = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.transparent,
      useRootNavigator: true,
      isDismissible: true,
      enableDrag: true,
      builder: (_) =>
          ProviderScope(parent: container, child: const SubscriptionSheet()),
    );
    _planSheetOpen = false;
    if (!mounted) return;

    await ref.read(authNotifierProvider.notifier).refreshSubscription();
    if (canOpenCamera == true && cameraIdx != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _switchTab(cameraIdx, closePlanSheet: false);
      });
    }
  }

  Widget _buildCameraButton(int cameraIdx) {
    return GestureDetector(
      onTap: () => _handleCameraTap(cameraIdx),
      child: Container(
        width: AppTokens.navCameraSize,
        height: AppTokens.navCameraSize,
        decoration: BoxDecoration(
          color: AppTokens.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTokens.accent.withValues(alpha: AppTokens.navGlowAlpha),
              blurRadius: AppTokens.shadowBlurMedium,
              spreadRadius: AppTokens.shadowSpreadMedium,
            ),
          ],
        ),
        child: Icon(
          Icons.camera_alt_rounded,
          color: AppTokens.obsidian900,
          size: AppTokens.navIconSize,
        ),
      ),
    );
  }
}
