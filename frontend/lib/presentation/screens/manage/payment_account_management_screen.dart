import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            color: AppTokens.border,
            width: AppTokens.componentBorderWidth,
          ),
        ),
        title: Text(
          'Delete Account',
          style: AppTokens.manrope(
            size: AppTokens.textBodyLarge,
            weight: FontWeight.w700,
            color: AppTokens.text,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this payment account?',
          style: AppTokens.dmSans(
            size: AppTokens.textBodySmall,
            weight: FontWeight.w400,
            color: AppTokens.textSecondary,
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
                color: AppTokens.textSecondary,
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
    final topInset = widget.isTab ? 0.0 : MediaQuery.of(context).padding.top;
    final bottomInset = widget.isTab
        ? 0.0
        : MediaQuery.of(context).padding.bottom;
    final headerHeight = AppTokens.headerVisibleHeight + topInset;

    return Scaffold(
      backgroundColor: AppTokens.ice50,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerHeight + AppTokens.sheetTopRadius,
            child: _buildHeader(topInset),
          ),
          Positioned(
            top: headerHeight - AppTokens.sheetOverlap,
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildSheet(canAdd, bottomInset),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double topInset) {
    final logoTop = topInset + AppTokens.logoTopGap;
    final headerHeight =
        AppTokens.headerVisibleHeight + topInset + AppTokens.sheetTopRadius;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppTokens.obsidian950,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppTokens.ice50,
      ),
      child: SizedBox(
        width: double.infinity,
        height: headerHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: const AppHeaderPatternPainter(),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            if (!widget.isTab)
              Positioned(
                top: topInset + AppTokens.authTopBarInset,
                left: AppTokens.authTopBarInset,
                right: AppTokens.authTopBarInset,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AuthBackButton(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            Positioned(
              top: logoTop,
              left: 0,
              right: 0,
              child: Center(child: _buildLogo()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Semantics(
      label: 'App logo',
      child: Container(
        width: AppTokens.logoTileSize,
        height: AppTokens.logoTileSize,
        decoration: BoxDecoration(
          color: AppTokens.white,
          borderRadius: BorderRadius.circular(AppTokens.logoTileRadius),
        ),
        child: Center(
          child: SizedBox(
            width: AppTokens.logoIconSize,
            height: AppTokens.logoIconSize,
            child: const CustomPaint(painter: AppLogoPainter()),
          ),
        ),
      ),
    );
  }

  Widget _buildSheet(bool canAdd, double bottomInset) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        systemNavigationBarColor: AppTokens.ice50,
        systemNavigationBarDividerColor: AppTokens.ice50,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTokens.ice50,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppTokens.sheetTopRadius),
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadAccounts,
          color: AppTokens.primary,
          backgroundColor: AppTokens.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              AppTokens.sheetHorizontalPadding,
              AppTokens.sheetTopPadding,
              AppTokens.sheetHorizontalPadding,
              AppTokens.sheetBottomPadding + bottomInset,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppTokens.formMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Payment Accounts',
                      style: AppTokens.manrope(
                        size: AppTokens.textTitle,
                        weight: FontWeight.w700,
                        color: AppTokens.text,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceLg),
                    if (canAdd) _buildAddButton(),
                    const SizedBox(height: AppTokens.spaceLg),
                    if (_loading)
                      const Center(
                        child: SvLoader.page(color: AppTokens.primary),
                      )
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
                        message:
                            'Add your first payment account to get started',
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
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      height: AppTokens.buttonHeight,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add_rounded, size: AppTokens.formPrefixIconSize),
        label: Text('Add Payment Account', style: AppText.button),
        style: FilledButton.styleFrom(
          backgroundColor: AppTokens.primary,
          foregroundColor: AppTokens.white,
          disabledBackgroundColor: AppTokens.ice200,
          shape: RoundedRectangleBorder(
            borderRadius: AppTokens.buttonBorderRadius,
          ),
          elevation: AppTokens.cardElevation,
          shadowColor: AppTokens.transparent,
        ),
      ),
    );
  }

  Widget _buildRetryButton() {
    return OutlinedButton.icon(
      onPressed: _loadAccounts,
      icon: const Icon(
        Icons.refresh_rounded,
        size: AppTokens.backButtonIconSize,
      ),
      label: Text(
        'Retry',
        style: AppTokens.manrope(
          size: AppTokens.textBodySmall,
          weight: FontWeight.w600,
          color: AppTokens.primary,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTokens.primary,
        side: const BorderSide(
          color: AppTokens.primary,
          width: AppTokens.componentBorderWidth,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.buttonBorderRadius,
        ),
      ),
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
    this.backgroundColor = AppTokens.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: AppTokens.cardBorderRadius,
        border: Border.all(
          color: AppTokens.border,
          width: AppTokens.componentBorderWidth,
        ),
        boxShadow: const [AppTokens.cardShadow],
      ),
      child: SVCard(
        padding: padding,
        backgroundColor: backgroundColor,
        borderRadius: AppTokens.radiusCard,
        hasShadow: false,
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
      backgroundColor: AppTokens.surfaceLight,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTokens.statCardPadding),
            decoration: BoxDecoration(
              color: AppTokens.primary.withValues(alpha: AppTokens.alphaSubtle),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: AppTokens.statTileSize,
              color: AppTokens.primary,
            ),
          ),
          const SizedBox(height: AppTokens.spaceXl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTokens.manrope(
              size: AppTokens.textBodyLarge,
              weight: FontWeight.w500,
              color: AppTokens.text,
            ),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTokens.dmSans(
              size: AppTokens.textBodySmall,
              weight: FontWeight.w400,
              color: AppTokens.textSecondary,
            ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppTokens.statTileSize,
                height: AppTokens.statTileSize,
                decoration: BoxDecoration(
                  color: AppTokens.primary.withValues(
                    alpha: AppTokens.alphaSubtle,
                  ),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: AppTokens.statIconSize,
                  color: AppTokens.primary,
                ),
              ),
              const SizedBox(width: AppTokens.spaceSm),
              Expanded(
                child: Text(
                  _providerDisplayName,
                  style: AppTokens.manrope(
                    size: AppTokens.textBodyLarge,
                    weight: FontWeight.w600,
                    color: AppTokens.text,
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
        Icon(
          icon,
          size: AppTokens.checkIconSize,
          color: AppTokens.textSecondary,
        ),
        const SizedBox(width: AppTokens.statTitleGap),
        Expanded(
          child: Text(
            value,
            style: AppTokens.dmSans(
              size: AppTokens.textCaption,
              weight: FontWeight.w400,
              color: AppTokens.textSecondary,
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
    final color = isRemove ? AppTokens.danger : AppTokens.primary;

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
    return AuthFieldShell(
      label: label,
      child: Row(
        children: [
          Icon(
            icon,
            size: AppTokens.eyeIconSize,
            color: AppTokens.textSecondary,
          ),
          const SizedBox(width: AppTokens.dropdownIconGap),
          Expanded(
            child: TextFormField(
              controller: controller,
              style: AppText.authInput,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppText.authHint,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                errorStyle: AppText.authError,
              ),
            ),
          ),
        ],
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
                      color: AppTokens.text,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: AppTokens.backButtonSize,
                      height: AppTokens.backButtonSize,
                      decoration: BoxDecoration(
                        color: AppTokens.white,
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        border: Border.all(
                          color: AppTokens.border,
                          width: AppTokens.componentBorderWidth,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppTokens.text,
                        size: AppTokens.backButtonIconSize,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space2xl),
              _LightCard(
                padding: const EdgeInsets.all(AppTokens.spaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthFieldShell(
                      label: 'Provider',
                      child: DropdownButtonFormField<String>(
                        value: _selectedProvider,
                        isExpanded: true,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          errorStyle: AppText.authError,
                        ),
                        style: AppText.authInput,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_outlined,
                          size: AppTokens.eyeIconSize,
                          color: AppTokens.textSecondary,
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
                    ),
                    const SizedBox(height: AppTokens.fieldGap),
                    _PaymentFormField(
                      controller: _accountNumberController,
                      label: 'Account Number',
                      hint: 'Enter account number (optional)',
                      icon: Icons.account_balance_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space3xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.primary,
                    foregroundColor: AppTokens.white,
                    disabledBackgroundColor: AppTokens.ice200,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.space2xl,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTokens.buttonBorderRadius,
                    ),
                    elevation: AppTokens.cardElevation,
                    shadowColor: AppTokens.transparent,
                    minimumSize: const Size(
                      double.infinity,
                      AppTokens.buttonHeight,
                    ),
                  ),
                  child: _isSubmitting
                      ? const SvLoader.button(color: AppTokens.white)
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
                                color: AppTokens.white,
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
