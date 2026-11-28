import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/toast_service.dart';
import '../../../theme/app_text.dart';
import '../../../theme/app_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/sv_app_shell.dart';
import '../../widgets/sv_loader.dart';

class BranchManagementScreen extends ConsumerStatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  ConsumerState<BranchManagementScreen> createState() =>
      _BranchManagementScreenState();
}

class _BranchManagementScreenState
    extends ConsumerState<BranchManagementScreen> {
  List<dynamic> _branches = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authState = ref.read(authNotifierProvider);
      if (authState.tokens?.accessToken != null) {
        final branches = await ref
            .read(authRepositoryProvider)
            .getBranches(
              (await ref
                  .read(authNotifierProvider.notifier)
                  .ensureFreshAccessToken())!,
            );
        if (mounted) {
          setState(() {
            _branches = branches;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading branches: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'Failed to load branches. Check your connection and try again.';
        });
        ToastService.showError(_loadError!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              title: 'Branch Management',
              titleSize: AppTokens.textSubtitle,
              onBack: () => Navigator.of(context).pop(),
              actions: [
                SvDashboardHeaderButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh',
                  enabled: !_isLoading,
                  onTap: _loadBranches,
                ),
              ],
            ),
            Expanded(
              child: Container(
                color: AppTokens.ice50,
                child: RefreshIndicator(
                  onRefresh: _loadBranches,
                  color: AppTokens.inkMuted,
                  backgroundColor: AppTokens.white,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppTokens.formMaxWidth,
                      ),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          AppTokens.sheetHorizontalPadding,
                          AppTokens.spaceLg,
                          AppTokens.sheetHorizontalPadding,
                          AppTokens.space3xl + bottomInset,
                        ),
                        children: [
                          if (ref.watch(authNotifierProvider).role.canAddBranch)
                            SvActionButton(
                              label: 'Add New Branch',
                              icon: Icons.add_rounded,
                              tone: SvTone.neutral,
                              onPressed: () => _showAddBranchSheet(context),
                            ),
                          const SizedBox(height: AppTokens.spaceXl),
                          SvSectionLabel(
                            'Branches',
                            trailing: SvStatusPill(
                              '${_branches.length}',
                              tone: SvTone.neutral,
                              small: true,
                            ),
                          ),
                          const SizedBox(height: AppTokens.spaceMd),
                          if (_isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: AppTokens.space3xl,
                                ),
                                child: SvLoader.page(color: AppTokens.inkMuted),
                              ),
                            )
                          else if (_loadError != null)
                            SvSurfaceCard(
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
                                      _loadError!,
                                      style: AppText.bodySmall.copyWith(
                                        color: AppTokens.danger,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _loadError = null;
                                      });
                                      _loadBranches();
                                    },
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
                                      style: AppText.labelLarge.copyWith(
                                        color: AppTokens.errorStrong,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (_branches.isEmpty)
                            SvEmptyState(
                              icon: Icons.storefront_outlined,
                              title: 'No branches added yet',
                              subtitle:
                                  'Pull down to refresh or add your first branch',
                              action: SvActionButton(
                                label: 'Refresh',
                                icon: Icons.refresh_rounded,
                                onPressed: _loadBranches,
                                tone: SvTone.neutral,
                                fullWidth: false,
                              ),
                            )
                          else
                            ..._branches.map(
                              (branch) => _buildBranchCard(branch),
                            ),
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

  Widget _buildBranchCard(dynamic branch) {
    final authState = ref.watch(authNotifierProvider);
    final canEdit = authState.role.canEditBranch;
    final canRemove = authState.role.canRemoveBranch;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spaceMd),
      child: SvSurfaceCard(
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              branch['name'] ?? 'Unnamed',
              style: AppText.titleSmall.copyWith(color: AppTokens.ink),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppTokens.spaceSm),
            SvDetailRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: branch['address']?.toString() ?? 'No address',
            ),
            if (branch['phone'] != null)
              Padding(
                padding: const EdgeInsets.only(top: AppTokens.spaceSm),
                child: SvDetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: branch['phone']!.toString(),
                ),
              ),
            if (canEdit || canRemove)
              Padding(
                padding: const EdgeInsets.only(top: AppTokens.spaceMd),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (canEdit)
                      SvActionButton(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        onPressed: () => _showEditBranchSheet(context, branch),
                        tone: SvTone.neutral,
                        fullWidth: false,
                        height: AppTokens.buttonHeightSmall,
                      ),
                    if (canEdit && canRemove)
                      const SizedBox(width: AppTokens.spaceSm),
                    if (canRemove)
                      SvActionButton(
                        label: 'Remove',
                        icon: Icons.delete_outline,
                        onPressed: () => _removeBranch(branch['id']),
                        tone: SvTone.neutral,
                        fullWidth: false,
                        height: AppTokens.buttonHeightSmall,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeBranch(String branchId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTokens.ice50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(
            color: AppTokens.ice200,
            width: AppTokens.componentBorderWidth,
          ),
        ),
        title: Text(
          'Remove Branch',
          style: AppText.titleMedium.copyWith(color: AppTokens.ink),
        ),
        content: Text(
          'Are you sure you want to remove this branch? This action cannot be undone.',
          style: AppText.bodySmall.copyWith(color: AppTokens.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppText.labelLarge.copyWith(color: AppTokens.inkMuted),
            ),
          ),
          SvActionButton(
            label: 'Remove',
            onPressed: () => Navigator.pop(context, true),
            tone: SvTone.neutral,
            fullWidth: false,
            height: AppTokens.tapTarget,
          ),
        ],
      ),
    );

    // If not confirmed, return early
    if (confirmed != true) return;

    try {
      final authState = ref.read(authNotifierProvider);
      if (authState.tokens?.accessToken != null) {
        await ref
            .read(authRepositoryProvider)
            .removeBranch(authState.tokens!.accessToken, branchId);
        _loadBranches();

        // Show success message
        if (mounted) {
          ToastService.showSuccess('Branch removed successfully');
        }
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ToastService.showError('Error: ${e.toString()}');
      }
    }
  }

  void _showEditBranchSheet(BuildContext context, dynamic branch) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.transparent,
      builder: (context) =>
          _EditBranchSheet(branch: branch, onBranchUpdated: _loadBranches),
    );
  }

  void _showAddBranchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.transparent,
      builder: (context) => _AddBranchSheet(onBranchAdded: _loadBranches),
    );
  }
}

class _AddBranchSheet extends ConsumerStatefulWidget {
  final VoidCallback onBranchAdded;

  const _AddBranchSheet({required this.onBranchAdded});

  @override
  ConsumerState<_AddBranchSheet> createState() => _AddBranchSheetState();
}

class _AddBranchSheetState extends ConsumerState<_AddBranchSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _managerCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _managerCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });
      try {
        final authState = ref.read(authNotifierProvider);
        if (authState.tokens?.accessToken != null) {
          await ref
              .read(authRepositoryProvider)
              .addBranch(
                authState.tokens!.accessToken,
                name: _nameCtrl.text.trim(),
                phone: _phoneCtrl.text.trim().isNotEmpty
                    ? _phoneCtrl.text.trim()
                    : null,
                address: _addressCtrl.text.trim(),
              );
          if (mounted) {
            Navigator.pop(context);
            widget.onBranchAdded();
          }
        }
      } catch (e) {
        if (mounted) {
          ToastService.showError(
            e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
          );
        }
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
        AppTokens.sheetBottomPadding + bottomInset,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  'Add New Branch',
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
              SvSurfaceCard(
                padding: const EdgeInsets.all(AppTokens.spaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SvFormField(
                      controller: _nameCtrl,
                      label: 'Branch Name',
                      hint: 'e.g. Bole Main Branch',
                      prefixIcon: Icons.storefront_rounded,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppTokens.fieldGap),
                    SvFormField(
                      controller: _phoneCtrl,
                      label: 'Phone',
                      hint: '+251 9XX XXX XXX',
                      prefixIcon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppTokens.fieldGap),
                    SvFormField(
                      controller: _addressCtrl,
                      label: 'Address',
                      hint: 'e.g. Bole Road, Addis Ababa',
                      prefixIcon: Icons.location_on_rounded,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppTokens.fieldGap),
                    SvFormField(
                      controller: _managerCtrl,
                      label: 'Manager Name (Optional)',
                      hint: 'e.g. Abebe Bekele',
                      prefixIcon: Icons.manage_accounts_rounded,
                    ),
                    const SizedBox(height: AppTokens.fieldGap),
                    SvFormField(
                      controller: _hoursCtrl,
                      label: 'Working Hours',
                      hint: 'Mon-Sat: 8:00 AM - 10:00 PM',
                      prefixIcon: Icons.schedule_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space3xl),
              SvActionButton(
                label: 'Add Branch',
                icon: Icons.add_business_rounded,
                tone: SvTone.neutral,
                onPressed: _isSubmitting ? null : _submit,
                loading: _isSubmitting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditBranchSheet extends ConsumerStatefulWidget {
  final dynamic branch;
  final VoidCallback onBranchUpdated;

  const _EditBranchSheet({required this.branch, required this.onBranchUpdated});

  @override
  ConsumerState<_EditBranchSheet> createState() => _EditBranchSheetState();
}

class _EditBranchSheetState extends ConsumerState<_EditBranchSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.branch['name'] ?? '');
    _phoneCtrl = TextEditingController(text: widget.branch['phone'] ?? '');
    _addressCtrl = TextEditingController(text: widget.branch['address'] ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });
      try {
        final authState = ref.read(authNotifierProvider);
        if (authState.tokens?.accessToken != null) {
          await ref
              .read(authRepositoryProvider)
              .updateBranch(
                authState.tokens!.accessToken,
                widget.branch['id'],
                name: _nameCtrl.text.trim(),
                phone: _phoneCtrl.text.trim().isNotEmpty
                    ? _phoneCtrl.text.trim()
                    : null,
                address: _addressCtrl.text.trim(),
              );
          if (mounted) {
            Navigator.pop(context);
            widget.onBranchUpdated();
            ToastService.showSuccess('Branch updated successfully');
          }
        }
      } catch (e) {
        if (mounted) {
          ToastService.showError('Error: ${e.toString()}');
        }
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
        AppTokens.sheetBottomPadding + bottomInset,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  'Edit Branch',
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
              SvSurfaceCard(
                padding: const EdgeInsets.all(AppTokens.spaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SvFormField(
                      controller: _nameCtrl,
                      label: 'Branch Name',
                      hint: 'e.g. Bole Main Branch',
                      prefixIcon: Icons.storefront_rounded,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppTokens.fieldGap),
                    SvFormField(
                      controller: _phoneCtrl,
                      label: 'Phone',
                      hint: '+251 9XX XXX XXX',
                      prefixIcon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppTokens.fieldGap),
                    SvFormField(
                      controller: _addressCtrl,
                      label: 'Address',
                      hint: 'e.g. Bole Road, Addis Ababa',
                      prefixIcon: Icons.location_on_rounded,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space3xl),
              SvActionButton(
                label: 'Update Branch',
                icon: Icons.check_rounded,
                tone: SvTone.neutral,
                onPressed: _isSubmitting ? null : _submit,
                loading: _isSubmitting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
