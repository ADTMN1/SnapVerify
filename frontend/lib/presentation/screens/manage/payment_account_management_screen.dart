import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/toast_service.dart';
import '../../../theme/app_tokens.dart';
import '../../../domain/entities/payment_account.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/payment_provider.dart';
import '../../widgets/sv_loader.dart';

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
        backgroundColor: AppTokens.obsidian900,
        title: Text(
          'Delete Account',
          style: AppTokens.manrope(
            size: AppTokens.textBodyLarge,
            weight: FontWeight.w700,
            color: AppTokens.white,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this payment account?',
          style: AppTokens.dmSans(
            size: AppTokens.textBodySmall,
            weight: FontWeight.w400,
            color: AppTokens.ice400,
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
                color: AppTokens.ice400,
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
                color: AppTokens.error,
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

    return Scaffold(
      backgroundColor: AppTokens.headerBase,
      body: SafeArea(
        top: !widget.isTab,
        bottom: !widget.isTab,
        left: !widget.isTab,
        right: !widget.isTab,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadAccounts,
                color: AppTokens.accent,
                backgroundColor: AppTokens.obsidian900,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceLg,
                    vertical: AppTokens.spaceLg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (canAdd)
                        GestureDetector(
                          onTap: () => _showAddEditDialog(),
                          child: Container(
                            width: double.infinity,
                            height: AppTokens.buttonHeight,
                            decoration: BoxDecoration(
                              color: AppTokens.accent,
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusLg,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.add_rounded,
                                    color: AppTokens.obsidian900,
                                    size: AppTokens.formPrefixIconSize,
                                  ),
                                  const SizedBox(width: AppTokens.spaceSm),
                                  Text(
                                    'Add Payment Account',
                                    style: AppTokens.manrope(
                                      size: AppTokens.textBody,
                                      weight: FontWeight.w700,
                                      color: AppTokens.obsidian900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: AppTokens.spaceLg),
                      if (_loading)
                        const Center(child: SvLoader.page())
                      else if (_error != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTokens.logoTopGap,
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: AppTokens.statTileSize,
                                  color: AppTokens.error,
                                ),
                                const SizedBox(height: AppTokens.spaceXl),
                                Text(
                                  'Failed to load accounts',
                                  style: AppTokens.manrope(
                                    size: AppTokens.textBodyLarge,
                                    weight: FontWeight.w500,
                                    color: AppTokens.white,
                                  ),
                                ),
                                const SizedBox(height: AppTokens.spaceSm),
                                Text(
                                  _error!,
                                  style: AppTokens.dmSans(
                                    size: AppTokens.textBodySmall,
                                    weight: FontWeight.w400,
                                    color: AppTokens.ice400,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppTokens.spaceXl),
                                GestureDetector(
                                  onTap: _loadAccounts,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppTokens.statCardPadding,
                                      vertical: AppTokens.spaceMd,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTokens.accent.withValues(
                                        alpha: AppTokens.alphaLow,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTokens.radiusMd,
                                      ),
                                      border: Border.all(
                                        color: AppTokens.accent.withValues(
                                          alpha: AppTokens.alphaStrong,
                                        ),
                                        width: AppTokens.componentBorderWidth,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.refresh_rounded,
                                          color: AppTokens.accent,
                                          size: AppTokens.backButtonIconSize,
                                        ),
                                        const SizedBox(
                                          width: AppTokens.spaceSm,
                                        ),
                                        Text(
                                          'Retry',
                                          style: AppTokens.manrope(
                                            size: AppTokens.textBodySmall,
                                            weight: FontWeight.w600,
                                            color: AppTokens.accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_accounts == null || _accounts!.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTokens.logoTopGap,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(
                                    AppTokens.statCardPadding,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTokens.accent.withValues(
                                      alpha: AppTokens.alphaSubtle,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: AppTokens.statTileSize,
                                    color: AppTokens.accent,
                                  ),
                                ),
                                const SizedBox(height: AppTokens.spaceXl),
                                Text(
                                  'No payment accounts added yet',
                                  style: AppTokens.manrope(
                                    size: AppTokens.textBodyLarge,
                                    weight: FontWeight.w500,
                                    color: AppTokens.white,
                                  ),
                                ),
                                const SizedBox(height: AppTokens.spaceSm),
                                Text(
                                  'Add your first payment account to get started',
                                  style: AppTokens.dmSans(
                                    size: AppTokens.textBodySmall,
                                    weight: FontWeight.w400,
                                    color: AppTokens.ice400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._accounts!.map(
                          (account) => _AccountCard(
                            account: account,
                            onEdit: () => _showAddEditDialog(account),
                            onDelete: () => _deleteAccount(account),
                          ),
                        ),
                    ],
                  ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceLg,
        vertical: AppTokens.spaceLg,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTokens.obsidian900,
            width: AppTokens.componentBorderWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          if (!widget.isTab)
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: AppTokens.backButtonSize,
                height: AppTokens.backButtonSize,
                decoration: BoxDecoration(
                  color: AppTokens.obsidian900,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(
                    color: AppTokens.obsidian700,
                    width: AppTokens.componentBorderWidth,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppTokens.white,
                  size: AppTokens.backButtonIconSize,
                ),
              ),
            ),
          if (!widget.isTab) const SizedBox(width: AppTokens.spaceLg),
          Expanded(
            child: Text(
              'Payment Accounts',
              style: AppTokens.manrope(
                size: AppTokens.textSubtitle,
                weight: FontWeight.w700,
                color: AppTokens.white,
              ),
            ),
          ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceMd),
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      decoration: BoxDecoration(
        color: AppTokens.obsidian950,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
          color: AppTokens.obsidian700,
          width: AppTokens.componentBorderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _providerDisplayName,
                  style: AppTokens.manrope(
                    size: AppTokens.textBodyLarge,
                    weight: FontWeight.w600,
                    color: AppTokens.white,
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
        Icon(icon, size: AppTokens.checkIconSize, color: AppTokens.ice400),
        const SizedBox(width: AppTokens.statTitleGap),
        Expanded(
          child: Text(
            value,
            style: AppTokens.dmSans(
              size: AppTokens.textCaption,
              weight: FontWeight.w400,
              color: AppTokens.white.withValues(alpha: AppTokens.alphaDisabled),
            ),
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
    final color = isRemove ? AppTokens.error : AppTokens.accent;

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
            color: color.withValues(alpha: AppTokens.alphaLow),
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
              color: color.withValues(alpha: AppTokens.alphaStrong),
              width: AppTokens.componentBorderWidth,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: AppTokens.checkIconSize, color: color),
              const SizedBox(width: AppTokens.statTitleGap),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: AppTokens.manrope(
                    size: AppTokens.textLabel,
                    weight: FontWeight.w600,
                    color: color,
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

class _PaymentFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  const _PaymentFormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTokens.manrope(
            size: AppTokens.textLabel,
            weight: FontWeight.w600,
            color: AppTokens.white.withValues(
              alpha: AppTokens.alphaPrimaryMuted,
            ),
          ),
        ),
        const SizedBox(height: AppTokens.statTitleGap),
        TextFormField(
          controller: controller,
          style: AppTokens.manrope(
            size: AppTokens.textBodySmall,
            weight: FontWeight.w500,
            color: AppTokens.white,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTokens.dmSans(
              size: AppTokens.textBodySmall,
              weight: FontWeight.w400,
              color: AppTokens.white.withValues(alpha: AppTokens.alphaStrong),
            ),
            prefixIcon: Icon(
              icon,
              color: AppTokens.white.withValues(
                alpha: AppTokens.alphaSecondary,
              ),
              size: AppTokens.backButtonIconSize,
            ),
            filled: true,
            fillColor: AppTokens.obsidian950,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceLg,
              vertical: AppTokens.badgePaddingH,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              borderSide: BorderSide(
                color: AppTokens.obsidian700,
                width: AppTokens.componentBorderWidth,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              borderSide: BorderSide(
                color: AppTokens.obsidian700,
                width: AppTokens.componentBorderWidth,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              borderSide: const BorderSide(
                color: AppTokens.accent,
                width: AppTokens.componentBorderWidthStrong,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              borderSide: const BorderSide(
                color: AppTokens.error,
                width: AppTokens.componentBorderWidth,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              borderSide: const BorderSide(
                color: AppTokens.error,
                width: AppTokens.componentBorderWidthStrong,
              ),
            ),
            errorStyle: AppTokens.dmSans(
              size: AppTokens.textOverline,
              weight: FontWeight.w400,
              color: AppTokens.error,
            ),
          ),
        ),
      ],
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
  final _accountNumberController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      _selectedProvider = widget.account!.provider.name;
      _accountNumberController.text = widget.account!.accountNumber ?? '';
    }
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    super.dispose();
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
        color: AppTokens.headerBase,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radius2xl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppTokens.sheetHorizontalPadding,
        AppTokens.spaceLg,
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
                    color: AppTokens.obsidian700,
                    borderRadius: BorderRadius.circular(AppTokens.radiusXs),
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.spaceXl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.account == null
                        ? 'Add Payment Account'
                        : 'Edit Payment Account',
                    style: AppTokens.manrope(
                      size: AppTokens.textSubtitle,
                      weight: FontWeight.w700,
                      color: AppTokens.white,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: AppTokens.backButtonSize,
                      height: AppTokens.backButtonSize,
                      decoration: BoxDecoration(
                        color: AppTokens.white.withValues(
                          alpha: AppTokens.alphaSubtle,
                        ),
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        border: Border.all(
                          color: AppTokens.obsidian700,
                          width: AppTokens.componentBorderWidth,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppTokens.white,
                        size: AppTokens.backButtonIconSize,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space2xl),
              DropdownButtonFormField<String>(
                value: _selectedProvider,
                decoration: InputDecoration(
                  labelText: 'Provider',
                  filled: true,
                  fillColor: AppTokens.obsidian950,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    borderSide: BorderSide(
                      color: AppTokens.obsidian700,
                      width: AppTokens.componentBorderWidth,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    borderSide: BorderSide(
                      color: AppTokens.obsidian700,
                      width: AppTokens.componentBorderWidth,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    borderSide: const BorderSide(
                      color: AppTokens.accent,
                      width: AppTokens.componentBorderWidthStrong,
                    ),
                  ),
                ),
                style: AppTokens.manrope(
                  size: AppTokens.textBodySmall,
                  weight: FontWeight.w500,
                  color: AppTokens.white,
                ),
                items: PaymentProvider.values.map((provider) {
                  String displayName;
                  switch (provider) {
                    case PaymentProvider.CBE:
                      displayName = 'CBE';
                      break;
                    case PaymentProvider.TELEBIRR:
                      displayName = 'Telebirr';
                      break;
                    case PaymentProvider.DASHEN:
                      displayName = 'Dashen';
                      break;
                    case PaymentProvider.ABYSSINIA:
                      displayName = 'Abyssinia';
                      break;
                    case PaymentProvider.CBEBIRR:
                      displayName = 'CBE Birr';
                      break;
                    case PaymentProvider.M_PESA:
                      displayName = 'M-Pesa';
                      break;
                  }
                  return DropdownMenuItem(
                    value: provider.name,
                    child: Text(displayName),
                  );
                }).toList(),
                onChanged: widget.account == null
                    ? (value) {
                        setState(() {
                          _selectedProvider = value;
                        });
                      }
                    : null,
                validator: (value) =>
                    value == null ? 'Please select a provider' : null,
              ),
              const SizedBox(height: AppTokens.spaceLg),
              _PaymentFormField(
                controller: _accountNumberController,
                label: 'Account Number',
                hint: 'Enter account number (optional)',
                icon: Icons.account_balance_outlined,
              ),
              const SizedBox(height: AppTokens.space3xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.accent,
                    foregroundColor: AppTokens.headerBase,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.space2xl,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                    ),
                    elevation: AppTokens.cardElevation,
                    shadowColor: AppTokens.transparent,
                    minimumSize: const Size(
                      double.infinity,
                      AppTokens.buttonHeight,
                    ),
                  ),
                  child: _isSubmitting
                      ? const SvLoader.button()
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.account == null
                                  ? Icons.add_rounded
                                  : Icons.check_rounded,
                              size: AppTokens.backButtonIconSize,
                            ),
                            const SizedBox(width: AppTokens.spaceSm),
                            Text(
                              widget.account == null
                                  ? 'Add Account'
                                  : 'Update Account',
                              style: AppTokens.manrope(
                                size: AppTokens.textBody,
                                weight: FontWeight.w700,
                                color: AppTokens.headerBase,
                              ),
                            ),
                          ],
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
