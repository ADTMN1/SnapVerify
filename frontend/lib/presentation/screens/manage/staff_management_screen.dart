import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/utils/toast_service.dart';
import '../../../theme/app_text.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/auth_option_sheet.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/sv_app_shell.dart';
import '../../widgets/sv_loader.dart';

class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  ConsumerState<StaffManagementScreen> createState() =>
      _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  List<dynamic> _staff = [];
  bool _isLoading = true;
  String? _loadError;

  final List<String> _filters = [
    'All',
    'Owner',
    'Manager',
    'Cashier',
    'Waiter',
    'Online',
    'Offline',
    'Suspended',
  ];

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authState = ref.read(authNotifierProvider);
      if (authState.tokens?.accessToken != null) {
        final staff = await ref
            .read(authRepositoryProvider)
            .getStaff(
              (await ref
                  .read(authNotifierProvider.notifier)
                  .ensureFreshAccessToken())!,
            );
        if (mounted) {
          setState(() {
            _staff = staff;
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
      debugPrint('Error loading staff: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'Failed to load staff. Check your connection and try again.';
        });
        ToastService.showError(_loadError!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final canAdd = authState.role.canAddStaff;
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
              title: 'Staff Management',
              titleSize: AppTokens.textSubtitle,
              onBack: () => Navigator.of(context).pop(),
              actions: [
                SvDashboardHeaderButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh',
                  enabled: !_isLoading,
                  onTap: _loadStaff,
                ),
              ],
            ),
            Expanded(
              child: Container(
                color: AppTokens.ice50,
                child: RefreshIndicator(
                  onRefresh: _loadStaff,
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
                          _buildSearchAndFilters(),
                          const SizedBox(height: AppTokens.spaceLg),
                          if (canAdd)
                            SvActionButton(
                              label: 'Add New Staff',
                              icon: Icons.person_add_rounded,
                              onPressed: () => _showAddStaffSheet(context),
                            ),
                          const SizedBox(height: AppTokens.spaceLg),
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
                                      _loadStaff();
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
                          else if (_staff.isEmpty)
                            SvEmptyState(
                              icon: Icons.people_outline_rounded,
                              title: 'No staff added yet',
                              subtitle:
                                  'Pull down to refresh or add your first staff member',
                              action: SvActionButton(
                                label: 'Refresh',
                                icon: Icons.refresh_rounded,
                                tone: SvTone.neutral,
                                fullWidth: false,
                                height: AppTokens.tapTarget,
                                onPressed: _loadStaff,
                              ),
                            ),
                          if (_filteredStaff.isNotEmpty)
                            ..._filteredStaff.map(
                              (staffMember) => _buildStaffCard(staffMember),
                            ),
                          if (_filteredStaff.isEmpty &&
                              _selectedFilter != 'All')
                            SvEmptyState(
                              icon: Icons.filter_list_off_rounded,
                              title: 'No $_selectedFilter staff found',
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

  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvFormField(
          controller: _searchController,
          label: 'Search staff',
          hint: 'Search staff...',
          prefixIcon: Icons.search_rounded,
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase().trim();
            });
          },
        ),
        const SizedBox(height: AppTokens.spaceMd),
        SizedBox(
          height: AppTokens.languageItemHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppTokens.spaceSm),
            itemBuilder: (context, index) {
              final filter = _filters[index];
              final isSelected = filter == _selectedFilter;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceLg,
                    vertical: AppTokens.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTokens.ice100 : AppTokens.white,
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    border: Border.all(
                      color: AppTokens.ice200,
                      width: AppTokens.componentBorderWidth,
                    ),
                  ),
                  child: Text(
                    filter,
                    style: AppText.labelMedium.copyWith(
                      color: isSelected ? AppTokens.ink : AppTokens.inkMuted,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<dynamic> get _filteredStaff {
    List<dynamic> filtered = _staff;

    // Apply role/status filter
    if (_selectedFilter != 'All') {
      filtered = filtered.where((staffMember) {
        final role = staffMember['role']?.toLowerCase() ?? '';

        switch (_selectedFilter) {
          case 'Owner':
            return role == 'owner';
          case 'Manager':
            return role == 'manager';
          case 'Cashier':
            return role == 'cashier';
          case 'Waiter':
            return role == 'waiter';
          case 'Online':
            // TODO: Implement online status check when device tracking is added
            return true;
          case 'Offline':
            // TODO: Implement offline status check when device tracking is added
            return false;
          case 'Suspended':
            // TODO: Implement suspended status check when user status is tracked
            return false;
          default:
            return true;
        }
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((staffMember) {
        final user = staffMember['user'] ?? {};
        final fullName = (user['fullName'] ?? '').toLowerCase();
        final phone = (user['phone'] ?? '').toLowerCase();
        final role = (staffMember['role'] ?? '').toLowerCase();
        final branch = (staffMember['branch']?['name'] ?? '').toLowerCase();

        return fullName.contains(_searchQuery) ||
            phone.contains(_searchQuery) ||
            role.contains(_searchQuery) ||
            branch.contains(_searchQuery);
      }).toList();
    }

    return filtered;
  }

  Widget _buildStaffCard(dynamic staffMember) {
    final authState = ref.watch(authNotifierProvider);
    final canEdit = authState.role.canAddStaff;
    final canRemove = authState.role.canRemoveStaff;
    final user = staffMember['user'] ?? {};

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spaceMd),
      child: SvSurfaceCard(
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    user['fullName'] ?? 'Unnamed',
                    style: AppText.titleSmall.copyWith(color: AppTokens.ink),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceSm),
                SvStatusPill(
                  staffMember['role'] ?? 'Unknown',
                  tone: _toneFromRole(staffMember['role']),
                  small: true,
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceMd),
            SvInfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: user['phone'] ?? 'No phone',
            ),
            if (staffMember['branch'] != null ||
                staffMember['branchId'] != null)
              Padding(
                padding: const EdgeInsets.only(top: AppTokens.spaceSm),
                child: SvInfoRow(
                  icon: Icons.storefront_outlined,
                  label: 'Branch',
                  value: staffMember['branch']?['name'] ?? 'Assigned to branch',
                ),
              ),
            if (canEdit || canRemove)
              Padding(
                padding: const EdgeInsets.only(top: AppTokens.spaceLg),
                child: Row(
                  children: [
                    if (canEdit)
                      Expanded(
                        child: SvActionButton(
                          label: 'Edit',
                          icon: Icons.edit_outlined,
                          tone: SvTone.neutral,
                          height: AppTokens.tapTarget,
                          onPressed: () =>
                              _showEditStaffSheet(context, staffMember),
                        ),
                      ),
                    if (canEdit && canRemove)
                      const SizedBox(width: AppTokens.spaceSm),
                    if (canRemove)
                      Expanded(
                        child: SvActionButton(
                          label: 'Remove',
                          icon: Icons.delete_outline,
                          tone: SvTone.error,
                          height: AppTokens.tapTarget,
                          onPressed: () => _removeStaff(staffMember['id']),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddStaffSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.ice50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.sheetTopRadius),
        ),
      ),
      builder: (context) => _AddStaffSheet(onStaffAdded: _loadStaff),
    );
  }

  void _showEditStaffSheet(BuildContext context, dynamic staffMember) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.ice50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.sheetTopRadius),
        ),
      ),
      builder: (context) =>
          _EditStaffSheet(staffMember: staffMember, onStaffUpdated: _loadStaff),
    );
  }

  Future<void> _removeStaff(String staffId) async {
    // Show confirmation dialog
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
          'Remove Staff Member',
          style: AppText.titleMedium.copyWith(color: AppTokens.ink),
        ),
        content: Text(
          'Are you sure you want to remove this staff member? This action cannot be undone.',
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
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: AppTokens.dangerBg,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceLg,
                vertical: AppTokens.spaceSm,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                side: const BorderSide(color: AppTokens.errorStrong),
              ),
            ),
            child: Text(
              'Remove',
              style: AppText.labelLarge.copyWith(color: AppTokens.errorStrong),
            ),
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
            .removeStaff(
              (await ref
                  .read(authNotifierProvider.notifier)
                  .ensureFreshAccessToken())!,
              staffId,
            );
        _loadStaff();

        // Show success message
        if (mounted) {
          ToastService.showSuccess('Staff member removed successfully');
        }
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ToastService.showError('Error: ${e.toString()}');
      }
    }
  }

  SvTone _toneFromRole(String? role) {
    switch (role?.toLowerCase()) {
      case 'owner':
        return SvTone.success;
      case 'manager':
        return SvTone.info;
      case 'cashier':
        return SvTone.warning;
      case 'waiter':
        return SvTone.neutral;
      default:
        return SvTone.neutral;
    }
  }
}

const _noBranchValue = '__no_branch__';

String _roleLabel(String role) {
  if (role.isEmpty) return 'Cashier';
  return role[0].toUpperCase() + role.substring(1);
}

String? _branchIdFromValue(String value) =>
    value == _noBranchValue ? null : value;

String _branchLabel(String? branchId, List<dynamic> branches) {
  if (branchId == null) return 'No Branch';
  for (final branch in branches) {
    if (branch['id']?.toString() == branchId) {
      return branch['name']?.toString() ?? 'Branch';
    }
  }
  return 'No Branch';
}

SvFormField _sheetSelectField({
  required TextEditingController controller,
  required String label,
  required String hint,
  required IconData prefixIcon,
  required VoidCallback onTap,
}) {
  return SvFormField(
    controller: controller,
    label: label,
    hint: hint,
    prefixIcon: prefixIcon,
    readOnly: true,
    onTap: onTap,
    suffixIcon: const Padding(
      padding: EdgeInsets.only(right: AppTokens.spaceMd),
      child: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppTokens.inkMuted,
        size: AppTokens.componentIconMd,
      ),
    ),
  );
}

class _AddStaffSheet extends ConsumerStatefulWidget {
  final VoidCallback onStaffAdded;

  const _AddStaffSheet({required this.onStaffAdded});

  @override
  ConsumerState<_AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends ConsumerState<_AddStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _roleCtrl = TextEditingController(text: _roleLabel('cashier'));
  final _branchCtrl = TextEditingController(text: 'No Branch');

  String _selectedRole = 'cashier';
  String? _selectedBranchId;
  List<dynamic> _branches = [];
  bool _isLoadingBranches = true;

  final List<String> _roles = ['manager', 'cashier', 'waiter'];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
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
          });
        }
      }
    } catch (e) {
      // Ignore for now
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBranches = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _roleCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showRolePicker() async {
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
        title: 'Select Role',
        options: _roles,
        labelFor: _roleLabel,
        selected: _selectedRole,
        onSelected: (value) => Navigator.of(sheetContext).pop(value),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedRole = selected;
      _roleCtrl.text = _roleLabel(selected);
    });
  }

  Future<void> _showBranchPicker() async {
    final options = <String>[
      _noBranchValue,
      ..._branches.map((branch) => branch['id']?.toString() ?? ''),
    ]..removeWhere((value) => value.isEmpty);
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
        title: 'Select Branch',
        options: options,
        labelFor: (value) => _branchLabel(_branchIdFromValue(value), _branches),
        selected: _selectedBranchId ?? _noBranchValue,
        onSelected: (value) => Navigator.of(sheetContext).pop(value),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedBranchId = _branchIdFromValue(selected);
      _branchCtrl.text = _branchLabel(_selectedBranchId, _branches);
    });
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });
      try {
        final authState = ref.read(authNotifierProvider);
        if (authState.tokens?.accessToken != null) {
          final invitation = await ref
              .read(authRepositoryProvider)
              .addStaff(
                authState.tokens!.accessToken,
                fullName: _fullNameCtrl.text.trim(),
                username: _usernameCtrl.text.trim().toLowerCase(),
                role: _selectedRole,
                branchId: _selectedBranchId,
              );
          if (mounted) {
            Navigator.pop(context);
            widget.onStaffAdded();
            ref.invalidate(notificationsProvider);
            // Show the invitation QR + share link so the owner can hand it over
            _showInvitationResult(invitation);
          }
        }
      } catch (e) {
        ToastService.showError('Error: ${e.toString()}');
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  void _showInvitationResult(dynamic invitation) {
    final token = invitation is Map
        ? (invitation['token']?.toString() ?? '')
        : '';
    if (token.isEmpty) return;
    final invitationId = invitation is Map
        ? (invitation['id']?.toString() ?? '')
        : '';
    final joinLink = 'snapverify://staff/join?token=$token';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTokens.ice50,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.sheetTopRadius),
        ),
      ),
      builder: (ctx) => _InvitationQrSheet(
        joinLink: joinLink,
        invitationId: invitationId,
        onRefresh: widget.onStaffAdded,
      ),
    );
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
                  'Add New Staff',
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
                      controller: _fullNameCtrl,
                      label: 'Full Name',
                      hint: 'e.g. Abebe Bekele',
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppTokens.fieldGap),
                    SvFormField(
                      controller: _usernameCtrl,
                      label: 'Username (staff logs in with this)',
                      hint: 'e.g. abebe.cashier',
                      prefixIcon: Icons.badge_outlined,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (!RegExp(
                          r'^[a-zA-Z0-9._-]{3,30}$',
                        ).hasMatch(v.trim())) {
                          return '3-30 characters: letters, numbers, dots, dashes, underscores';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTokens.fieldGap),
                    _sheetSelectField(
                      controller: _roleCtrl,
                      label: 'Role',
                      hint: 'Select role',
                      prefixIcon: Icons.work_outline_rounded,
                      onTap: _showRolePicker,
                    ),
                    const SizedBox(height: AppTokens.fieldGap),
                    _isLoadingBranches
                        ? const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppTokens.spaceMd,
                            ),
                            child: Row(
                              children: [
                                SvLoader.inline(color: AppTokens.inkMuted),
                                SizedBox(width: AppTokens.spaceMd),
                                Text(
                                  'Loading branches...',
                                  style: TextStyle(
                                    color: AppTokens.inkMuted,
                                    fontSize: AppTokens.textBodySmall,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _branches.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTokens.spaceMd,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No branches yet',
                                  style: AppText.labelLarge.copyWith(
                                    color: AppTokens.ink,
                                  ),
                                ),
                                const SizedBox(height: AppTokens.spaceXs),
                                Text(
                                  'Add a branch first to assign staff to it',
                                  style: AppText.caption.copyWith(
                                    color: AppTokens.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _sheetSelectField(
                            controller: _branchCtrl,
                            label: 'Branch (Optional)',
                            hint: 'Select branch',
                            prefixIcon: Icons.account_tree_outlined,
                            onTap: _showBranchPicker,
                          ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space3xl),
              SvActionButton(
                label: 'Send Invitation',
                icon: Icons.send_rounded,
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

class _EditStaffSheet extends ConsumerStatefulWidget {
  final dynamic staffMember;
  final VoidCallback onStaffUpdated;

  const _EditStaffSheet({
    required this.staffMember,
    required this.onStaffUpdated,
  });

  @override
  ConsumerState<_EditStaffSheet> createState() => _EditStaffSheetState();
}

class _EditStaffSheetState extends ConsumerState<_EditStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _roleCtrl;
  late final TextEditingController _branchCtrl;

  late String _selectedRole;
  String? _selectedBranchId;
  List<dynamic> _branches = [];
  bool _isLoadingBranches = true;

  final List<String> _roles = ['manager', 'cashier', 'waiter'];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final user = widget.staffMember['user'] ?? {};
    _fullNameCtrl = TextEditingController(text: user['fullName'] ?? '');
    _selectedRole = widget.staffMember['role']?.toLowerCase() ?? 'cashier';
    final branchId = widget.staffMember['branchId'];
    _selectedBranchId = branchId?.toString();
    _roleCtrl = TextEditingController(text: _roleLabel(_selectedRole));
    _branchCtrl = TextEditingController(
      text: _branchLabel(_selectedBranchId, _branches),
    );
    _loadBranches();
  }

  Future<void> _loadBranches() async {
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
            _branchCtrl.text = _branchLabel(_selectedBranchId, _branches);
          });
        }
      }
    } catch (e) {
      // Ignore for now
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBranches = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _roleCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showRolePicker() async {
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
        title: 'Select Role',
        options: _roles,
        labelFor: _roleLabel,
        selected: _selectedRole,
        onSelected: (value) => Navigator.of(sheetContext).pop(value),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedRole = selected;
      _roleCtrl.text = _roleLabel(selected);
    });
  }

  Future<void> _showBranchPicker() async {
    final options = <String>[
      _noBranchValue,
      ..._branches.map((branch) => branch['id']?.toString() ?? ''),
    ]..removeWhere((value) => value.isEmpty);
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
        title: 'Select Branch',
        options: options,
        labelFor: (value) => _branchLabel(_branchIdFromValue(value), _branches),
        selected: _selectedBranchId ?? _noBranchValue,
        onSelected: (value) => Navigator.of(sheetContext).pop(value),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedBranchId = _branchIdFromValue(selected);
      _branchCtrl.text = _branchLabel(_selectedBranchId, _branches);
    });
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
              .updateStaff(
                authState.tokens!.accessToken,
                widget.staffMember['id'],
                fullName: _fullNameCtrl.text.trim(),
                role: _selectedRole,
                branchId: _selectedBranchId,
              );
          if (mounted) {
            Navigator.pop(context);
            widget.onStaffUpdated();
            ToastService.showSuccess('Staff member updated successfully');
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
    final user = widget.staffMember['user'] ?? {};

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
                  'Edit Staff Member',
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
                      controller: _fullNameCtrl,
                      label: 'Full Name',
                      hint: 'e.g. Abebe Bekele',
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: AppTokens.fieldGap),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTokens.spaceMd,
                      ),
                      child: SvInfoRow(
                        icon: Icons.phone_rounded,
                        label: 'Phone Number',
                        value: user['phone'] ?? 'No phone',
                      ),
                    ),
                    const SizedBox(height: AppTokens.fieldGap),
                    _sheetSelectField(
                      controller: _roleCtrl,
                      label: 'Role',
                      hint: 'Select role',
                      prefixIcon: Icons.work_outline_rounded,
                      onTap: _showRolePicker,
                    ),
                    const SizedBox(height: AppTokens.fieldGap),
                    _isLoadingBranches
                        ? const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppTokens.spaceMd,
                            ),
                            child: Row(
                              children: [
                                SvLoader.inline(color: AppTokens.inkMuted),
                                SizedBox(width: AppTokens.spaceMd),
                                Text(
                                  'Loading branches...',
                                  style: TextStyle(
                                    color: AppTokens.inkMuted,
                                    fontSize: AppTokens.textBodySmall,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _branches.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTokens.spaceMd,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No branches yet',
                                  style: AppText.labelLarge.copyWith(
                                    color: AppTokens.ink,
                                  ),
                                ),
                                const SizedBox(height: AppTokens.spaceXs),
                                Text(
                                  'Add a branch first to assign staff to it',
                                  style: AppText.caption.copyWith(
                                    color: AppTokens.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _sheetSelectField(
                            controller: _branchCtrl,
                            label: 'Branch (Optional)',
                            hint: 'Select branch',
                            prefixIcon: Icons.account_tree_outlined,
                            onTap: _showBranchPicker,
                          ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space3xl),
              SvActionButton(
                label: 'Update Staff',
                icon: Icons.check_rounded,
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

/// Full-screen QR handover sheet with a 10-minute expiry countdown and
/// revoke/regenerate actions. Shown right after creating a staff invitation.
class _InvitationQrSheet extends ConsumerStatefulWidget {
  final String joinLink;
  final String invitationId;
  final VoidCallback onRefresh;

  const _InvitationQrSheet({
    required this.joinLink,
    required this.invitationId,
    required this.onRefresh,
  });

  @override
  ConsumerState<_InvitationQrSheet> createState() => _InvitationQrSheetState();
}

class _InvitationQrSheetState extends ConsumerState<_InvitationQrSheet> {
  Timer? _timer;
  int _secondsLeft = 10 * 60;
  String _currentLink = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _currentLink = widget.joinLink;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = 10 * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
      }
      setState(() => _secondsLeft = _secondsLeft > 0 ? _secondsLeft - 1 : 0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _countdown {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _regenerate() async {
    if (widget.invitationId.isEmpty) return;
    setState(() => _busy = true);
    try {
      final token = await ref
          .read(authNotifierProvider.notifier)
          .ensureFreshAccessToken();
      final inv = await ref
          .read(authRepositoryProvider)
          .regenerateInvitation(token!, widget.invitationId);
      final newToken = inv['token']?.toString() ?? '';
      if (mounted && newToken.isNotEmpty) {
        setState(() {
          _currentLink = 'snapverify://staff/join?token=$newToken';
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke() async {
    if (widget.invitationId.isEmpty) return;
    setState(() => _busy = true);
    try {
      final token = await ref
          .read(authNotifierProvider.notifier)
          .ensureFreshAccessToken();
      await ref
          .read(authRepositoryProvider)
          .revokeInvitation(token!, widget.invitationId);
      widget.onRefresh();
      ref.invalidate(notificationsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ToastService.showError('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = _secondsLeft <= 0;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.sheetHorizontalPadding,
          AppTokens.sheetTopPadding,
          AppTokens.sheetHorizontalPadding,
          AppTokens.sheetBottomPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'QR Invitation',
              style: AppText.titleLarge.copyWith(color: AppTokens.ink),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Text(
              'Show this QR to the staff member. It expires in $_countdown '
              'and works only once.',
              textAlign: TextAlign.center,
              style: AppText.bodySmall.copyWith(color: AppTokens.inkMuted),
            ),
            const SizedBox(height: AppTokens.spaceXl),
            if (expired) ...[
              Container(
                width: 200,
                height: 200,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTokens.dangerBg,
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  border: Border.all(
                    color: AppTokens.errorStrong,
                    width: AppTokens.componentBorderWidth,
                  ),
                ),
                child: Text(
                  'QR expired',
                  style: AppText.labelLarge.copyWith(
                    color: AppTokens.errorStrong,
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(AppTokens.spaceLg),
                decoration: BoxDecoration(
                  color: AppTokens.white,
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  border: Border.all(
                    color: AppTokens.ice200,
                    width: AppTokens.componentBorderWidth,
                  ),
                ),
                child: QrImageView(
                  data: _currentLink,
                  size: 200,
                  backgroundColor: AppTokens.white,
                ),
              ),
            ],
            const SizedBox(height: AppTokens.spaceXl),
            Row(
              children: [
                Expanded(
                  child: SvActionButton(
                    label: 'Revoke',
                    icon: Icons.block_rounded,
                    tone: SvTone.neutral,
                    fullWidth: true,
                    height: AppTokens.buttonHeightCompact,
                    onPressed: _busy ? null : _revoke,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceMd),
                Expanded(
                  child: SvActionButton(
                    label: expired ? 'New QR' : 'Regenerate',
                    icon: Icons.refresh_rounded,
                    tone: SvTone.neutral,
                    fullWidth: true,
                    height: AppTokens.buttonHeightCompact,
                    onPressed: _busy ? null : _regenerate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
