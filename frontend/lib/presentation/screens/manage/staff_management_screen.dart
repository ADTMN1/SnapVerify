import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/tailwind.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/sv_status_badge.dart';

class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  ConsumerState<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> {
  final _searchController = TextEditingController();
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

  Future<void> _loadStaff() async {
    try {
      final authState = ref.read(authNotifierProvider);
      if (authState.tokens?.accessToken != null) {
        final staff = await ref.read(authRepositoryProvider).getStaff(authState.tokens!.accessToken);
        setState(() {
          _staff = staff;
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                      const Center(child: CircularProgressIndicator(color: TwColors.brightGreen))
                    else if (_staff.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            'No staff added yet',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._staff.map((staffMember) => _buildStaffCard(staffMember)),
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
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: TwColors.slate800,
            width: 1,
          ),
        ),
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
                border: Border.all(
                  color: TwColors.slate700,
                  width: 1,
                ),
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
            color: TwColors.slate700,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: TwColors.slate600,
              width: 1,
            ),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(
              color: TwColors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Search staff...',
              hintStyle: TextStyle(
                color: TwColors.white.withOpacity(0.5),
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: TwColors.white.withOpacity(0.6),
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
                        ? TwColors.brightGreen.withOpacity(0.2)
                        : TwColors.slate800,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? TwColors.brightGreen.withOpacity(0.4)
                          : Colors.transparent,
                      width: isSelected ? 1.5 : 0,
                    ),
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? TwColors.brightGreen : TwColors.white.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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

  Widget _buildStaffCard(dynamic staffMember) {
    final authState = ref.watch(authNotifierProvider);
    final canEdit = authState.role.canAddStaff;
    final canRemove = authState.role.canRemoveStaff;
    final user = staffMember['user'] ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TwColors.slate800,
        borderRadius: BorderRadius.circular(14),
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
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  if (canEdit)
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        onTap: () {},
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

  Future<void> _removeStaff(String staffId) async {
    try {
      final authState = ref.read(authNotifierProvider);
      if (authState.tokens?.accessToken != null) {
        await ref.read(authRepositoryProvider).removeStaff(authState.tokens!.accessToken, staffId);
        _loadStaff();
      }
    } catch (e) {
      // Show error
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

  const _InfoRow({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: TwColors.white.withOpacity(0.6),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: TwColors.white.withOpacity(0.8),
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: TwColors.slate700,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: TwColors.white.withOpacity(0.8),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: TwColors.white.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _selectedRole = 'cashier';
  String? _selectedBranchId;
  List<dynamic> _branches = [];
  bool _isLoadingBranches = true;

  final List<String> _roles = ['owner', 'manager', 'cashier', 'waiter'];

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
        final branches = await ref.read(authRepositoryProvider).getBranches(authState.tokens!.accessToken);
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
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
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
          print('DEBUG: Adding staff with role=$_selectedRole, phone=${_phoneCtrl.text.trim()}');
          await ref.read(authRepositoryProvider).addStaff(
            authState.tokens!.accessToken,
            fullName: _fullNameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            role: _selectedRole,
            password: _passwordCtrl.text.trim().isNotEmpty ? _passwordCtrl.text.trim() : null,
            branchId: _selectedBranchId,
          );
          if (mounted) {
            Navigator.pop(context);
            widget.onStaffAdded();
          }
        }
      } catch (e) {
        print('DEBUG: Error adding staff: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
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
                    color: TwColors.slate600,
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
                        color: TwColors.slate800,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: TwColors.slate700, width: 1),
                      ),
                      child: const Icon(Icons.close_rounded, color: TwColors.white, size: 18),
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
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _FormField(
                controller: _phoneCtrl,
                label: 'Phone Number',
                hint: '+251 9XX XXX XXX',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim().length < 9) return 'Enter a valid phone number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _FormField(
                controller: _passwordCtrl,
                label: 'Password (Optional)',
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                obscureText: true,
              ),
              const SizedBox(height: 16),
              const _SheetLabel(label: 'Role'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: TwColors.slate800,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TwColors.slate700, width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    isExpanded: true,
                    dropdownColor: TwColors.slate800,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: TwColors.white.withOpacity(0.5)),
                    style: const TextStyle(color: TwColors.white, fontSize: 14, fontWeight: FontWeight.w500),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      decoration: BoxDecoration(
                        color: TwColors.slate800,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TwColors.slate700, width: 1),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: TwColors.brightGreen, strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Loading branches...',
                            style: TextStyle(color: TwColors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : _branches.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: TwColors.slate800.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: TwColors.slate700, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No branches yet',
                                style: TextStyle(
                                  color: TwColors.white.withOpacity(0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add a branch first to assign staff to it',
                                style: TextStyle(
                                  color: TwColors.white.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: TwColors.slate800,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: TwColors.slate700, width: 1),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _selectedBranchId,
                              isExpanded: true,
                              dropdownColor: TwColors.slate800,
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: TwColors.white.withOpacity(0.5)),
                              style: const TextStyle(color: TwColors.white, fontSize: 14, fontWeight: FontWeight.w500),
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
                              onChanged: (v) => setState(() => _selectedBranchId = v),
                            ),
                          ),
                        ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TwColors.brightGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_add_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Add Staff',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
            color: TwColors.white.withOpacity(0.65),
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
          style: const TextStyle(color: TwColors.white, fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: TwColors.white.withOpacity(0.3), fontSize: 14),
            prefixIcon: Icon(icon, color: TwColors.white.withOpacity(0.4), size: 18),
            filled: true,
            fillColor: TwColors.slate800,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              borderSide: const BorderSide(color: TwColors.brightGreen, width: 1.5),
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
        color: TwColors.white.withOpacity(0.65),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
