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
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      country: json['country']?.toString(),
      logoUrl: json['logoUrl']?.toString(),
      subscriptionPlan: json['subscriptionPlan']?.toString(),
      status: json['status']?.toString() ?? "active",
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : DateTime.now(),
    );
  }
}
