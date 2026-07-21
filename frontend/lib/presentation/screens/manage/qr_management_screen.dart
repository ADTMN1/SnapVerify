import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/tailwind.dart';
import '../../../domain/entities/qr_code.dart';
import '../../widgets/sv_status_badge.dart';
import '../../providers/auth_provider.dart';

class QRManagementScreen extends ConsumerStatefulWidget {
  const QRManagementScreen({super.key});

  @override
  ConsumerState<QRManagementScreen> createState() => _QRManagementScreenState();
}

class _QRManagementScreenState extends ConsumerState<QRManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwColors.primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'No QR codes yet',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: TwColors.slate800,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: TwColors.slate800,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: TwColors.slate700,
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: TwColors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'QR Management',
              style: TextStyle(
                color: TwColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QRCodeCard extends ConsumerWidget {
  final QRCode qr;

  const _QRCodeCard({required this.qr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: TwColors.slate800,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: TwColors.slate700,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        qr.branchName,
                        style: const TextStyle(
                          color: TwColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        qr.qrData,
                        style: TextStyle(
                          color: TwColors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SVStatusBadge(
                  text: qr.status.name.toUpperCase(),
                  type: qr.status == QRStatus.active
                      ? BadgeType.success
                      : BadgeType.neutral,
                  isSmall: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: TwColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.qr_code_rounded,
                size: 120,
                color: TwColors.slate900,
              ),
            ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: TwColors.slate700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Today's Scans",
                          style: TextStyle(
                            color: TwColors.white.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${qr.timesUsedToday}',
                          style: const TextStyle(
                            color: TwColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Last Scan",
                          style: TextStyle(
                            color: TwColors.white.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (qr.lastScanTime != null)
                          Text(
                            _formatTime(qr.lastScanTime!),
                            style: const TextStyle(
                              color: TwColors.brightGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Only show regenerate button for users with permission
                if (ref.watch(authNotifierProvider).role.canGenerateQRCode)
                  _ActionBtn(
                    icon: Icons.refresh_rounded,
                    label: 'Regenerate',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('QR code regenerated!')),
                      );
                    },
                  ),
                if (ref.watch(authNotifierProvider).role.canGenerateQRCode)
                  const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.download_rounded,
                  label: 'Download',
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.print_rounded,
                  label: 'Print',
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: TwColors.slate700,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: TwColors.white.withOpacity(0.8),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: TwColors.white.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
