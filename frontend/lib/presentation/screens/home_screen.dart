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
  int? _hoveredNavIndex;
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
      backgroundColor: AppTokens.ice50,
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
        horizontal: AppTokens.spaceLg,
        vertical: AppTokens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: AppTokens.ice50,
        border: const Border(
          top: BorderSide(
            color: AppTokens.ice200,
            width: AppTokens.componentBorderWidth,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppTokens.inkOverlay14,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
    final isHovered = _hoveredNavIndex == index;
    final iconColor = isActive ? AppTokens.white : AppTokens.inkMuted;
    final labelColor = isActive ? AppTokens.ink : AppTokens.inkMuted;
    final pillColor = isActive
        ? AppTokens.obsidian950
        : isHovered
        ? AppTokens.obsidian800
        : AppTokens.transparent;
    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredNavIndex = index),
        onExit: (_) => setState(() {
          if (_hoveredNavIndex == index) _hoveredNavIndex = null;
        }),
        child: GestureDetector(
          onTap: () => _switchTab(index),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: AppTokens.navActivePillWidth,
                height: AppTokens.navActivePillHeight,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: AppTokens.navIconSize,
                ),
              ),
              const SizedBox(height: AppTokens.spaceXs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (isActive
                            ? AppText.navLabelActive
                            : AppText.navLabelInactive)
                        .copyWith(color: labelColor),
              ),
            ],
          ),
        ),
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
          color: AppTokens.cameraActionBackground,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTokens.cameraActionBackground.withValues(
                alpha: AppTokens.navGlowAlpha,
              ),
              blurRadius: AppTokens.shadowBlurMedium,
              spreadRadius: AppTokens.shadowSpreadMedium,
            ),
          ],
        ),
        child: Icon(
          Icons.camera_alt_rounded,
          color: AppTokens.cameraActionForeground,
          size: AppTokens.navIconSize,
        ),
      ),
    );
  }
}
