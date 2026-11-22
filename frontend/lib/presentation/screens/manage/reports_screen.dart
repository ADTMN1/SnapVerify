import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/tailwind.dart';
import '../../../core/utils/toast_service.dart';
import '../../../domain/entities/report_summary.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../widgets/sv_loader.dart';

enum _ReportType { payments, staff, verification, fraud }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late DateTime _from;
  late DateTime _to;
  _ReportType _selected = _ReportType.payments;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = _to.subtract(const Duration(days: 29));
  }

  String get _fromStr => DateFormat('yyyy-MM-dd').format(_from);
  String get _toStr => DateFormat('yyyy-MM-dd').format(_to);

  void _setRange(DateTime from, DateTime to) {
    setState(() {
      _from = from;
      _to = to;
    });
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2023),
      lastDate: _to,
    );
    if (picked != null) _setRange(picked, _to);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: _from,
      lastDate: DateTime.now(),
    );
    if (picked != null) _setRange(_from, picked);
  }

  void _refresh() {
    ref.invalidate(reportSummaryProvider((from: _fromStr, to: _toStr)));
  }

  @override
  Widget build(BuildContext context) {
    final asyncSummary = ref.watch(
      reportSummaryProvider((from: _fromStr, to: _toStr)),
    );

    return Scaffold(
      backgroundColor: TwColors.primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuickRanges(),
                    const SizedBox(height: 16),
                    _buildDateRange(),
                    const SizedBox(height: 16),
                    asyncSummary.when(
                      data: (data) => _buildData(context, data),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: SvLoader.page()),
                      ),
                      error: (e, _) => _buildError(context, e),
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
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TwColors.slate800, width: 1)),
      ),
      child: Row(
        children: [
          _HeaderIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Reports & Export',
              style: TextStyle(
                color: TwColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _HeaderIconButton(icon: Icons.refresh_rounded, onTap: _refresh),
        ],
      ),
    );
  }

  Widget _buildQuickRanges() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final ranges = <({String label, DateTime from, DateTime to})>[
      (label: 'Today', from: today, to: today),
      (
        label: '7 days',
        from: today.subtract(const Duration(days: 6)),
        to: today,
      ),
      (
        label: '30 days',
        from: today.subtract(const Duration(days: 29)),
        to: today,
      ),
      (label: 'This year', from: DateTime(today.year, 1, 1), to: today),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ranges.map((r) {
        return _RangeChip(
          label: r.label,
          selected: _from == r.from && _to == r.to,
          onTap: () => _setRange(r.from, r.to),
        );
      }).toList(),
    );
  }

  Widget _buildDateRange() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _DateField(label: 'From', value: _from, onTap: _pickFrom),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DateField(label: 'To', value: _to, onTap: _pickTo),
          ),
        ],
      ),
    );
  }

  Widget _buildData(BuildContext context, ReportSummary data) {
    final canExport = ref.watch(authNotifierProvider).role.canExportReports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryGrid(data),
        const SizedBox(height: 20),
        _buildTypeSelector(),
        const SizedBox(height: 12),
        _buildBreakdown(data),
        const SizedBox(height: 20),
        if (canExport)
          _ExportButton(onTap: () => _exportCsv(data))
        else
          Text(
            'You do not have permission to export reports.',
            style: TextStyle(
              color: TwColors.white.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryGrid(ReportSummary data) {
    final s = data.summary;
    return Column(
      children: [
        Row(
          children: [
            _SummaryCard(
              title: 'Total',
              value: '${s.total}',
              icon: Icons.receipt_long_rounded,
              color: TwColors.sky500,
            ),
            const SizedBox(width: 10),
            _SummaryCard(
              title: 'Verified',
              value: '${s.verified}',
              icon: Icons.verified_rounded,
              color: TwColors.brightGreen,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _SummaryCard(
              title: 'Verified Amount',
              value: '${s.currency} ${s.verifiedAmount.toStringAsFixed(2)}',
              icon: Icons.payments_rounded,
              color: TwColors.lime400,
            ),
            const SizedBox(width: 10),
            _SummaryCard(
              title: 'Average',
              value: '${s.currency} ${s.averageAmount.toStringAsFixed(2)}',
              icon: Icons.trending_up_rounded,
              color: TwColors.violet400,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      children: [
        Row(
          children: [
            _TypeCard(
              label: 'Payments',
              icon: Icons.payments_rounded,
              selected: _selected == _ReportType.payments,
              onTap: () => setState(() => _selected = _ReportType.payments),
            ),
            const SizedBox(width: 10),
            _TypeCard(
              label: 'Staff',
              icon: Icons.people_rounded,
              selected: _selected == _ReportType.staff,
              onTap: () => setState(() => _selected = _ReportType.staff),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _TypeCard(
              label: 'Verification',
              icon: Icons.verified_rounded,
              selected: _selected == _ReportType.verification,
              onTap: () => setState(() => _selected = _ReportType.verification),
            ),
            const SizedBox(width: 10),
            _TypeCard(
              label: 'Fraud',
              icon: Icons.warning_amber_rounded,
              selected: _selected == _ReportType.fraud,
              onTap: () => setState(() => _selected = _ReportType.fraud),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBreakdown(ReportSummary data) {
    final currency = data.summary.currency;
    switch (_selected) {
      case _ReportType.payments:
        return _buildBreakdownSection(
          'Payments by status',
          currency,
          data.byStatus
              .map(
                (r) => _BreakdownItem(
                  label: r.status,
                  count: r.count,
                  amount: r.amount,
                  color: _statusColor(r.status),
                ),
              )
              .toList(),
        );
      case _ReportType.staff:
        return _buildBreakdownSection(
          'Staff performance',
          currency,
          data.byStaff
              .map(
                (r) => _BreakdownItem(
                  label: r.name,
                  count: r.count,
                  amount: r.amount,
                  color: TwColors.sky500,
                ),
              )
              .toList(),
        );
      case _ReportType.verification:
        final s = data.summary;
        return _buildBreakdownSection('Verification outcomes', currency, [
          _BreakdownItem(
            label: 'Verified',
            count: s.verified,
            amount: s.verifiedAmount,
            color: TwColors.brightGreen,
          ),
          _BreakdownItem(
            label: 'Failed',
            count: s.failed,
            amount: 0,
            color: TwColors.red500,
          ),
          _BreakdownItem(
            label: 'Rejected',
            count: s.rejected,
            amount: 0,
            color: TwColors.amber500,
          ),
          _BreakdownItem(
            label: 'Pending',
            count: s.pending,
            amount: 0,
            color: TwColors.slate400,
          ),
        ]);
      case _ReportType.fraud:
        final s = data.summary;
        final items = <_BreakdownItem>[
          _BreakdownItem(
            label: 'High-risk payments',
            count: s.highRisk,
            amount: s.highRiskAmount,
            color: TwColors.red500,
          ),
          ...data.highRiskPayments.map(
            (p) => _BreakdownItem(
              label: p.transactionId ?? p.id,
              amount: p.amount,
              color: TwColors.amber500,
            ),
          ),
        ];
        return _buildBreakdownSection('Fraud & risk', currency, items);
    }
  }

  Widget _buildBreakdownSection(
    String title,
    String currency,
    List<_BreakdownItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: TwColors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Text(
              'No data for this range.',
              style: TextStyle(
                color: TwColors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          )
        else
          ...items.map(
            (item) => _BreakdownRow(
              label: item.label,
              count: item.count == null ? null : '${item.count}',
              amount: '${currency} ${item.amount.toStringAsFixed(2)}',
              color: item.color,
            ),
          ),
      ],
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TwColors.red500.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: TwColors.red500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error.toString().replaceFirst('Exception: ', ''),
              style: const TextStyle(color: TwColors.white, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _refresh,
            style: TextButton.styleFrom(
              foregroundColor: TwColors.brightGreen,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'VERIFIED':
        return TwColors.brightGreen;
      case 'FAILED':
        return TwColors.red500;
      case 'REJECTED':
        return TwColors.amber500;
      case 'PENDING':
        return TwColors.slate400;
      default:
        return TwColors.sky500;
    }
  }

  Future<void> _exportCsv(ReportSummary data) async {
    final rows = <String>[
      'SnapVerify Report',
      'From,${data.range.from}',
      'To,${data.range.to}',
      '',
      'Summary',
      'Metric,Value',
      'Total,${data.summary.total}',
      'Verified,${data.summary.verified}',
      'Failed,${data.summary.failed}',
      'Rejected,${data.summary.rejected}',
      'Pending,${data.summary.pending}',
      'Total Amount,${data.summary.totalAmount.toStringAsFixed(2)} ${data.summary.currency}',
      'Verified Amount,${data.summary.verifiedAmount.toStringAsFixed(2)} ${data.summary.currency}',
      'Average Amount,${data.summary.averageAmount.toStringAsFixed(2)} ${data.summary.currency}',
      '',
      'By Status',
      'Status,Count,Amount',
      ...data.byStatus.map(
        (r) => '${r.status},${r.count},${r.amount.toStringAsFixed(2)}',
      ),
      '',
      'By Provider',
      'Provider,Count,Amount',
      ...data.byProvider.map(
        (r) => '${r.provider},${r.count},${r.amount.toStringAsFixed(2)}',
      ),
      '',
      'By Staff',
      'Name,Count,Amount',
      ...data.byStaff.map(
        (r) =>
            '"${r.name.replaceAll('"', '""')}",${r.count},${r.amount.toStringAsFixed(2)}',
      ),
      '',
      'Daily',
      'Date,Count,Amount,Verified,Verified Amount',
      ...data.daily.map(
        (r) =>
            '${r.date},${r.count},${r.amount.toStringAsFixed(2)},${r.verifiedCount},${r.verifiedAmount.toStringAsFixed(2)}',
      ),
    ];

    final bytes = Uint8List.fromList(utf8.encode(rows.join('\n')));
    try {
      await FileSaver.instance.saveFile(
        name: 'snapverify_report_${data.range.from}_${data.range.to}.csv',
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
      ToastService.showSuccess('Report exported');
    } catch (e) {
      ToastService.showError('Export failed: $e');
    }
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.black,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: TwColors.slate700, width: 1),
  );
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: TwColors.slate800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TwColors.slate700, width: 1),
        ),
        child: Icon(icon, color: TwColors.white, size: 18),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? TwColors.brightGreen.withValues(alpha: 0.15)
              : Colors.black,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? TwColors.brightGreen : TwColors.slate700,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? TwColors.brightGreen : TwColors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final VoidCallback onTap;
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TwColors.slate700, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: TwColors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d, yyyy').format(value),
              style: const TextStyle(
                color: TwColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TwColors.slate700, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: TwColors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: TwColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? TwColors.brightGreen.withValues(alpha: 0.12)
                : Colors.black,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? TwColors.brightGreen : TwColors.slate700,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? TwColors.brightGreen : TwColors.slate400,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? TwColors.brightGreen : TwColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String? count;
  final String amount;
  final Color color;
  const _BreakdownRow({
    required this.label,
    required this.count,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TwColors.slate700, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: TwColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (count != null && count!.isNotEmpty) ...[
            Text(
              count!,
              style: TextStyle(
                color: TwColors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ExportButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.download_rounded, size: 20),
        label: const Text('Export CSV'),
        style: ElevatedButton.styleFrom(
          backgroundColor: TwColors.brightGreen,
          foregroundColor: TwColors.slate900,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _BreakdownItem {
  final String label;
  final int? count;
  final double amount;
  final Color color;
  const _BreakdownItem({
    required this.label,
    this.count,
    required this.amount,
    required this.color,
  });
}
