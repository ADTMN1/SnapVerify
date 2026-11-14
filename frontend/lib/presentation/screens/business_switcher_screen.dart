import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class BusinessSwitcherScreen extends ConsumerWidget {
  final bool isInitialSelection;

  const BusinessSwitcherScreen({
    super.key,
    this.isInitialSelection = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final authNotifier = ref.read(authNotifierProvider.notifier);

    final memberships = authState.availableOrganizations;
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: !isInitialSelection,
        title: Text(
          isInitialSelection ? 'Choose Business' : 'Switch Business',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authState.pendingUser?.fullName != null
                          ? 'Hello, ${authState.pendingUser!.fullName}! 👋'
                          : authState.user?.fullName != null
                              ? 'Hello, ${authState.user!.fullName}! 👋'
                              : 'Welcome! 👋',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isInitialSelection
                          ? 'Select a business to continue.'
                          : 'Select a business to switch to.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Expanded(
                      child: ListView.separated(
                        itemCount: memberships.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final m = memberships[index];
                          final isSelected =
                              !isInitialSelection &&
                              authState.organization?.id == m.organizationId;
                          return _BusinessCard(
                            membership: m,
                            isSelected: isSelected,
                            onTap: () async {
                              if (isInitialSelection) {
                                await authNotifier.selectBusiness(m.organizationId);
                              } else {
                                await authNotifier.switchBusiness(m.organizationId);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              }
                            },
                          );
                        },
                      ),
                    ),
                    if (authState.status == AuthStatus.error) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          authState.errorMessage ?? 'An error occurred',
                          style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final UserBusinessMembership membership;
  final bool isSelected;
  final VoidCallback onTap;

  const _BusinessCard({
    required this.membership,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFF2563EB).withOpacity(0.05) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.store_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      membership.organizationName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _roleColor(membership.role).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            membership.role.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _roleColor(membership.role),
                            ),
                          ),
                        ),
                        if (membership.branchId != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Branch',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: isSelected ? const Color(0xFF2563EB) : Colors.grey[400],
                size: isSelected ? 26 : 28,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return const Color(0xFFB45309);
      case UserRole.manager:
        return const Color(0xFF7C3AED);
      case UserRole.cashier:
        return const Color(0xFF059669);
      case UserRole.waiter:
        return const Color(0xFF0284C7);
      case UserRole.unknown:
        return Colors.grey;
    }
  }
}
