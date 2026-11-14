class User {
  final String id;
  final String? fullName;
  final String phone;
  final String? email;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    this.fullName,
    required this.phone,
    this.email,
    this.status = "active",
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory to create from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString(),
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      status: json['status']?.toString() ?? "active",
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'].toString()) : DateTime.now(),
    );
  }
}
