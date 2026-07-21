enum StaffStatus { active, suspended, offline, online }
enum StaffRole { owner, manager, cashier, waiter, supervisor, accountant }

class StaffPerformance {
  final double verificationAccuracy;
  final int totalVerifications;
  final double totalAmount;
  final double avgVerificationTime;
  final int fraudFlags;

  const StaffPerformance({
    this.verificationAccuracy = 100.0,
    this.totalVerifications = 0,
    this.totalAmount = 0.0,
    this.avgVerificationTime = 0.0,
    this.fraudFlags = 0,
  });
}

class Staff {
  final String id;
  final String employeeId;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final StaffRole role;
  final String branchId;
  final String branchName;
  final String phoneNumber;
  final String? email;
  final StaffStatus status;
  final DateTime? lastLogin;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final StaffPerformance todayPerformance;
  final StaffPerformance weekPerformance;
  final StaffPerformance monthPerformance;
  final StaffPerformance yearPerformance;

  String get fullName => '$firstName $lastName';

  Staff({
    required this.id,
    required this.employeeId,
    required this.firstName,
    required this.lastName,
    this.photoUrl,
    required this.role,
    required this.branchId,
    required this.branchName,
    required this.phoneNumber,
    this.email,
    this.status = StaffStatus.offline,
    this.lastLogin,
    required this.createdAt,
    this.updatedAt,
    this.todayPerformance = const StaffPerformance(),
    this.weekPerformance = const StaffPerformance(),
    this.monthPerformance = const StaffPerformance(),
    this.yearPerformance = const StaffPerformance(),
  });

  Staff copyWith({
    String? id,
    String? employeeId,
    String? firstName,
    String? lastName,
    String? photoUrl,
    StaffRole? role,
    String? branchId,
    String? branchName,
    String? phoneNumber,
    String? email,
    StaffStatus? status,
    DateTime? lastLogin,
    DateTime? createdAt,
    DateTime? updatedAt,
    StaffPerformance? todayPerformance,
    StaffPerformance? weekPerformance,
    StaffPerformance? monthPerformance,
    StaffPerformance? yearPerformance,
  }) {
    return Staff(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      status: status ?? this.status,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      todayPerformance: todayPerformance ?? this.todayPerformance,
      weekPerformance: weekPerformance ?? this.weekPerformance,
      monthPerformance: monthPerformance ?? this.monthPerformance,
      yearPerformance: yearPerformance ?? this.yearPerformance,
    );
  }
}
