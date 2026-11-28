import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/toast_service.dart';
import '../../../domain/entities/report_summary.dart';
import '../../../theme/app_text.dart';
import '../../../theme/app_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../widgets/sv_app_shell.dart';
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
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTokens.ice50,
      body: SafeArea(
        top: true,
        bottom: false,
        left: false,
        right: false,
        child: Column(
          children: [
            SvDashboardHeader(
              title: 'Reports & Export',
              titleSize: AppTokens.textSubtitle,
              onBack: () => Navigator.of(context).pop(),
              actions: [
                SvDashboardHeaderButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh',
                  onTap: _refresh,
                ),
              ],
            ),
            Expanded(
              child: Container(
                color: AppTokens.ice50,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.sheetHorizontalPadding,
                    AppTokens.spaceLg,
                    AppTokens.sheetHorizontalPadding,
                    AppTokens.space3xl + bottomInset,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppTokens.formMaxWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SvSectionLabel('Date range'),
                          const SizedBox(height: AppTokens.spaceMd),
                          _buildQuickRanges(),
                          const SizedBox(height: AppTokens.spaceLg),
                          _buildDateRange(),
                          const SizedBox(height: AppTokens.spaceXl),
                          asyncSummary.when(
                            data: (data) => _buildData(context, data),
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppTokens.space3xl,
                              ),
                              child: Center(
                                child: SvLoader.page(color: AppTokens.inkMuted),
                              ),
                            ),
                            error: (e, _) => _buildError(context, e),
                          ),
                          const SizedBox(height: AppTokens.space2xl),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
      spacing: AppTokens.spaceSm,
      runSpacing: AppTokens.spaceSm,
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
    return SvSurfaceCard(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      child: Row(
        children: [
          Expanded(
            child: _DateField(label: 'From', value: _from, onTap: _pickFrom),
          ),
          const SizedBox(width: AppTokens.spaceMd),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummaryGrid(data),
        const SizedBox(height: AppTokens.spaceXl),
        const SvSectionLabel('Report type'),
        const SizedBox(height: AppTokens.spaceMd),
        _buildTypeSelector(),
        const SizedBox(height: AppTokens.spaceLg),
        _buildBreakdown(data),
        const SizedBox(height: AppTokens.spaceXl),
        if (canExport)
          SvActionButton(
            label: 'Export CSV',
            icon: Icons.download_rounded,
            onPressed: () => _exportCsv(data),
          )
        else
          SvSurfaceCard(
            color: AppTokens.surfaceLight,
            borderColor: AppTokens.surfaceLight,
            padding: const EdgeInsets.all(AppTokens.spaceLg),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color: AppTokens.inkMuted,
                  size: AppTokens.componentIconMd,
                ),
                const SizedBox(width: AppTokens.spaceMd),
                Expanded(
                  child: Text(
                    'You do not have permission to export reports.',
                    style: AppText.bodySmall.copyWith(
                      color: AppTokens.inkMuted,
                    ),
                  ),
                ),
              ],
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
            ),
            const SizedBox(width: AppTokens.spaceMd),
            _SummaryCard(
              title: 'Verified',
              value: '${s.verified}',
              icon: Icons.verified_rounded,
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceMd),
        Row(
          children: [
            _SummaryCard(
              title: 'Verified Amount',
              value: '${s.currency} ${s.verifiedAmount.toStringAsFixed(2)}',
              icon: Icons.payments_rounded,
            ),
            const SizedBox(width: AppTokens.spaceMd),
            _SummaryCard(
              title: 'Average',
              value: '${s.currency} ${s.averageAmount.toStringAsFixed(2)}',
              icon: Icons.trending_up_rounded,
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
            const SizedBox(width: AppTokens.spaceMd),
            _TypeCard(
              label: 'Staff',
              icon: Icons.people_rounded,
              selected: _selected == _ReportType.staff,
              onTap: () => setState(() => _selected = _ReportType.staff),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceMd),
        Row(
          children: [
            _TypeCard(
              label: 'Verification',
              icon: Icons.verified_rounded,
              selected: _selected == _ReportType.verification,
              onTap: () => setState(() => _selected = _ReportType.verification),
            ),
            const SizedBox(width: AppTokens.spaceMd),
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
                  color: AppTokens.ink,
                  tone: _statusTone(r.status),
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
                  color: AppTokens.ink,
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
            color: AppTokens.ink,
            tone: SvTone.success,
          ),
          _BreakdownItem(
            label: 'Failed',
            count: s.failed,
            amount: 0,
            color: AppTokens.ink,
            tone: SvTone.error,
          ),
          _BreakdownItem(
            label: 'Rejected',
            count: s.rejected,
            amount: 0,
            color: AppTokens.ink,
            tone: SvTone.warning,
          ),
          _BreakdownItem(
            label: 'Pending',
            count: s.pending,
            amount: 0,
            color: AppTokens.ink,
            tone: SvTone.neutral,
          ),
        ], plainLabels: true);
      case _ReportType.fraud:
        final s = data.summary;
        final items = <_BreakdownItem>[
          _BreakdownItem(
            label: 'High-risk payments',
            count: s.highRisk,
            amount: s.highRiskAmount,
            color: AppTokens.ink,
            tone: SvTone.error,
          ),
          ...data.highRiskPayments.map(
            (p) => _BreakdownItem(
              label: p.transactionId ?? p.id,
              amount: p.amount,
              color: AppTokens.ink,
              tone: SvTone.warning,
            ),
          ),
        ];
        return _buildBreakdownSection('Fraud & risk', currency, items);
    }
  }

  Widget _buildBreakdownSection(
    String title,
    String currency,
    List<_BreakdownItem> items, {
    bool plainLabels = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppText.titleSmall.copyWith(color: AppTokens.ink)),
        const SizedBox(height: AppTokens.spaceMd),
        if (items.isEmpty)
          const SvSurfaceCard(
            child: SvEmptyState(
              icon: Icons.bar_chart_rounded,
              title: 'No data for this range.',
            ),
          )
        else
          ...items.map(
            (item) => _BreakdownRow(
              label: item.label,
              count: item.count == null ? null : '${item.count}',
              amount: '$currency ${item.amount.toStringAsFixed(2)}',
              color: item.color,
              tone: item.tone,
              plainLabel: plainLabels,
            ),
          ),
      ],
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return SvSurfaceCard(
      color: AppTokens.dangerBg,
      borderColor: AppTokens.danger,
      padding: const EdgeInsets.all(AppTokens.errorPadding),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTokens.ink,
            size: AppTokens.componentIconMd,
          ),
          const SizedBox(width: AppTokens.spaceMd),
          Expanded(
            child: Text(
              error.toString().replaceFirst('Exception: ', ''),
              style: AppText.bodySmall.copyWith(color: AppTokens.danger),
            ),
          ),
          TextButton(
            onPressed: _refresh,
            style: TextButton.styleFrom(
              foregroundColor: AppTokens.errorStrong,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceSm,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: AppText.labelLarge,
            ),
            child: Text(
              'Retry',
              style: AppText.labelLarge.copyWith(color: AppTokens.errorStrong),
            ),
          ),
        ],
      ),
    );
  }

  SvTone _statusTone(String status) {
    switch (status.toUpperCase()) {
      case 'VERIFIED':
        return SvTone.success;
      case 'FAILED':
        return SvTone.error;
      case 'REJECTED':
        return SvTone.warning;
      case 'PENDING':
        return SvTone.neutral;
      default:
        return SvTone.info;
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceLg,
          vertical: AppTokens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppTokens.ice100 : AppTokens.white,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(
            color: AppTokens.ice200,
            width: AppTokens.componentBorderWidth,
          ),
        ),
        child: Text(
          label,
          style: AppText.labelMedium.copyWith(
            color: selected ? AppTokens.ink : AppTokens.inkMuted,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceLg,
          vertical: AppTokens.spaceMd,
        ),
        decoration: BoxDecoration(
          color: AppTokens.surfaceLight,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: AppTokens.ice200,
            width: AppTokens.componentBorderWidth,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppText.caption.copyWith(color: AppTokens.inkMuted),
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Text(
              DateFormat('MMM d, yyyy').format(value),
              style: AppText.labelLarge.copyWith(color: AppTokens.ink),
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
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SvSurfaceCard(
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: AppTokens.inkMuted,
              size: AppTokens.componentIconMd,
            ),
            const SizedBox(height: AppTokens.spaceMd),
            Text(
              title,
              style: AppText.labelSmall.copyWith(color: AppTokens.inkMuted),
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.titleMedium.copyWith(color: AppTokens.ink),
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
      child: SvSurfaceCard(
        onTap: onTap,
        color: selected ? AppTokens.ice100 : AppTokens.white,
        borderColor: AppTokens.ice200,
        padding: const EdgeInsets.symmetric(
          vertical: AppTokens.spaceLg,
          horizontal: AppTokens.spaceMd,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? AppTokens.ink : AppTokens.inkMuted,
              size: AppTokens.componentIconLg,
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Text(
              label,
              style: AppText.labelMedium.copyWith(
                color: selected ? AppTokens.ink : AppTokens.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _breakdownToneColor(SvTone tone) => switch (tone) {
  SvTone.success => AppTokens.successStrong,
  SvTone.warning => AppTokens.warningStrong,
  SvTone.error => AppTokens.errorStrong,
  SvTone.info => AppTokens.infoStrong,
  SvTone.neutral => AppTokens.inkMuted,
};

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String? count;
  final String amount;
  final Color color;
  final SvTone? tone;
  final bool plainLabel;
  const _BreakdownRow({
    required this.label,
    required this.count,
    required this.amount,
    required this.color,
    this.tone,
    this.plainLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spaceSm),
      child: SvSurfaceCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceLg,
          vertical: AppTokens.spaceMd,
        ),
        child: Row(
          children: [
            if (tone != null && !plainLabel)
              Expanded(child: SvStatusPill(label, tone: tone!, small: true))
            else if (tone != null)
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(
                    color: _breakdownToneColor(tone!),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else ...[
              Container(
                width: AppTokens.heroDotSize,
                height: AppTokens.heroDotSize,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppTokens.spaceMd),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.labelMedium.copyWith(color: AppTokens.ink),
                ),
              ),
            ],
            if (count != null && count!.isNotEmpty) ...[
              Text(
                count!,
                style: AppText.bodySmall.copyWith(color: AppTokens.inkMuted),
              ),
              const SizedBox(width: AppTokens.spaceMd),
            ],
            Text(amount, style: AppText.labelMedium.copyWith(color: color)),
          ],
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
  final SvTone? tone;
  const _BreakdownItem({
    required this.label,
    this.count,
    required this.amount,
    required this.color,
    this.tone,
  });
}
