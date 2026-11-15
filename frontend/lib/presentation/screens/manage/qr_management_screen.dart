import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tailwind.dart';
import '../../../domain/entities/qr_account.dart';
import '../../providers/qr_provider.dart';
import '../../widgets/qr_code_view.dart';
import 'qr_display_screen.dart';

/// Business-wide QR management: every payment account that has a QR code,
/// with bank/account identification, branch association, search, filtering,
/// preview, download and sharing.
class QRManagementScreen extends ConsumerStatefulWidget {
  const QRManagementScreen({super.key});

  @override
  ConsumerState<QRManagementScreen> createState() => _QRManagementScreenState();
}

class _QRManagementScreenState extends ConsumerState<QRManagementScreen> {
  static const _providers = <String, String>{
    'CBE': 'CBE',
    'TELEBIRR': 'Telebirr',
    'DASHEN': 'Dashen',
    'ABYSSINIA': 'Abyssinia',
    'CBEBIRR': 'CBE Birr',
    'M_PESA': 'M-Pesa',
  };

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<QrAccountInfo>? _items;
  bool _loading = true;
  String? _error;
  String? _provider;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref
          .read(qrApiProvider)
          .list(
            provider: _provider,
            isActive: switch (_statusFilter) {
              'active' => true,
              'disabled' => false,
              _ => null,
            },
            search: _searchController.text,
          );
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
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

  Rect? get _shareOrigin {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _download(QrAccountInfo item) async {
    if (!item.hasQrUrl) {
      _toast('This account has no QR link yet.', error: true);
      return;
    }
    try {
      final bytes = await QrImageExporter.renderPng(item.qrUrl!);
      await QrImageExporter.download(
        bytes,
        fileName: QrImageExporter.fileNameFor(
          provider: item.provider,
          publicId: item.publicId,
        ),
      );
      _toast('QR code saved as PNG.');
    } catch (e) {
      _toast('Could not save the QR code: $e', error: true);
    }
  }

  Future<void> _share(QrAccountInfo item) async {
    if (!item.hasQrUrl) {
      _toast('This account has no QR link yet.', error: true);
      return;
    }
    try {
      final bytes = await QrImageExporter.renderPng(item.qrUrl!);
      await QrImageExporter.shareImage(
        bytes,
        fileName: QrImageExporter.fileNameFor(
          provider: item.provider,
          publicId: item.publicId,
        ),
        text: item.qrUrl,
        subject: 'SnapVerify QR — ${item.providerLabel}',
        sharePositionOrigin: _shareOrigin,
      );
    } catch (e) {
      _toast('Could not share the QR code: $e', error: true);
    }
  }

  void _open(QrAccountInfo item) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => QRDisplayScreen(account: item)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwColors.primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            Expanded(child: _buildBody()),
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
              'QR Management',
              style: TextStyle(
                color: TwColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: _loading ? null : _load,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: TwColors.slate800,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TwColors.slate700, width: 1),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: TwColors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        children: [
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TwColors.slate700, width: 1),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: TwColors.slate400,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: TwColors.white, fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Search bank, branch or QR ID',
                      hintStyle: TextStyle(
                        color: TwColors.white.withValues(alpha: 0.35),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _load();
                    },
                    child: const Icon(
                      Icons.close_rounded,
                      color: TwColors.slate400,
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _FilterDropdown(
                  value: _provider,
                  hint: 'All banks',
                  items: _providers.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _provider = value);
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FilterDropdown<String>(
                  value: _statusFilter,
                  hint: 'Any status',
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Any status')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'disabled',
                      child: Text('Disabled'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _statusFilter = value ?? 'all');
                    _load();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: TwColors.brightGreen),
      );
    }

    if (_error != null) {
      return _StateView(
        icon: Icons.error_outline_rounded,
        iconColor: TwColors.red500,
        title: 'Failed to load QR codes',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }

    final items = _items ?? const <QrAccountInfo>[];
    if (items.isEmpty) {
      return _StateView(
        icon: Icons.qr_code_2_rounded,
        iconColor: TwColors.brightGreen,
        title: 'No QR codes found',
        message:
            _searchController.text.isNotEmpty ||
                _provider != null ||
                _statusFilter != 'all'
            ? 'No payment account matches these filters.'
            : 'Add a payment account — every account automatically receives a QR code.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: TwColors.brightGreen,
      backgroundColor: TwColors.slate800,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _QrAccountCard(
            item: item,
            onView: () => _open(item),
            onDownload: () => _download(item),
            onShare: () => _share(item),
          );
        },
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TwColors.slate700, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: TwColors.slate900,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: TwColors.slate400,
            size: 20,
          ),
          style: const TextStyle(color: TwColors.white, fontSize: 13),
          hint: Text(
            hint,
            style: TextStyle(
              color: TwColors.white.withValues(alpha: 0.45),
              fontSize: 13,
            ),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _QrAccountCard extends StatelessWidget {
  final QrAccountInfo item;
  final VoidCallback onView;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  const _QrAccountCard({
    required this.item,
    required this.onView,
    required this.onDownload,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TwColors.slate700, width: 1),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.hasQrUrl)
                SVQrCode(data: item.qrUrl!, size: 64, padding: 4)
              else
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: TwColors.slate800,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: TwColors.slate500,
                    size: 36,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.providerLabel,
                            style: const TextStyle(
                              color: TwColors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _StatusPill(isActive: item.isActive),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.accountNumber ?? 'No account number',
                      style: const TextStyle(
                        color: TwColors.slate400,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.account_tree_outlined,
                          size: 12,
                          color: TwColors.slate500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.branchName ?? 'All branches',
                            style: const TextStyle(
                              color: TwColors.slate400,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (item.organizationName != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.business_outlined,
                            size: 12,
                            color: TwColors.slate500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.organizationName!,
                              style: const TextStyle(
                                color: TwColors.slate500,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: TwColors.slate950,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.qrUrl ?? 'QR link unavailable',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: TwColors.slate500,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CardAction(
                  icon: Icons.open_in_full_rounded,
                  label: 'View',
                  onTap: onView,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CardAction(
                  icon: Icons.download_rounded,
                  label: 'Download',
                  onTap: onDownload,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CardAction(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: onShare,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isActive;

  const _StatusPill({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? TwColors.brightGreen : TwColors.slate400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'DISABLED',
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: TwColors.brightGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: TwColors.brightGreen.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: TwColors.brightGreen),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: TwColors.brightGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateView({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: iconColor),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: TwColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: TwColors.slate400, fontSize: 13),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: TwColors.brightGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: TwColors.brightGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      color: TwColors.brightGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
