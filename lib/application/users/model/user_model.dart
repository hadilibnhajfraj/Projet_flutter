class UserModel {
  final String name;
  final String designation;
  final String department;
  final String email;
  final String phone;
  final String status;
  final String imageUrl;

  UserModel({
    required this.name,
    required this.designation,
    required this.department,
    required this.email,
    required this.phone,
    required this.status,
    required this.imageUrl,
  });

  @override
  String toString() {
    return 'UserModel{name: $name}';
  }
}
