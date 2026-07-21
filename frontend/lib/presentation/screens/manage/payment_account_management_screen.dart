import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/tailwind.dart';
import '../../../core/utils/toast_service.dart';
import '../../../data/datasources/payment_remote_datasource.dart';
import '../../../domain/entities/payment_account.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/widgets/sv_button.dart';
import '../../../presentation/widgets/sv_input_field.dart';

class PaymentAccountManagementScreen extends ConsumerStatefulWidget {
  const PaymentAccountManagementScreen({super.key});

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
    final authState = ref.read(authNotifierProvider);
    if (!authState.isAuthenticated) return;

    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final datasource = PaymentRemoteDatasource(client: http.Client());
      final accounts = await datasource.getPaymentAccounts(
        accessToken: authState.tokens!.accessToken,
      );

      setState(() {
        _accounts = accounts;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showAddEditDialog([PaymentAccount? account]) {
    showDialog(
      context: context,
      builder: (context) => _PaymentAccountDialog(
        account: account,
        onSave: _saveAccount,
      ),
    );
  }

  Future<void> _saveAccount({
    required String provider,
    String? accountNumber,
    String? suffix,
    PaymentAccount? existingAccount,
  }) async {
    final authState = ref.read(authNotifierProvider);
    if (!authState.isAuthenticated) return;

    try {
      final datasource = PaymentRemoteDatasource(client: http.Client());
      if (existingAccount == null) {
        await datasource.createPaymentAccount(
          accessToken: authState.tokens!.accessToken,
          provider: provider,
          accountNumber: accountNumber,
          suffix: suffix,
        );
      } else {
        await datasource.updatePaymentAccount(
          accessToken: authState.tokens!.accessToken,
          provider: provider,
          accountNumber: accountNumber,
          suffix: suffix,
        );
      }
      ToastService.showSuccess('Payment account saved!');
      if (mounted) {
        Navigator.of(context).pop();
      }
      _loadAccounts();
    } catch (e) {
      ToastService.showError(e.toString());
    }
  }

  Future<void> _deleteAccount(PaymentAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TwColors.slate900,
        title: const Text('Delete Account', style: TextStyle(color: TwColors.white)),
        content: const Text('Are you sure you want to delete this payment account?', style: TextStyle(color: TwColors.slate400)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: TwColors.slate400)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: TwColors.red500)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authState = ref.read(authNotifierProvider);
      if (!authState.isAuthenticated) return;
      try {
        final datasource = PaymentRemoteDatasource(client: http.Client());
        await datasource.deletePaymentAccount(
          accessToken: authState.tokens!.accessToken,
          provider: account.provider.name,
        );
        ToastService.showSuccess('Account deleted!');
        _loadAccounts();
      } catch (e) {
        ToastService.showError(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Accounts'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAccounts,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Only show add button for users with permission
                      if (ref.watch(authNotifierProvider).role.canAddPaymentAccount)
                        SVButton(
                          onPressed: () => _showAddEditDialog(),
                          text: 'Add Payment Account',
                        ),
                      const SizedBox(height: 16),
                      if (_accounts!.isEmpty)
                        const Center(
                          child: Text(
                            'No payment accounts added yet',
                            style: TextStyle(color: TwColors.slate400),
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
    );
  }
}

class _AccountCard extends ConsumerWidget {
  final PaymentAccount account;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AccountCard(
      {required this.account, required this.onEdit, required this.onDelete});

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
    final role = ref.watch(authNotifierProvider).role;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TwColors.slate700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _providerDisplayName,
                  style: const TextStyle(
                    color: TwColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Only show edit button for users with permission
              if (role.canEditPaymentAccount)
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, color: TwColors.brightGreen),
                ),
              // Only show delete button for users with permission
              if (role.canRemovePaymentAccount)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, color: TwColors.red500),
                ),
            ],
          ),
          if (account.accountNumber != null) ...[
            const SizedBox(height: 8),
            Text(
              'Account: ${account.accountNumber}',
              style: const TextStyle(color: TwColors.slate400),
            ),
          ],
          if (account.suffix != null) ...[
            const SizedBox(height: 4),
            Text(
              'Suffix: ${account.suffix}',
              style: const TextStyle(color: TwColors.slate400),
            ),
          ],
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
    String? suffix,
    PaymentAccount? existingAccount,
  }) onSave;

  const _PaymentAccountDialog({this.account, required this.onSave});

  @override
  ConsumerState<_PaymentAccountDialog> createState() =>
      _PaymentAccountDialogState();
}

class _PaymentAccountDialogState extends ConsumerState<_PaymentAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedProvider;
  final _accountNumberController = TextEditingController();
  final _suffixController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      _selectedProvider = widget.account!.provider.name;
      _accountNumberController.text = widget.account!.accountNumber ?? '';
      _suffixController.text = widget.account!.suffix ?? '';
    }
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _suffixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: TwColors.slate900,
      title: Text(
        widget.account == null ? 'Add Payment Account' : 'Edit Payment Account',
        style: const TextStyle(color: TwColors.white),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedProvider,
                decoration: InputDecoration(
                  labelText: 'Provider',
                  filled: true,
                  fillColor: TwColors.slate800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: TwColors.white),
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
              const SizedBox(height: 16),
              SVInputField(
                controller: _accountNumberController,
                label: 'Account Number',
                hint: 'Enter account number (optional)',
              ),
              const SizedBox(height: 16),
              if (_selectedProvider == 'CBE' || _selectedProvider == 'ABYSSINIA')
                SVInputField(
                  controller: _suffixController,
                  label: _selectedProvider == 'CBE'
                      ? 'Suffix (8 digits)'
                      : 'Suffix (5 digits)',
                  hint: 'Enter suffix',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a suffix';
                    }
                    if (_selectedProvider == 'CBE' && value.length != 8) {
                      return 'Suffix must be 8 digits';
                    }
                    if (_selectedProvider == 'ABYSSINIA' && value.length != 5) {
                      return 'Suffix must be 5 digits';
                    }
                    return null;
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: TwColors.slate400)),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave(
                provider: _selectedProvider!,
                accountNumber: _accountNumberController.text.isEmpty
                    ? null
                    : _accountNumberController.text,
                suffix: _suffixController.text.isEmpty
                    ? null
                    : _suffixController.text,
                existingAccount: widget.account,
              );
            }
          },
          child: Text(
            widget.account == null ? 'Add' : 'Save',
            style: const TextStyle(color: TwColors.brightGreen),
          ),
        ),
      ],
    );
  }
}
