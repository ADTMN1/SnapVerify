import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tailwind.dart';
import '../../data/datasources/qr_remote_datasource.dart';
import '../../domain/entities/qr_account.dart';
import '../providers/qr_provider.dart';
import '../widgets/qr_code_view.dart';

/// QR tab: lists the business's payment accounts as scannable QR codes.
///
/// The waiter opens an account and holds the rendered QR up to the customer,
/// who scans it with their phone instead of typing the account number.
class QRTab extends ConsumerStatefulWidget {
  final bool isActive;

  const QRTab({super.key, this.isActive = true});

  @override
  ConsumerState<QRTab> createState() => _QRTabState();
}

class _QRTabState extends ConsumerState<QRTab> {
  List<QrAccountInfo>? _accounts;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final accounts = await ref.read(qrApiProvider).list(isActive: true);
      if (!mounted) return;
      setState(() => _accounts = accounts);
    } on QrApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      debugPrint('[QrTab] list error: $e');
      setState(() => _error = 'Could not load your payment accounts. '
          'Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: RefreshIndicator(
            color: TwColors.brightGreen,
            backgroundColor: Colors.black,
            onRefresh: _load,
            child: _buildBody(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: TwColors.slate800, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My QR codes',
                  style: TextStyle(
                    color: TwColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Show a code so the customer can scan it',
                  style: TextStyle(color: TwColors.slate400, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: Icon(
              Icons.refresh_rounded,
              color: _loading ? TwColors.slate600 : TwColors.white,
            ),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _accounts == null) {
      return const Center(
        child: CircularProgressIndicator(color: TwColors.brightGreen),
      );
    }
    if (_error != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: _buildError(),
        ),
      );
    }
    final accounts = _accounts ?? const [];
    if (accounts.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: _buildEmpty(),
        ),
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: accounts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) => _AccountCard(
        account: accounts[index],
        onOpen: () => _openQr(accounts[index]),
      ),
    );
  }

  Future<void> _openQr(QrAccountInfo account) async {
    if (!account.hasQrUrl) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => _QrFullscreen(account: account),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: TwColors.red500, size: 40),
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: TwColors.slate400,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          _PrimaryButton(
            label: 'Retry',
            onTap: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.qr_code_rounded, color: TwColors.slate400, size: 40),
          const SizedBox(height: 14),
          const Text(
            'No payment accounts yet',
            style: TextStyle(
              color: TwColors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a payment account to get a scannable QR code for your '
            'customers.',
            textAlign: TextAlign.center,
            style: TextStyle(color: TwColors.slate400, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.black,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: TwColors.slate700),
  );
}

class _AccountCard extends StatelessWidget {
  final QrAccountInfo account;
  final VoidCallback onOpen;

  const _AccountCard({required this.account, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: TwColors.brightGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_outlined,
                    color: TwColors.brightGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${account.providerLabel} • ${account.accountNumber ?? 'Account'}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: TwColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (account.accountHolderName != null)
                            account.accountHolderName!,
                          if (account.branchName != null) account.branchName!,
                        ].join(' • '),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: TwColors.slate400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: TwColors.slate400,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (account.hasQrUrl)
              SVQrCode(data: account.qrUrl!, size: 200, padding: 12)
            else
              Container(
                width: 200,
                height: 200,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TwColors.slate800,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'QR link not configured',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: TwColors.slate400, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'Tap to enlarge • Let the customer scan this code',
              style: TextStyle(color: TwColors.slate400, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrFullscreen extends StatelessWidget {
  final QrAccountInfo account;

  const _QrFullscreen({required this.account});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: _cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${account.providerLabel} • ${account.accountNumber ?? 'Account'}',
              style: const TextStyle(
                color: TwColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            SVQrCode(data: account.qrUrl!, size: 280, padding: 16),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionChip(
                  icon: Icons.download_rounded,
                  label: 'Save',
                  onTap: () async {
                    final bytes = await QrImageExporter.renderPng(account.qrUrl!);
                    await QrImageExporter.download(
                      bytes,
                      fileName: QrImageExporter.fileNameFor(
                        provider: account.provider,
                        publicId: account.publicId,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                _ActionChip(
                  icon: Icons.ios_share_rounded,
                  label: 'Share',
                  onTap: () async {
                    final bytes = await QrImageExporter.renderPng(account.qrUrl!);
                    await QrImageExporter.shareImage(
                      bytes,
                      fileName: QrImageExporter.fileNameFor(
                        provider: account.provider,
                        publicId: account.publicId,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: TwColors.slate400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: TwColors.slate800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TwColors.slate700),
        ),
        child: Row(
          children: [
            Icon(icon, color: TwColors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: TwColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: TwColors.brightGreen,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: TwColors.slate900,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
