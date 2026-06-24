import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/patient_model.dart';
import '../../models/test_model.dart';
import '../../theme/app_theme.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  List<PatientModel> _existingPatients = [];
  List<TestModel> _availableTests = [];
  final List<_InvoiceItem> _items = [];
  final _discountCtrl = TextEditingController(text: '0');
  final _paidCtrl = TextEditingController(text: '0');
  final _referredByCtrl = TextEditingController();
  final _testSearchCtrl = TextEditingController();

  // Patient fields (inline)
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _patientSearchCtrl = TextEditingController();
  final _nicCtrl = TextEditingController();
  final _specimenCtrl = TextEditingController(text: 'Blood');
  String _gender = 'Male';
  PatientModel? _selectedExisting;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final patients = await DBHelper.getAllPatients();
    final tests = await DBHelper.getAllTests();
    setState(() {
      _existingPatients = patients.map((e) => PatientModel.fromMap(e)).toList();
      _availableTests = tests.map((e) => TestModel.fromMap(e)).toList();
    });
  }

  double get _total => _items.fold(0, (sum, item) => sum + item.price);
  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _net => _total - _discount;
  double get _paid => double.tryParse(_paidCtrl.text) ?? 0;
  double get _due => _net - _paid;

  List<TestModel> get _filteredTests {
    final query = _testSearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _availableTests;
    return _availableTests.where((t) =>
        t.testName.toLowerCase().contains(query) ||
        t.category.toLowerCase().contains(query)).toList();
  }

  List<PatientModel> get _filteredPatients {
    final query = _patientSearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _existingPatients;
    return _existingPatients.where((p) =>
        p.name.toLowerCase().contains(query) ||
        p.phone.toLowerCase().contains(query)).toList();
  }

  void _selectExistingPatient(PatientModel p) {
    setState(() {
      _selectedExisting = p;
      _nameCtrl.text = p.name;
      _ageCtrl.text = p.age == 0 ? '' : p.age.toString();
      _gender = p.gender;
      _phoneCtrl.text = p.phone;
      _nicCtrl.text = p.nic ?? '';
      _patientSearchCtrl.clear();
    });
  }

  void _clearPatient() {
    setState(() {
      _selectedExisting = null;
      _nameCtrl.clear();
      _ageCtrl.clear();
      _phoneCtrl.clear();
      _nicCtrl.clear();
      _specimenCtrl.text = 'Blood';
      _gender = 'Male';
    });
  }

  void _addTest(TestModel test) {
    if (_items.any((item) => item.testId == test.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${test.testName} already added'), backgroundColor: AppTheme.warning),
      );
      return;
    }
    setState(() {
      _items.add(_InvoiceItem(testId: test.id!, testName: test.testName, price: test.price, category: test.category, printPage: test.printPage));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _save() async {
    // Validate patient name
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter patient name'), backgroundColor: AppTheme.error),
      );
      return;
    }
    final ageText = _ageCtrl.text.trim();
    if (ageText.isNotEmpty && int.tryParse(ageText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid patient age (number)'), backgroundColor: AppTheme.error),
      );
      return;
    }
    final patientAge = ageText.isEmpty ? 0 : int.parse(ageText);
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one test/item'), backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() => _saving = true);

    // Get or create patient
    int patientId;
    String patientName = _nameCtrl.text.trim();

    if (_selectedExisting != null && _selectedExisting!.name == patientName) {
      // Using existing patient
      patientId = _selectedExisting!.id!;
      // Also update patient CNIC if changed
      if ((_selectedExisting!.nic ?? '') != _nicCtrl.text.trim()) {
        await DBHelper.updatePatient(patientId, {
          'name': _selectedExisting!.name,
          'age': _selectedExisting!.age,
          'gender': _selectedExisting!.gender,
          'phone': _phoneCtrl.text.trim(),
          'address': _selectedExisting!.address,
          'nic': _nicCtrl.text.trim(),
          'createdAt': _selectedExisting!.createdAt,
        });
      }
    } else {
      // Create new patient
      final patientData = {
        'name': patientName,
        'age': patientAge,
        'gender': _gender,
        'phone': _phoneCtrl.text.trim(),
        'address': '',
        'nic': _nicCtrl.text.trim(),
        'createdAt': DateTime.now().toIso8601String(),
      };
      patientId = await DBHelper.insertPatient(patientData);
    }

    String status;
    if (_paid >= _net) {
      status = 'paid';
    } else if (_paid > 0) {
      status = 'partial';
    } else {
      status = 'unpaid';
    }

    // 1. Auto-create a pending report with the selected tests
    final reportId = await DBHelper.insertReport({
      'patientId': patientId,
      'patientName': patientName,
      'date': DateTime.now().toIso8601String(),
      'status': 'pending',
      'remarks': '',
      'referredBy': _referredByCtrl.text.trim(),
      'verifiedBy': '',
      'verifiedAt': '',
      'specimen': _specimenCtrl.text.trim(),
    });

    // 2. Insert test results as pending (empty results)
    for (var item in _items) {
      // Check if test has sub-parameters
      final params = await DBHelper.getTestParameters(item.testId);
      if (params.isNotEmpty) {
        for (var p in params) {
          // For multi-range parameters, build the formatted normalRange string
          final rangeType = p['rangeType'] ?? 'normal';
          String normalRange = p['normalRange'] ?? '';
          if (rangeType == 'multi') {
            final parts = <String>[];
            if ((p['normalRangeMale'] ?? '').toString().isNotEmpty) parts.add('M: ${p['normalRangeMale']}');
            if ((p['normalRangeFemale'] ?? '').toString().isNotEmpty) parts.add('F: ${p['normalRangeFemale']}');
            if ((p['normalRangeChild'] ?? '').toString().isNotEmpty) parts.add('C: ${p['normalRangeChild']}');
            normalRange = parts.join(' | ');
          }

          await DBHelper.insertTestResult({
            'reportId': reportId,
            'testId': item.testId,
            'testName': p['paramName'] ?? '',
            'result': '',
            'normalRange': normalRange,
            'unit': p['unit'] ?? '',
            'isAbnormal': 0,
            'category': item.category,
            'printPage': item.printPage,
          });
        }
      } else {
        // Get test details for normal range and unit
        final testData = await DBHelper.getTestById(item.testId);
        await DBHelper.insertTestResult({
          'reportId': reportId,
          'testId': item.testId,
          'testName': item.testName,
          'result': '',
          'normalRange': testData?['normalRange'] ?? '',
          'unit': testData?['unit'] ?? '',
          'isAbnormal': 0,
          'category': item.category,
          'printPage': item.printPage,
        });
      }
    }

    // 3. Create invoice linked to the report
    final invoiceId = await DBHelper.insertInvoice({
      'patientId': patientId,
      'patientName': patientName,
      'reportId': reportId,
      'totalAmount': _total,
      'discount': _discount,
      'paidAmount': _paid,
      'date': DateTime.now().toIso8601String(),
      'status': status,
    });

    for (var item in _items) {
      await DBHelper.insertInvoiceItem({
        'invoiceId': invoiceId,
        'testId': item.testId,
        'testName': item.testName,
        'price': item.price,
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice #$invoiceId created with pending Report #$reportId'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _paidCtrl.dispose();
    _referredByCtrl.dispose();
    _testSearchCtrl.dispose();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    _nicCtrl.dispose();
    _specimenCtrl.dispose();
    _patientSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(title: const Text('Create Invoice')),
      body: Row(
        children: [
          // Left: Patient info + Test selection
          SizedBox(
            width: 370,
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // --- Patient Section ---
                    Row(
                      children: [
                        const Icon(Icons.person_rounded, size: 20, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        const Text('Patient Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (_nameCtrl.text.isNotEmpty)
                          TextButton.icon(
                            onPressed: _clearPatient,
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text('Clear', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.error,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search existing patient
                    TextField(
                      controller: _patientSearchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search existing patient...',
                        prefixIcon: const Icon(Icons.person_search_outlined, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        suffixIcon: _patientSearchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _patientSearchCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),

                    // Show search results as a small dropdown
                    if (_patientSearchCtrl.text.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filteredPatients.length,
                          itemBuilder: (_, i) {
                            final p = _filteredPatients[i];
                            return ListTile(
                              dense: true,
                              visualDensity: const VisualDensity(vertical: -4),
                              title: Text(p.name, style: const TextStyle(fontSize: 13)),
                              subtitle: Text('${p.age}y / ${p.gender} · ${p.phone}', style: const TextStyle(fontSize: 11)),
                              onTap: () => _selectExistingPatient(p),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 12),
                    // Patient name
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Patient Name *',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
 
                    // Age + Gender row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ageCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Age (optional)',
                              prefixIcon: Icon(Icons.cake_outlined, size: 20),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _gender,
                            decoration: const InputDecoration(
                              labelText: 'Gender',
                              isDense: true,
                            ),
                            items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                            onChanged: (v) => setState(() => _gender = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
 
                    // Phone & CNIC row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              prefixIcon: Icon(Icons.phone_outlined, size: 20),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _nicCtrl,
                            decoration: const InputDecoration(
                              labelText: 'CNIC / Identity #',
                              prefixIcon: Icon(Icons.credit_card_outlined, size: 20),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Specimen field
                    TextFormField(
                      controller: _specimenCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Specimen (e.g. Blood, Urine, Stool)',
                        prefixIcon: Icon(Icons.biotech_rounded, size: 20),
                        isDense: true,
                      ),
                    ),

                    if (_selectedExisting != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                            const SizedBox(width: 6),
                            Expanded(child: Text('Existing patient #${_selectedExisting!.id}', style: const TextStyle(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.w500))),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Referred By
                    TextFormField(
                      controller: _referredByCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Referred By (Doctor)',
                        prefixIcon: Icon(Icons.medical_services_outlined, size: 20),
                        isDense: true,
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // --- Tests Section ---
                    const Text('Add Tests/Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    // Test search field
                    TextField(
                      controller: _testSearchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search tests...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        suffixIcon: _testSearchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _testSearchCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredTests.length,
                      itemBuilder: (_, i) {
                        final test = _filteredTests[i];
                        final alreadyAdded = _items.any((item) => item.testId == test.id);
                        return ListTile(
                          dense: true,
                          title: Text(test.testName, style: const TextStyle(fontSize: 13)),
                          subtitle: Text('Rs. ${test.price.toStringAsFixed(0)} · ${test.category}', style: const TextStyle(fontSize: 11)),
                          trailing: alreadyAdded
                              ? const Icon(Icons.check_circle, color: AppTheme.success, size: 20)
                              : IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor, size: 20),
                                  onPressed: () => _addTest(test),
                                ),
                        );
                      },
                    ),
                  ],
                ),
                ), // SingleChildScrollView
              ), // Padding
            ), // Card
          ), // SizedBox
          // Right: Invoice details
          Expanded(
            child: Card(
              margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Invoice Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Tests will be added to a pending report automatically', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 12),
                    if (_items.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text('Add items from the left panel', style: TextStyle(color: Colors.grey.shade400)),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('#')),
                                      DataColumn(label: Text('Item')),
                                      DataColumn(label: Text('Price')),
                                      DataColumn(label: Text('')),
                                    ],
                                    rows: _items.asMap().entries.map((entry) {
                                      return DataRow(cells: [
                                        DataCell(Text('${entry.key + 1}')),
                                        DataCell(Text(entry.value.testName)),
                                        DataCell(Text('Rs. ${entry.value.price.toStringAsFixed(0)}')),
                                        DataCell(IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error, size: 18),
                                          onPressed: () => _removeItem(entry.key),
                                        )),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                children: [
                                  _summaryRow('Subtotal', 'Rs. ${_total.toStringAsFixed(0)}'),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Text('Discount: ', style: TextStyle(fontSize: 14)),
                                      SizedBox(
                                        width: 100,
                                        child: TextField(
                                          controller: _discountCtrl,
                                          keyboardType: TextInputType.number,
                                          onChanged: (_) => setState(() {}),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            prefixText: 'Rs. ',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _summaryRow('Net Total', 'Rs. ${_net.toStringAsFixed(0)}', bold: true),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Text('Paid Amount: ', style: TextStyle(fontSize: 14)),
                                      SizedBox(
                                        width: 100,
                                        child: TextField(
                                          controller: _paidCtrl,
                                          keyboardType: TextInputType.number,
                                          onChanged: (_) => setState(() {}),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            prefixText: 'Rs. ',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _summaryRow('Due Amount', 'Rs. ${_due.toStringAsFixed(0)}', bold: true, color: _due > 0 ? AppTheme.error : AppTheme.success),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: _saving
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.save, size: 18),
                                label: const Text('Save Invoice & Create Report'),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
      ],
    );
  }
}

class _InvoiceItem {
  final int testId;
  final String testName;
  final double price;
  final String category;
  final int printPage;
  _InvoiceItem({required this.testId, required this.testName, required this.price, required this.category, this.printPage = 0});
}
