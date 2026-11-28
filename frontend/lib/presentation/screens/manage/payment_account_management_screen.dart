import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/toast_service.dart';
import '../../../domain/entities/payment_account.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/payment_provider.dart';
import '../../../theme/app_text.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/ui.dart';

class PaymentAccountManagementScreen extends ConsumerStatefulWidget {
  final bool isTab;

  const PaymentAccountManagementScreen({super.key, this.isTab = false});

  @override
  ConsumerState<PaymentAccountManagementScreen> createState() =>
      _PaymentAccountManagementScreenState();
}

class _PaymentAccountManagementScreenState
    extends ConsumerState<PaymentAccountManagementScreen> {
  List<PaymentAccount>? _accounts;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    if (!ref.read(authNotifierProvider).isAuthenticated) return;

    try {
      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }

      final token = await ref
          .read(authNotifierProvider.notifier)
          .ensureFreshAccessToken();
      if (token == null) {
        throw Exception('Session expired. Please log in again.');
      }
      final accounts = await ref
          .read(paymentDatasourceProvider)
          .getPaymentAccounts(accessToken: token);

      if (mounted) {
        setState(() {
          _accounts = accounts;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showAddEditDialog([PaymentAccount? account]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.transparent,
      builder: (context) =>
          _PaymentAccountDialog(account: account, onSave: _saveAccount),
    );
  }

  Future<void> _saveAccount({
    required String provider,
    String? accountNumber,
    PaymentAccount? existingAccount,
  }) async {
    if (!ref.read(authNotifierProvider).isAuthenticated) return;

    try {
      final token = await ref
          .read(authNotifierProvider.notifier)
          .ensureFreshAccessToken();
      if (token == null) {
        throw Exception('Session expired. Please log in again.');
      }
      final datasource = ref.read(paymentDatasourceProvider);
      if (existingAccount == null) {
        await datasource.createPaymentAccount(
          accessToken: token,
          provider: provider,
          accountNumber: accountNumber,
        );
      } else {
        await datasource.updatePaymentAccount(
          accessToken: token,
          provider: provider,
          accountNumber: accountNumber,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        ToastService.showSuccess('Payment account saved successfully');
      }
      _loadAccounts();
    } catch (e) {
      if (mounted) {
        ToastService.showError('Error: ${e.toString()}');
      }
    }
  }

  Future<void> _deleteAccount(PaymentAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTokens.ice50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          side: const BorderSide(
            color: AppTokens.ice200,
            width: AppTokens.componentBorderWidth,
          ),
        ),
        title: Text(
          'Delete Account',
          style: AppTokens.manrope(
            size: AppTokens.textBodyLarge,
            weight: FontWeight.w700,
            color: AppTokens.ink,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this payment account?',
          style: AppTokens.dmSans(
            size: AppTokens.textBodySmall,
            weight: FontWeight.w400,
            color: AppTokens.inkMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTokens.manrope(
                size: AppTokens.textBodySmall,
                weight: FontWeight.w600,
                color: AppTokens.inkMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: AppTokens.manrope(
                size: AppTokens.textBodySmall,
                weight: FontWeight.w600,
                color: AppTokens.danger,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!ref.read(authNotifierProvider).isAuthenticated) return;
      try {
        final token = await ref
            .read(authNotifierProvider.notifier)
            .ensureFreshAccessToken();
        if (token == null) {
          throw Exception('Session expired. Please log in again.');
        }
        await ref
            .read(paymentDatasourceProvider)
            .deletePaymentAccount(
              accessToken: token,
              provider: account.provider.name,
            );
        if (mounted) {
          ToastService.showSuccess('Account deleted successfully');
        }
        _loadAccounts();
      } catch (e) {
        if (mounted) {
          ToastService.showError('Error: ${e.toString()}');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final canAdd = authState.role.canAddPaymentAccount;
    final bottomInset = widget.isTab
        ? 0.0
        : MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTokens.ice50,
      body: SafeArea(
        top: !widget.isTab,
        bottom: false,
        left: false,
        right: false,
        child: Column(
          children: [
            SvDashboardHeader(
              title: 'Payment Accounts',
              onBack: widget.isTab ? null : () => Navigator.of(context).pop(),
              actions: [
                SvDashboardHeaderButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh',
                  enabled: !_loading,
                  onTap: _loadAccounts,
                ),
              ],
            ),
            Expanded(child: _buildSheet(canAdd, bottomInset)),
          ],
        ),
      ),
    );
  }

  Widget _buildSheet(bool canAdd, double bottomInset) {
    return Container(
      color: AppTokens.ice50,
      child: RefreshIndicator(
        onRefresh: _loadAccounts,
        color: AppTokens.inkMuted,
        backgroundColor: AppTokens.white,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppTokens.formMaxWidth),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                AppTokens.sheetHorizontalPadding,
                AppTokens.spaceLg,
                AppTokens.sheetHorizontalPadding,
                AppTokens.sheetBottomPadding + bottomInset,
              ),
              children: [
                const SvSectionLabel('Linked Accounts'),
                const SizedBox(height: AppTokens.spaceLg),
                if (canAdd) _buildAddButton(),
                const SizedBox(height: AppTokens.spaceLg),
                if (_loading)
                  const Center(child: SvLoader.page(color: AppTokens.inkMuted))
                else if (_error != null)
                  _StatusPanel(
                    icon: Icons.error_outline_rounded,
                    title: 'Failed to load accounts',
                    message: _error!,
                    action: _buildRetryButton(),
                  )
                else if (_accounts == null || _accounts!.isEmpty)
                  const _StatusPanel(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No payment accounts added yet',
                    message: 'Add your first payment account to get started',
                  )
                else
                  ..._accounts!.map(
                    (account) => _AccountCard(
                      account: account,
                      onEdit: () => _showAddEditDialog(account),
                      onDelete: () => _deleteAccount(account),
                    ),
                  ),
                const SizedBox(height: AppTokens.space3xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return SvActionButton(
      label: 'Add Payment Account',
      icon: Icons.add_rounded,
      tone: SvTone.neutral,
      onPressed: () => _showAddEditDialog(),
    );
  }

  Widget _buildRetryButton() {
    return SvActionButton(
      label: 'Retry',
      icon: Icons.refresh_rounded,
      tone: SvTone.neutral,
      onPressed: _loadAccounts,
    );
  }
}

class _LightCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color backgroundColor;

  const _LightCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.space2xl),
    this.margin,
    this.backgroundColor = AppTokens.transparent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: SvSurfaceCard(
        padding: padding,
        color: backgroundColor,
        borderColor: AppTokens.ice200,
        child: child,
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return _LightCard(
      padding: const EdgeInsets.all(AppTokens.space2xl),
      backgroundColor: AppTokens.transparent,
      child: Column(
        children: [
          Icon(icon, size: AppTokens.statTileSize, color: AppTokens.ink),
          const SizedBox(height: AppTokens.spaceXl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTokens.poppins(
              size: AppTokens.textBodyLarge,
              weight: FontWeight.w800,
              color: AppTokens.ink,
              letterSpacing: AppTokens.trackingTight,
            ),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.bodySmall.copyWith(color: AppTokens.inkMuted),
          ),
          if (action != null) ...[
            const SizedBox(height: AppTokens.spaceXl),
            action!,
          ],
        ],
      ),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  final PaymentAccount account;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AccountCard({
    required this.account,
    required this.onEdit,
    required this.onDelete,
  });

  String get _providerDisplayName {
    switch (account.provider) {
      case PaymentProvider.CBE:
        return 'CBE';
      case PaymentProvider.TELEBIRR:
        return 'Telebirr';
      case PaymentProvider.DASHEN:
        return 'Dashen';
      case PaymentProvider.ABYSSINIA:
        return 'Abyssinia';
      case PaymentProvider.CBEBIRR:
        return 'CBE Birr';
      case PaymentProvider.M_PESA:
        return 'M-Pesa';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final canEdit = authState.role.canEditPaymentAccount;
    final canRemove = authState.role.canRemovePaymentAccount;

    return _LightCard(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceMd),
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      backgroundColor: AppTokens.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: AppTokens.componentIconLg,
                color: AppTokens.ink,
              ),
              const SizedBox(width: AppTokens.spaceSm),
              Expanded(
                child: Text(
                  _providerDisplayName,
                  style: AppTokens.poppins(
                    size: AppTokens.textBodyLarge,
                    weight: FontWeight.w800,
                    color: AppTokens.ink,
                    letterSpacing: AppTokens.trackingTight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          if (account.accountNumber != null)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.spaceSm),
              child: _InfoRow(
                icon: Icons.account_balance_outlined,
                value: 'Account: ${account.accountNumber}',
              ),
            ),
          if (account.suffix != null)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.spaceSm),
              child: _InfoRow(
                icon: Icons.numbers_outlined,
                value: 'Suffix: ${account.suffix}',
              ),
            ),
          if (canEdit || canRemove)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.spaceMd),
              child: Row(
                children: [
                  if (canEdit)
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        onTap: onEdit,
                        isRemove: false,
                      ),
                    ),
                  if (canEdit && canRemove)
                    const SizedBox(width: AppTokens.spaceSm),
                  if (canRemove)
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.delete_outline,
                        label: 'Remove',
                        onTap: onDelete,
                        isRemove: true,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _InfoRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppTokens.checkIconSize, color: AppTokens.inkMuted),
        const SizedBox(width: AppTokens.statTitleGap),
        Expanded(
          child: Text(
            value,
            style: AppText.bodySmall.copyWith(color: AppTokens.inkMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isRemove;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isRemove = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRemove ? AppTokens.inkMuted : AppTokens.ink;

    return Opacity(
      opacity: onTap == null ? AppTokens.alphaSecondary : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceMd,
            vertical: AppTokens.badgeSmallPaddingH,
          ),
          decoration: BoxDecoration(
            color: AppTokens.transparent,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
              color: AppTokens.ice200,
              width: AppTokens.componentBorderWidth,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: AppTokens.componentIconSm, color: color),
              const SizedBox(width: AppTokens.statTitleGap),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: AppText.labelLarge.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentAccountDialog extends ConsumerStatefulWidget {
  final PaymentAccount? account;
  final Function({
    required String provider,
    String? accountNumber,
    PaymentAccount? existingAccount,
  })
  onSave;

  const _PaymentAccountDialog({this.account, required this.onSave});

  @override
  ConsumerState<_PaymentAccountDialog> createState() =>
      _PaymentAccountDialogState();
}

class _PaymentAccountDialogState extends ConsumerState<_PaymentAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedProvider;
  final _providerController = TextEditingController();
  final _accountNumberController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      _selectedProvider = widget.account!.provider.name;
      _providerController.text = _providerLabel(_selectedProvider!);
      _accountNumberController.text = widget.account!.accountNumber ?? '';
    }
  }

  @override
  void dispose() {
    _providerController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  String _providerLabel(String name) {
    for (final provider in PaymentProvider.values) {
      if (provider.name == name) return provider.label;
    }
    return name;
  }

  Future<void> _showProviderPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTokens.ice50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.sheetTopRadius),
        ),
      ),
      builder: (sheetContext) => AuthOptionSheet<String>(
        title: 'Select Provider',
        options: PaymentProvider.values
            .map((provider) => provider.name)
            .toList(),
        labelFor: _providerLabel,
        selected: _selectedProvider,
        onSelected: (value) => Navigator.of(sheetContext).pop(value),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedProvider = selected;
      _providerController.text = _providerLabel(selected);
    });
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });
      try {
        await widget.onSave(
          provider: _selectedProvider!,
          accountNumber: _accountNumberController.text.isEmpty
              ? null
              : _accountNumberController.text,
          existingAccount: widget.account,
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppTokens.ice50,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.sheetTopRadius),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppTokens.sheetHorizontalPadding,
        AppTokens.togglePadding,
        AppTokens.sheetHorizontalPadding,
        AppTokens.sheetHorizontalPadding + bottomInset,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: AppTokens.handleWidth,
                  height: AppTokens.handleHeight,
                  decoration: BoxDecoration(
                    color: AppTokens.ice200,
                    borderRadius: BorderRadius.circular(AppTokens.radiusXs),
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.spaceXl),
              Center(
                child: Text(
                  widget.account == null
                      ? 'Add Payment Account'
                      : 'Edit Payment Account',
                  textAlign: TextAlign.center,
                  style: AppTokens.poppins(
                    size: AppTokens.textSubtitle,
                    weight: FontWeight.w800,
                    color: AppTokens.ink,
                    letterSpacing: AppTokens.trackingTight,
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.space2xl),
              _LightCard(
                padding: const EdgeInsets.all(AppTokens.spaceLg),
                backgroundColor: AppTokens.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SvFormField(
                      controller: _providerController,
                      label: 'Provider',
                      hint: 'Select provider',
                      prefixIcon: Icons.account_balance_outlined,
                      readOnly: true,
                      onTap: widget.account == null
                          ? _showProviderPicker
                          : null,
                      suffixIcon: const Padding(
                        padding: EdgeInsets.only(right: AppTokens.spaceMd),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTokens.inkMuted,
                          size: AppTokens.componentIconMd,
                        ),
                      ),
                      validator: (_) => _selectedProvider == null
                          ? 'Please select a provider'
                          : null,
                    ),
                    const SizedBox(height: AppTokens.fieldGap),
                    SvFormField(
                      controller: _accountNumberController,
                      label: 'Account Number',
                      hint: 'Enter account number (optional)',
                      prefixIcon: Icons.account_balance_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space3xl),
              SvActionButton(
                label: widget.account == null
                    ? 'Add Account'
                    : 'Update Account',
                icon: widget.account == null
                    ? Icons.add_rounded
                    : Icons.check_rounded,
                tone: SvTone.neutral,
                loading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
