import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/tailwind.dart';
import '../../presentation/providers/auth_provider.dart';
import 'home_tab.dart';
import 'history_tab.dart';
import 'camera_tab.dart';
import 'qr_tab.dart';
import 'manage_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _activeTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isWaiter = authState.role == UserRole.waiter;
    final canManage = authState.role.canManage;

    final children = <Widget>[
      if (!isWaiter) HomeTab(onNavigate: _switchTab),
      const HistoryTab(),
      const CameraTab(),
      QRTab(isActive: _activeTabIndex == (isWaiter ? 2 : 3)),
      if (canManage) const ManageTab(),
    ];

    // Reset active tab if it's now out of bounds
    if (_activeTabIndex >= children.length) {
      _activeTabIndex = 0;
    }

    return Scaffold(
      backgroundColor: TwColors.slate950,
      body: SafeArea(
        child: IndexedStack(
          index: _activeTabIndex,
          children: children,
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(
        isWaiter: isWaiter,
        canManage: canManage,
      ),
    );
  }

  Widget _buildBottomNavBar({
    required bool isWaiter,
    required bool canManage,
  }) {
    // Waiter layout: History, Camera, QR
    // Other roles: Home, History, Camera, QR, [Manage]
    final int historyIdx = isWaiter ? 0 : 1;
    final int cameraIdx = isWaiter ? 1 : 2;
    final int qrIdx = isWaiter ? 2 : 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: TwColors.slate900,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(32),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!isWaiter) _buildNavItem(0, Icons.home_rounded, 'Home'),
          _buildNavItem(historyIdx, Icons.history_rounded, 'History'),
          _activeTabIndex == cameraIdx
              ? const SizedBox(width: 48)
              : _buildCameraButton(cameraIdx),
          _buildNavItem(qrIdx, Icons.qr_code_scanner_rounded, 'QR'),
          if (canManage) _buildNavItem(4, Icons.settings_rounded, 'Manage'),
        ],
      ),
    );
  }

  void _switchTab(int index) {
    setState(() {
      _activeTabIndex = index;
    });
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _activeTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTabIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? TwColors.brightGreen : TwColors.white.withOpacity(0.5),
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? TwColors.brightGreen : TwColors.white.withOpacity(0.5),
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraButton(int cameraIdx) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTabIndex = cameraIdx;
        });
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: TwColors.brightGreen,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: TwColors.brightGreen.withOpacity(0.2),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          Icons.camera_alt_rounded,
          color: TwColors.slate900,
          size: 28,
        ),
      ),
    );
  }
}
