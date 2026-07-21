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
      id: json['id'] as String,
      fullName: json['fullName'] as String?,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      status: json['status'] as String? ?? "active",
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
