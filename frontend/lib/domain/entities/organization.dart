class Organization {
  final String id;
  final String name;
  final String type;
  final String phone;
  final String? email;
  final String? address;
  final String? city;
  final String? country;
  final String? logoUrl;
  final String? subscriptionPlan;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Organization({
    required this.id,
    required this.name,
    required this.type,
    required this.phone,
    this.email,
    this.address,
    this.city,
    this.country,
    this.logoUrl,
    this.subscriptionPlan,
    this.status = "active",
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory to create from JSON
  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      logoUrl: json['logoUrl'] as String?,
      subscriptionPlan: json['subscriptionPlan'] as String?,
      status: json['status'] as String? ?? "active",
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
