class PatientModel {
  final int? id;
  final String name;
  final int age;
  final String gender;
  final String phone;
  final String address;
  final String nic;
  final String? createdAt;

  PatientModel({
    this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.phone,
    required this.address,
    this.nic = '',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'gender': gender,
      'phone': phone,
      'address': address,
      'nic': nic,
      'createdAt': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory PatientModel.fromMap(Map<String, dynamic> map) {
    return PatientModel(
      id: map['id'],
      name: map['name'],
      age: map['age'],
      gender: map['gender'],
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      nic: map['nic'] ?? '',
      createdAt: map['createdAt'],
    );
  }

  PatientModel copyWith({
    int? id,
    String? name,
    int? age,
    String? gender,
    String? phone,
    String? address,
    String? nic,
    String? createdAt,
  }) {
    return PatientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      nic: nic ?? this.nic,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
