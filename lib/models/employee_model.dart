class EmployeeModel {
  final int? id;
  final String name;
  final String phone;
  final String type; // employee, internee
  final String department;
  final String joinDate;
  final String? endDate;
  final String status; // active, inactive

  EmployeeModel({
    this.id,
    required this.name,
    required this.phone,
    required this.type,
    required this.department,
    required this.joinDate,
    this.endDate,
    this.status = 'active',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'type': type,
      'department': department,
      'joinDate': joinDate,
      'endDate': endDate ?? '',
      'status': status,
    };
  }

  factory EmployeeModel.fromMap(Map<String, dynamic> map) {
    return EmployeeModel(
      id: map['id'],
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      type: map['type'] ?? 'employee',
      department: map['department'] ?? '',
      joinDate: map['joinDate'] ?? '',
      endDate: map['endDate'],
      status: map['status'] ?? 'active',
    );
  }

  EmployeeModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? type,
    String? department,
    String? joinDate,
    String? endDate,
    String? status,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      type: type ?? this.type,
      department: department ?? this.department,
      joinDate: joinDate ?? this.joinDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
    );
  }
}
