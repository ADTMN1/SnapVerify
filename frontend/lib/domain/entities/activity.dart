enum ActivityType {
  login,
  logout,
  verifyPayment,
  addStaff,
  editStaff,
  suspendStaff,
  deleteStaff,
  addBranch,
  editBranch,
  disableBranch,
  deleteBranch,
  generateQR,
  regenerateQR,
  exportReport
}

class ActivityLog {
  final String id;
  final ActivityType type;
  final String title;
  final String description;
  final String? userId;
  final String? userName;
  final String? branchId;
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.userId,
    this.userName,
    this.branchId,
    required this.timestamp,
  });
}
