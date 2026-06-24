class TestResultModel {
  final int? id;
  final int reportId;
  final int testId;
  final String testName;
  final String result;
  final String normalRange;
  final String unit;
  final bool isAbnormal;
  final String category;
  final int printPage;

  TestResultModel({
    this.id,
    required this.reportId,
    required this.testId,
    required this.testName,
    required this.result,
    required this.normalRange,
    required this.unit,
    this.isAbnormal = false,
    this.category = '',
    this.printPage = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reportId': reportId,
      'testId': testId,
      'testName': testName,
      'result': result,
      'normalRange': normalRange,
      'unit': unit,
      'isAbnormal': isAbnormal ? 1 : 0,
      'category': category,
      'printPage': printPage,
    };
  }

  factory TestResultModel.fromMap(Map<String, dynamic> map) {
    return TestResultModel(
      id: map['id'],
      reportId: map['reportId'],
      testId: map['testId'],
      testName: map['testName'],
      result: map['result'] ?? '',
      normalRange: map['normalRange'] ?? '',
      unit: map['unit'] ?? '',
      isAbnormal: map['isAbnormal'] == 1,
      category: map['category'] ?? '',
      printPage: map['printPage'] ?? 0,
    );
  }
}
