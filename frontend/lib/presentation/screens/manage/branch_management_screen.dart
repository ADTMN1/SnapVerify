import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/tailwind.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/sv_status_badge.dart';

class BranchManagementScreen extends ConsumerStatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  ConsumerState<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends ConsumerState<BranchManagementScreen> {
  List<dynamic> _branches = [];
  bool _isLoading = true;

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
        final branches = await ref.read(authRepositoryProvider).getBranches(authState.tokens!.accessToken);
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
      print('Error loading branches: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load branches: ${e.toString()}'),
            backgroundColor: TwColors.red500,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwColors.primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadBranches,
                color: TwColors.brightGreen,
                backgroundColor: TwColors.slate800,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ref.watch(authNotifierProvider).role.canAddBranch)
                        GestureDetector(
                          onTap: () => _showAddBranchSheet(context),
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
                                    Icons.add_rounded,
                                    color: TwColors.slate900,
                                    size: 22,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Add New Branch',
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
                      else if (_branches.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: TwColors.brightGreen.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.storefront_outlined,
                                    size: 48,
                                    color: TwColors.brightGreen,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'No branches added yet',
                                  style: TextStyle(
                                    color: TwColors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Pull down to refresh or add your first branch',
                                  style: TextStyle(
                                    color: TwColors.slate400,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                GestureDetector(
                                  onTap: _loadBranches,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: TwColors.brightGreen.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: TwColors.brightGreen.withValues(alpha: 0.3),
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
                        )
                      else
                        ..._branches.map((branch) => _buildBranchCard(branch)),
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
              'Branch Management',
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

  Widget _buildBranchCard(dynamic branch) {
    final authState = ref.watch(authNotifierProvider);
    final canEdit = authState.role.canEditBranch;
    final canRemove = authState.role.canRemoveBranch;

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
                  branch['name'] ?? 'Unnamed',
                  style: const TextStyle(
                    color: TwColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.location_on_outlined,
            value: branch['address'] ?? 'No address',
          ),
          if (branch['phone'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _InfoRow(
                icon: Icons.phone_outlined,
                value: branch['phone']!,
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
                        onTap: () => _showEditBranchSheet(context, branch),
                        isRemove: false,
                      ),
                    ),
                  if (canEdit && canRemove) const SizedBox(width: 8),
                  if (canRemove)
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.delete_outline,
                        label: 'Remove',
                        onTap: () => _removeBranch(branch['id']),
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

  Future<void> _removeBranch(String branchId) async {
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
          'Remove Branch',
          style: TextStyle(
            color: TwColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to remove this branch? This action cannot be undone.',
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
                side: BorderSide(
                  color: TwColors.red500.withValues(alpha: 0.3),
                ),
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
        await ref.read(authRepositoryProvider).removeBranch(
          authState.tokens!.accessToken,
          branchId,
        );
        _loadBranches();
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Branch removed successfully'),
              backgroundColor: TwColors.brightGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: TwColors.red500,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _showEditBranchSheet(BuildContext context, dynamic branch) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditBranchSheet(
        branch: branch,
        onBranchUpdated: _loadBranches,
      ),
    );
  }

  void _showAddBranchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddBranchSheet(onBranchAdded: _loadBranches),
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
          size: 16,
          color: TwColors.slate400,
        ),
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
  final bool isRemove;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isRemove = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRemove ? TwColors.red500 : TwColors.brightGreen;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: color,
            ),
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
          await ref.read(authRepositoryProvider).addBranch(
            authState.tokens!.accessToken,
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
            address: _addressCtrl.text.trim(),
          );
          if (mounted) {
            Navigator.pop(context);
            widget.onBranchAdded();
          }
        }
      } catch (e) {
        // Show error
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
                    'Add New Branch',
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
                      child: const Icon(Icons.close_rounded, color: TwColors.white, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _BranchFormField(
                controller: _nameCtrl,
                label: 'Branch Name',
                hint: 'e.g. Bole Main Branch',
                icon: Icons.storefront_rounded,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _BranchFormField(
                controller: _phoneCtrl,
                label: 'Phone',
                hint: '+251 9XX XXX XXX',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _BranchFormField(
                controller: _addressCtrl,
                label: 'Address',
                hint: 'e.g. Bole Road, Addis Ababa',
                icon: Icons.location_on_rounded,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _BranchFormField(
                controller: _managerCtrl,
                label: 'Manager Name (Optional)',
                hint: 'e.g. David Mekonnen',
                icon: Icons.manage_accounts_rounded,
              ),
              const SizedBox(height: 16),
              _BranchFormField(
                controller: _hoursCtrl,
                label: 'Working Hours',
                hint: 'Mon-Sat: 8:00 AM - 10:00 PM',
                icon: Icons.schedule_rounded,
              ),
              const SizedBox(height: 28),
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
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: TwColors.primaryBg, strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_business_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Add Branch',
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

class _BranchFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _BranchFormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
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
          style: const TextStyle(color: TwColors.white, fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: TwColors.white.withValues(alpha: 0.3), fontSize: 14),
            prefixIcon: Icon(icon, color: TwColors.white.withValues(alpha: 0.5), size: 18),
            filled: true,
            fillColor: Colors.black,
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

// ══════════════════════════════════════════════════════════════════════════════
// Edit Branch Sheet
// ══════════════════════════════════════════════════════════════════════════════

class _EditBranchSheet extends ConsumerStatefulWidget {
  final dynamic branch;
  final VoidCallback onBranchUpdated;

  const _EditBranchSheet({
    required this.branch,
    required this.onBranchUpdated,
  });

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
          // Note: You'll need to add an updateBranch method to the repository
          // For now, we'll show a placeholder
          await ref.read(authRepositoryProvider).updateBranch(
            authState.tokens!.accessToken,
            widget.branch['id'],
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
            address: _addressCtrl.text.trim(),
          );
          if (mounted) {
            Navigator.pop(context);
            widget.onBranchUpdated();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Branch updated successfully'),
                backgroundColor: TwColors.brightGreen,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: TwColors.red500,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                    'Edit Branch',
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
                      child: const Icon(Icons.close_rounded, color: TwColors.white, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _BranchFormField(
                controller: _nameCtrl,
                label: 'Branch Name',
                hint: 'e.g. Bole Main Branch',
                icon: Icons.storefront_rounded,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _BranchFormField(
                controller: _phoneCtrl,
                label: 'Phone',
                hint: '+251 9XX XXX XXX',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _BranchFormField(
                controller: _addressCtrl,
                label: 'Address',
                hint: 'e.g. Bole Road, Addis Ababa',
                icon: Icons.location_on_rounded,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 28),
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
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: TwColors.primaryBg, strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Update Branch',
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
