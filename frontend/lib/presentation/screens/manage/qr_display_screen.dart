import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/tailwind.dart';
import '../../../core/utils/qr_link.dart';
import '../../../domain/entities/qr_account.dart';
import '../../widgets/qr_code_view.dart';

/// Full-screen QR display for one payment account.
///
/// Scanning this code identifies the receiving account only; it is never
/// treated as proof of payment.
class QRDisplayScreen extends StatefulWidget {
  final QrAccountInfo account;

  const QRDisplayScreen({super.key, required this.account});

  @override
  State<QRDisplayScreen> createState() => _QRDisplayScreenState();
}

class _QRDisplayScreenState extends State<QRDisplayScreen> {
  bool _busy = false;

  String get _data => widget.account.qrUrl ?? '';

  String get _fileName => QrImageExporter.fileNameFor(
    provider: widget.account.provider,
    publicId: widget.account.publicId,
  );

  Rect? get _shareOrigin {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? TwColors.red500 : TwColors.emerald600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _download() async {
    if (_data.isEmpty) {
      _toast('This account has no QR link yet.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await QrImageExporter.renderPng(_data);
      await QrImageExporter.download(bytes, fileName: _fileName);
      _toast('QR code saved as PNG.');
    } catch (e) {
      _toast('Could not save the QR code: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_data.isEmpty) {
      _toast('This account has no QR link yet.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await QrImageExporter.renderPng(_data);
      await QrImageExporter.shareImage(
        bytes,
        fileName: _fileName,
        text: _data,
        subject: 'SnapVerify QR — ${widget.account.providerLabel}',
        sharePositionOrigin: _shareOrigin,
      );
    } catch (e) {
      _toast('Could not share the QR code: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyLink() async {
    if (_data.isEmpty) {
      _toast('This account has no QR link yet.', error: true);
      return;
    }
    await Clipboard.setData(ClipboardData(text: _data));
    _toast('QR link copied.');
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;

    return Scaffold(
      backgroundColor: TwColors.primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: TwColors.slate700),
                      ),
                      child: Column(
                        children: [
                          if (_data.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 60),
                              child: Text(
                                'QR link unavailable.\nAsk an administrator to configure the public QR domain.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: TwColors.slate400,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          else
                            SVQrCode(data: _data, size: 240),
                          const SizedBox(height: 18),
                          Text(
                            account.providerLabel,
                            style: const TextStyle(
                              color: TwColors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (account.accountNumber != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Account ${account.accountNumber}',
                              style: const TextStyle(
                                color: TwColors.slate400,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          if (QrLink.hostOf(account.qrUrl) != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              QrLink.hostOf(account.qrUrl)!,
                              style: TextStyle(
                                color: TwColors.white.withValues(alpha: 0.45),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _InfoCard(account: account),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: TwColors.amber500.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: TwColors.amber500.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: TwColors.amber400,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This QR code identifies the payment account only. '
                              'It is not proof of payment — always verify the '
                              'transaction reference before releasing goods or services.',
                              style: TextStyle(
                                color: TwColors.amber200.withValues(alpha: 0.9),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _QrActionButton(
                            icon: Icons.download_rounded,
                            label: 'Download PNG',
                            onTap: _busy ? null : _download,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QrActionButton(
                            icon: Icons.share_rounded,
                            label: 'Share',
                            onTap: _busy ? null : _share,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: _QrActionButton(
                        icon: Icons.link_rounded,
                        label: 'Copy QR link',
                        onTap: _busy ? null : _copyLink,
                        outlined: true,
                      ),
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 16),
                      const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: TwColors.brightGreen,
                        ),
                      ),
                    ],
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
        border: Border(bottom: BorderSide(color: TwColors.slate800, width: 1)),
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
                border: Border.all(color: TwColors.slate700, width: 1),
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
              'Account QR',
              style: TextStyle(
                color: TwColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:
                  (widget.account.isActive
                          ? TwColors.brightGreen
                          : TwColors.slate400)
                      .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.account.isActive ? 'ACTIVE' : 'DISABLED',
              style: TextStyle(
                color: widget.account.isActive
                    ? TwColors.brightGreen
                    : TwColors.slate400,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final QrAccountInfo account;

  const _InfoCard({required this.account});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TwColors.slate700, width: 1),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.business_outlined,
            label: 'Business',
            value: account.organizationName ?? '—',
          ),
          _InfoRow(
            icon: Icons.account_tree_outlined,
            label: 'Branch',
            value: account.branchName ?? 'All branches',
          ),
          if (account.accountHolderName != null)
            _InfoRow(
              icon: Icons.person_outline_rounded,
              label: 'Account holder',
              value: account.accountHolderName!,
            ),
          if (account.suffix != null)
            _InfoRow(
              icon: Icons.numbers_outlined,
              label: 'Suffix',
              value: account.suffix!,
            ),
          _InfoRow(
            icon: Icons.fingerprint_rounded,
            label: 'QR ID',
            value: account.publicId,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: TwColors.slate400),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: TwColors.slate400, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: TwColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool outlined;

  const _QrActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : TwColors.brightGreen,
            borderRadius: BorderRadius.circular(14),
            border: outlined
                ? Border.all(color: TwColors.slate700, width: 1)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: outlined ? TwColors.white : TwColors.slate900,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: outlined ? TwColors.white : TwColors.slate900,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
