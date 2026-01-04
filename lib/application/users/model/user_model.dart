class UserModel {
  final String id;
  final String name;
  final String designation; // role
  final String department;
  final String email;
  final String phone;
  final String status; // Active / Inactive
  final String imageUrl;

  const UserModel({
    required this.id,
    required this.name,
    required this.designation,
    required this.department,
    required this.email,
    required this.phone,
    required this.status,
    required this.imageUrl,
  });

  bool get isActive => status.toLowerCase() == "active";

  UserModel copyWith({
    String? status,
    String? imageUrl,
  }) {
    return UserModel(
      id: id,
      name: name,
      designation: designation,
      department: department,
      email: email,
      phone: phone,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
