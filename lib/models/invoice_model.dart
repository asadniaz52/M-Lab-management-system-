class InvoiceItemModel {
  final int? id;
  final int invoiceId;
  final String testName;
  final double price;

  InvoiceItemModel({
    this.id,
    required this.invoiceId,
    required this.testName,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'testName': testName,
      'price': price,
    };
  }

  factory InvoiceItemModel.fromMap(Map<String, dynamic> map) {
    return InvoiceItemModel(
      id: map['id'],
      invoiceId: map['invoiceId'],
      testName: map['testName'],
      price: (map['price'] ?? 0).toDouble(),
    );
  }
}

class InvoiceModel {
  final int? id;
  final int patientId;
  final String patientName;
  final int? reportId;
  final double totalAmount;
  final double discount;
  final double paidAmount;
  final String date;
  final String status; // paid, unpaid, partial
  final List<InvoiceItemModel> items;

  InvoiceModel({
    this.id,
    required this.patientId,
    required this.patientName,
    this.reportId,
    required this.totalAmount,
    required this.discount,
    required this.paidAmount,
    required this.date,
    required this.status,
    this.items = const [],
  });

  double get netAmount => totalAmount - discount;
  double get dueAmount => netAmount - paidAmount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'reportId': reportId,
      'totalAmount': totalAmount,
      'discount': discount,
      'paidAmount': paidAmount,
      'date': date,
      'status': status,
    };
  }

  factory InvoiceModel.fromMap(Map<String, dynamic> map, [List<InvoiceItemModel>? items]) {
    return InvoiceModel(
      id: map['id'],
      patientId: map['patientId'],
      patientName: map['patientName'] ?? '',
      reportId: map['reportId'],
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      paidAmount: (map['paidAmount'] ?? 0).toDouble(),
      date: map['date'],
      status: map['status'] ?? 'unpaid',
      items: items ?? [],
    );
  }
}
