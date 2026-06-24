class TestParameterModel {
  final int? id;
  final int parentTestId;
  final String paramName;
  final String normalRange;
  final String unit;
  final int sortOrder;
  final String rangeType; // 'normal', 'negative', 'nil', 'multi'
  final String normalRangeMale;
  final String normalRangeFemale;
  final String normalRangeChild;

  TestParameterModel({
    this.id,
    required this.parentTestId,
    required this.paramName,
    required this.normalRange,
    required this.unit,
    this.sortOrder = 0,
    this.rangeType = 'normal',
    this.normalRangeMale = '',
    this.normalRangeFemale = '',
    this.normalRangeChild = '',
  });

  /// Returns a display-friendly normal range string.
  /// For 'multi' type, formats as "M: x | F: y | C: z".
  String get displayRange {
    switch (rangeType) {
      case 'negative':
        return normalRange.isNotEmpty ? normalRange : 'Negative';
      case 'nil':
        return '-';
      case 'multi':
        final parts = <String>[];
        if (normalRangeMale.isNotEmpty) parts.add('M: $normalRangeMale');
        if (normalRangeFemale.isNotEmpty) parts.add('F: $normalRangeFemale');
        if (normalRangeChild.isNotEmpty) parts.add('C: $normalRangeChild');
        return parts.isNotEmpty ? parts.join(' | ') : '-';
      default:
        return normalRange;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parentTestId': parentTestId,
      'paramName': paramName,
      'normalRange': normalRange,
      'unit': unit,
      'sortOrder': sortOrder,
      'rangeType': rangeType,
      'normalRangeMale': normalRangeMale,
      'normalRangeFemale': normalRangeFemale,
      'normalRangeChild': normalRangeChild,
    };
  }

  factory TestParameterModel.fromMap(Map<String, dynamic> map) {
    return TestParameterModel(
      id: map['id'],
      parentTestId: map['parentTestId'],
      paramName: map['paramName'] ?? '',
      normalRange: map['normalRange'] ?? '',
      unit: map['unit'] ?? '',
      sortOrder: map['sortOrder'] ?? 0,
      rangeType: map['rangeType'] ?? 'normal',
      normalRangeMale: map['normalRangeMale'] ?? '',
      normalRangeFemale: map['normalRangeFemale'] ?? '',
      normalRangeChild: map['normalRangeChild'] ?? '',
    );
  }

  TestParameterModel copyWith({
    int? id,
    int? parentTestId,
    String? paramName,
    String? normalRange,
    String? unit,
    int? sortOrder,
    String? rangeType,
    String? normalRangeMale,
    String? normalRangeFemale,
    String? normalRangeChild,
  }) {
    return TestParameterModel(
      id: id ?? this.id,
      parentTestId: parentTestId ?? this.parentTestId,
      paramName: paramName ?? this.paramName,
      normalRange: normalRange ?? this.normalRange,
      unit: unit ?? this.unit,
      sortOrder: sortOrder ?? this.sortOrder,
      rangeType: rangeType ?? this.rangeType,
      normalRangeMale: normalRangeMale ?? this.normalRangeMale,
      normalRangeFemale: normalRangeFemale ?? this.normalRangeFemale,
      normalRangeChild: normalRangeChild ?? this.normalRangeChild,
    );
  }
}
