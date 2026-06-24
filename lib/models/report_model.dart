import 'test_result_model.dart';

class ReportModel {
  final int? id;
  final int patientId;
  final String patientName;
  final String date;
  final String status; // pending, completed
  final String? remarks;
  final String? referredBy;
  final String? verifiedBy;
  final String? verifiedAt;
  final String? specimen;
  final List<TestResultModel> testResults;

  ReportModel({
    this.id,
    required this.patientId,
    required this.patientName,
    required this.date,
    required this.status,
    this.remarks,
    this.referredBy,
    this.verifiedBy,
    this.verifiedAt,
    this.specimen,
    this.testResults = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'date': date,
      'status': status,
      'remarks': remarks ?? '',
      'referredBy': referredBy ?? '',
      'verifiedBy': verifiedBy ?? '',
      'verifiedAt': verifiedAt ?? '',
      'specimen': specimen ?? '',
    };
  }

  factory ReportModel.fromMap(Map<String, dynamic> map, [List<TestResultModel>? results]) {
    return ReportModel(
      id: map['id'],
      patientId: map['patientId'],
      patientName: map['patientName'] ?? '',
      date: map['date'],
      status: map['status'] ?? 'pending',
      remarks: map['remarks'],
      referredBy: map['referredBy'],
      verifiedBy: map['verifiedBy'],
      verifiedAt: map['verifiedAt'],
      specimen: map['specimen'],
      testResults: results ?? [],
    );
  }

  ReportModel copyWith({
    int? id,
    int? patientId,
    String? patientName,
    String? date,
    String? status,
    String? remarks,
    String? referredBy,
    String? verifiedBy,
    String? verifiedAt,
    String? specimen,
    List<TestResultModel>? testResults,
  }) {
    return ReportModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      date: date ?? this.date,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      referredBy: referredBy ?? this.referredBy,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      specimen: specimen ?? this.specimen,
      testResults: testResults ?? this.testResults,
    );
  }
}
