class TestModel {
  final int? id;
  final String testName;
  final String normalRange;
  final String unit;
  final double price;
  final String category;
  final int printPage;

  TestModel({
    this.id,
    required this.testName,
    required this.normalRange,
    required this.unit,
    required this.price,
    required this.category,
    this.printPage = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'testName': testName,
      'normalRange': normalRange,
      'unit': unit,
      'price': price,
      'category': category,
      'printPage': printPage,
    };
  }

  factory TestModel.fromMap(Map<String, dynamic> map) {
    return TestModel(
      id: map['id'],
      testName: map['testName'],
      normalRange: map['normalRange'] ?? '',
      unit: map['unit'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      category: map['category'] ?? 'General',
      printPage: map['printPage'] ?? 0,
    );
  }

  TestModel copyWith({
    int? id,
    String? testName,
    String? normalRange,
    String? unit,
    double? price,
    String? category,
    int? printPage,
  }) {
    return TestModel(
      id: id ?? this.id,
      testName: testName ?? this.testName,
      normalRange: normalRange ?? this.normalRange,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      category: category ?? this.category,
      printPage: printPage ?? this.printPage,
    );
  }
}
