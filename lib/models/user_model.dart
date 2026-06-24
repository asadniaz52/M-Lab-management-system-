class UserModel {
  final int? id;
  final String username;
  final String password;
  final String fullName;
  final String role; // admin, technician
  final String phone;
  final String? createdAt;

  UserModel({
    this.id,
    required this.username,
    required this.password,
    required this.fullName,
    required this.role,
    required this.phone,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'fullName': fullName,
      'role': role,
      'phone': phone,
      'createdAt': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      username: map['username'],
      password: map['password'],
      fullName: map['fullName'],
      role: map['role'],
      phone: map['phone'],
      createdAt: map['createdAt'],
    );
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? password,
    String? fullName,
    String? role,
    String? phone,
    String? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
