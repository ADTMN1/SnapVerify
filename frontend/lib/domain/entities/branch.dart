enum BranchStatus { active, closed, suspended }

class Branch {
  final String id;
  final String name;
  final String code;
  final String? phoneNumber;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? workingHours;
  final String? managerId;
  final String? managerName;
  final String? description;
  final BranchStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int activeStaffCount;
  final int onlineStaffCount;
  final int todaysVerifiedPayments;
  final double todaysVerifiedAmount;

  Branch({
    required this.id,
    required this.name,
    required this.code,
    this.phoneNumber,
    this.address,
    this.latitude,
    this.longitude,
    this.workingHours,
    this.managerId,
    this.managerName,
    this.description,
    this.status = BranchStatus.active,
    required this.createdAt,
    this.updatedAt,
    this.activeStaffCount = 0,
    this.onlineStaffCount = 0,
    this.todaysVerifiedPayments = 0,
    this.todaysVerifiedAmount = 0.0,
  });

  Branch copyWith({
    String? id,
    String? name,
    String? code,
    String? phoneNumber,
    String? address,
    double? latitude,
    double? longitude,
    String? workingHours,
    String? managerId,
    String? managerName,
    String? description,
    BranchStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? activeStaffCount,
    int? onlineStaffCount,
    int? todaysVerifiedPayments,
    double? todaysVerifiedAmount,
  }) {
    return Branch(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      workingHours: workingHours ?? this.workingHours,
      managerId: managerId ?? this.managerId,
      managerName: managerName ?? this.managerName,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      activeStaffCount: activeStaffCount ?? this.activeStaffCount,
      onlineStaffCount: onlineStaffCount ?? this.onlineStaffCount,
      todaysVerifiedPayments: todaysVerifiedPayments ?? this.todaysVerifiedPayments,
      todaysVerifiedAmount: todaysVerifiedAmount ?? this.todaysVerifiedAmount,
    );
  }
}
