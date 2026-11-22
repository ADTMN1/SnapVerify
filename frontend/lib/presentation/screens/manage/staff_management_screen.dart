import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/tailwind.dart';
import '../../../core/utils/toast_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/sv_loader.dart';
import '../../widgets/sv_status_badge.dart';

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
      final authState = ref.read(authNotifierProvider);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ToastService.showError('Failed to load staff: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final canAdd = authState.role.canAddStaff;

    return Scaffold(
      backgroundColor: TwColors.primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadStaff,
                color: TwColors.brightGreen,
                backgroundColor: TwColors.slate800,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchAndFilters(),
                      const SizedBox(height: 16),
                      if (canAdd)
                        GestureDetector(
                          onTap: () => _showAddStaffSheet(context),
                          child: Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              color: TwColors.brightGreen,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_add_rounded,
                                    color: TwColors.slate900,
                                    size: 22,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Add New Staff',
                                    style: TextStyle(
                                      color: TwColors.slate900,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const Center(child: SvLoader.page())
                      else if (_staff.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: TwColors.brightGreen.withValues(
                                      alpha: 0.1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.people_outline_rounded,
                                    size: 48,
                                    color: TwColors.brightGreen,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'No staff added yet',
                                  style: TextStyle(
                                    color: TwColors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Pull down to refresh or add your first staff member',
                                  style: TextStyle(
                                    color: TwColors.slate400,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                GestureDetector(
                                  onTap: _loadStaff,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: TwColors.brightGreen.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: TwColors.brightGreen.withValues(
                                          alpha: 0.3,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.refresh_rounded,
                                          color: TwColors.brightGreen,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Refresh',
                                          style: TextStyle(
                                            color: TwColors.brightGreen,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
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
                      if (_filteredStaff.isNotEmpty)
                        ..._filteredStaff.map(
                          (staffMember) => _buildStaffCard(staffMember),
                        ),
                      if (_filteredStaff.isEmpty && _selectedFilter != 'All')
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.filter_list_off_rounded,
                                  size: 48,
                                  color: TwColors.white.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No $_selectedFilter staff found',
                                  style: TextStyle(
                                    color: TwColors.white.withValues(
                                      alpha: 0.6,
                                    ),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
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
                color: TwColors.white.withValues(alpha: 0.07),
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
              'Staff Management',
              style: TextStyle(
                color: TwColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TwColors.slate700, width: 1),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase().trim();
              });
            },
            style: const TextStyle(
              color: TwColors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Search staff...',
              hintStyle: TextStyle(
                color: TwColors.white.withValues(alpha: 0.35),
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: TwColors.white.withValues(alpha: 0.5),
                size: 22,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
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
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? TwColors.brightGreen.withValues(alpha: 0.12)
                        : TwColors.slate800,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? TwColors.brightGreen.withValues(alpha: 0.3)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected
                          ? TwColors.brightGreen
                          : TwColors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TwColors.slate700, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  user['fullName'] ?? 'Unnamed',
                  style: const TextStyle(
                    color: TwColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SVStatusBadge(
                text: staffMember['role'] ?? 'Unknown',
                type: _statusFromRole(staffMember['role']),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.phone_outlined,
            value: user['phone'] ?? 'No phone',
          ),
          if (staffMember['branch'] != null || staffMember['branchId'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _InfoRow(
                icon: Icons.storefront_outlined,
                value: staffMember['branch']?['name'] ?? 'Assigned to branch',
              ),
            ),
          if (canEdit || canRemove)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  if (canEdit)
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        onTap: () => _showEditStaffSheet(context, staffMember),
                      ),
                    ),
                  if (canEdit && canRemove) const SizedBox(width: 8),
                  if (canRemove)
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.delete_outline,
                        label: 'Remove',
                        onTap: () => _removeStaff(staffMember['id']),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showAddStaffSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddStaffSheet(onStaffAdded: _loadStaff),
    );
  }

  void _showEditStaffSheet(BuildContext context, dynamic staffMember) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _EditStaffSheet(staffMember: staffMember, onStaffUpdated: _loadStaff),
    );
  }

  Future<void> _removeStaff(String staffId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TwColors.primaryBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: TwColors.slate700, width: 1),
        ),
        title: const Text(
          'Remove Staff Member',
          style: TextStyle(
            color: TwColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to remove this staff member? This action cannot be undone.',
          style: TextStyle(
            color: TwColors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: TwColors.white.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: TwColors.red500.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: TwColors.red500.withValues(alpha: 0.3)),
              ),
            ),
            child: const Text(
              'Remove',
              style: TextStyle(
                color: TwColors.red500,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
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

  BadgeType _statusFromRole(String? role) {
    switch (role?.toLowerCase()) {
      case 'owner':
        return BadgeType.success;
      case 'manager':
        return BadgeType.info;
      case 'cashier':
        return BadgeType.warning;
      case 'waiter':
        return BadgeType.neutral;
      default:
        return BadgeType.neutral;
    }
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
        Icon(icon, size: 16, color: TwColors.slate400),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: TwColors.white.withValues(alpha: 0.8),
              fontSize: 12,
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
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRemove = label == 'Remove';
    final color = isRemove ? TwColors.red500 : TwColors.brightGreen;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
      backgroundColor: TwColors.primaryBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
        color: TwColors.primaryBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TwColors.slate700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add New Staff',
                    style: TextStyle(
                      color: TwColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: TwColors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: TwColors.slate700, width: 1),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: TwColors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _FormField(
                controller: _fullNameCtrl,
                label: 'Full Name',
                hint: 'e.g. David Mekonnen',
                icon: Icons.person_outline_rounded,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _FormField(
                controller: _usernameCtrl,
                label: 'Username (staff logs in with this)',
                hint: 'e.g. david.cashier',
                icon: Icons.badge_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!RegExp(r'^[a-zA-Z0-9._-]{3,30}$').hasMatch(v.trim())) {
                    return '3-30 characters: letters, numbers, dots, dashes, underscores';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const _SheetLabel(label: 'Role'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TwColors.slate700, width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    isExpanded: true,
                    dropdownColor: Colors.black,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: TwColors.white.withValues(alpha: 0.5),
                    ),
                    style: const TextStyle(
                      color: TwColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    items: _roles.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(role[0].toUpperCase() + role.substring(1)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedRole = v!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _SheetLabel(label: 'Branch (Optional)'),
              const SizedBox(height: 8),
              _isLoadingBranches
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TwColors.slate700, width: 1),
                      ),
                      child: const Row(
                        children: [
                          SvLoader.inline(),
                          SizedBox(width: 10),
                          Text(
                            'Loading branches...',
                            style: TextStyle(
                              color: TwColors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _branches.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TwColors.slate700, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No branches yet',
                            style: TextStyle(
                              color: TwColors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add a branch first to assign staff to it',
                            style: TextStyle(
                              color: TwColors.white.withValues(alpha: 0.45),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TwColors.slate700, width: 1),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedBranchId,
                          isExpanded: true,
                          dropdownColor: Colors.black,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: TwColors.white.withValues(alpha: 0.5),
                          ),
                          style: const TextStyle(
                            color: TwColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('No Branch'),
                            ),
                            ..._branches.map((branch) {
                              return DropdownMenuItem<String?>(
                                value: branch['id'],
                                child: Text(branch['name']),
                              );
                            }),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedBranchId = v),
                        ),
                      ),
                    ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TwColors.brightGreen,
                    foregroundColor: TwColors.primaryBg,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: _isSubmitting
                      ? const SvLoader.button()
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.send_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Send Invitation',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
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

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool obscureText;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: TwColors.white.withValues(alpha: 0.65),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          obscureText: obscureText,
          style: const TextStyle(
            color: TwColors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: TwColors.white.withValues(alpha: 0.3),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              icon,
              color: TwColors.white.withValues(alpha: 0.5),
              size: 18,
            ),
            filled: true,
            fillColor: Colors.black,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: TwColors.slate700, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: TwColors.slate700, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: TwColors.brightGreen,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: TwColors.red500, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: TwColors.red500, width: 1.5),
            ),
            errorStyle: const TextStyle(color: TwColors.red500, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String label;
  const _SheetLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: TwColors.white.withValues(alpha: 0.5),
        fontSize: 13,
        fontWeight: FontWeight.w600,
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
    _selectedBranchId = widget.staffMember['branchId'];
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
        color: TwColors.primaryBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TwColors.slate700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Staff Member',
                    style: TextStyle(
                      color: TwColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: TwColors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: TwColors.slate700, width: 1),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: TwColors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _FormField(
                controller: _fullNameCtrl,
                label: 'Full Name',
                hint: 'e.g. David Mekonnen',
                icon: Icons.person_outline_rounded,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              // Phone number (readonly)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TwColors.slate800.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TwColors.slate700, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.phone_rounded,
                      color: TwColors.white.withValues(alpha: 0.3),
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phone Number',
                          style: TextStyle(
                            color: TwColors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user['phone'] ?? 'No phone',
                          style: TextStyle(
                            color: TwColors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _SheetLabel(label: 'Role'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TwColors.slate700, width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    isExpanded: true,
                    dropdownColor: Colors.black,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: TwColors.white.withValues(alpha: 0.5),
                    ),
                    style: const TextStyle(
                      color: TwColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    items: _roles.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(role[0].toUpperCase() + role.substring(1)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedRole = v!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _SheetLabel(label: 'Branch (Optional)'),
              const SizedBox(height: 8),
              _isLoadingBranches
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TwColors.slate700, width: 1),
                      ),
                      child: const Row(
                        children: [
                          SvLoader.inline(),
                          SizedBox(width: 10),
                          Text(
                            'Loading branches...',
                            style: TextStyle(
                              color: TwColors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _branches.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TwColors.slate700, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No branches yet',
                            style: TextStyle(
                              color: TwColors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add a branch first to assign staff to it',
                            style: TextStyle(
                              color: TwColors.white.withValues(alpha: 0.45),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TwColors.slate700, width: 1),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedBranchId,
                          isExpanded: true,
                          dropdownColor: Colors.black,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: TwColors.white.withValues(alpha: 0.5),
                          ),
                          style: const TextStyle(
                            color: TwColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('No Branch'),
                            ),
                            ..._branches.map((branch) {
                              return DropdownMenuItem<String?>(
                                value: branch['id'],
                                child: Text(branch['name']),
                              );
                            }),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedBranchId = v),
                        ),
                      ),
                    ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TwColors.brightGreen,
                    foregroundColor: TwColors.primaryBg,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: _isSubmitting
                      ? const SvLoader.button()
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Update Staff',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
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
      final authState = ref.read(authNotifierProvider);
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
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'QR Invitation',
            style: TextStyle(
              color: TwColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Show this QR to the staff member. It expires in $_countdown '
            'and works only once.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: TwColors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          if (expired) ...[
            Container(
              width: 200,
              height: 200,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TwColors.slate800,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'QR expired',
                style: TextStyle(
                  color: TwColors.red500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: _currentLink,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _revoke,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TwColors.red500,
                    side: BorderSide(
                      color: TwColors.red500.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.block_rounded, size: 18),
                  label: const Text(
                    'Revoke',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _regenerate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TwColors.brightGreen,
                    foregroundColor: TwColors.primaryBg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    expired ? 'New QR' : 'Regenerate',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
