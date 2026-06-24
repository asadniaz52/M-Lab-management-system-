import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/patient_model.dart';
import '../../models/test_model.dart';
import '../../models/test_parameter_model.dart';
import '../../theme/app_theme.dart';

class CreateReportScreen extends StatefulWidget {
  const CreateReportScreen({super.key});

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  List<PatientModel> _patients = [];
  List<TestModel> _availableTests = [];
  Map<int, List<TestParameterModel>> _testParams = {};
  PatientModel? _selectedPatient;
  final _referredByCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _specimenCtrl = TextEditingController(text: 'Blood');

  // Selected tests/params with results
  final List<_ResultRow> _resultRows = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final patients = await DBHelper.getAllPatients();
    final tests = await DBHelper.getAllTests();
    final testModels = tests.map((e) => TestModel.fromMap(e)).toList();

    // Load params for each test
    final params = <int, List<TestParameterModel>>{};
    for (var t in testModels) {
      final p = await DBHelper.getTestParameters(t.id!);
      if (p.isNotEmpty) {
        params[t.id!] = p.map((e) => TestParameterModel.fromMap(e)).toList();
      }
    }

    setState(() {
      _patients = patients.map((e) => PatientModel.fromMap(e)).toList();
      _availableTests = testModels;
      _testParams = params;
    });
  }

  void _addTest(TestModel test) {
    if (_resultRows.any((r) => r.testId == test.id && r.paramName == null)) return;

    final params = _testParams[test.id];
    if (params != null && params.isNotEmpty) {
      // Add parent as a header row (no result input)
      _resultRows.add(_ResultRow(
        testId: test.id!,
        testName: test.testName,
        normalRange: '',
        unit: '',
        isHeader: true,
      ));
      // Add each sub-parameter as a result row
      for (var p in params) {
        _resultRows.add(_ResultRow(
          testId: test.id!,
          testName: '  ${p.paramName}',
          paramName: p.paramName,
          normalRange: p.normalRange,
          unit: p.unit,
          resultCtrl: TextEditingController(),
        ));
      }
    } else {
      // Simple test without sub-params
      _resultRows.add(_ResultRow(
        testId: test.id!,
        testName: test.testName,
        normalRange: test.normalRange,
        unit: test.unit,
        resultCtrl: TextEditingController(),
      ));
    }
    setState(() {});
  }

  void _removeTest(int testId) {
    setState(() {
      for (var r in _resultRows.where((r) => r.testId == testId)) {
        r.resultCtrl?.dispose();
      }
      _resultRows.removeWhere((r) => r.testId == testId);
    });
  }

  bool get _hasTest {
    return _resultRows.any((r) => !r.isHeader);
  }

  Set<int> get _addedTestIds => _resultRows.map((r) => r.testId).toSet();

  Future<void> _saveReport() async {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient'), backgroundColor: AppTheme.error),
      );
      return;
    }
    if (!_hasTest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one test'), backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() => _saving = true);

    final inputRows = _resultRows.where((r) => !r.isHeader).toList();
    final allFilled = inputRows.every((r) => (r.resultCtrl?.text.trim() ?? '').isNotEmpty);
    final status = allFilled ? 'completed' : 'pending';

    final reportId = await DBHelper.insertReport({
      'patientId': _selectedPatient!.id,
      'patientName': _selectedPatient!.name,
      'date': DateTime.now().toIso8601String(),
      'status': status,
      'remarks': _remarksCtrl.text.trim(),
      'referredBy': _referredByCtrl.text.trim(),
      'specimen': _specimenCtrl.text.trim(),
    });

    for (var r in inputRows) {
      final resultVal = r.resultCtrl?.text.trim() ?? '';
      await DBHelper.insertTestResult({
        'reportId': reportId,
        'testId': r.testId,
        'testName': r.paramName ?? r.testName,
        'result': resultVal,
        'normalRange': r.normalRange,
        'unit': r.unit,
        'isAbnormal': _isAbnormal(resultVal, r.normalRange) ? 1 : 0,
      });
    }

    if (mounted) Navigator.pop(context, true);
  }

  bool _isAbnormal(String resultStr, String normalRange) {
    if (resultStr.isEmpty || normalRange.isEmpty || normalRange == '-') return false;
    final val = double.tryParse(resultStr);
    if (val == null) return false;

    final rangeParts = normalRange.replaceAll(RegExp(r'[^0-9.\-]'), ' ').trim().split(RegExp(r'\s*-\s*'));
    if (rangeParts.length == 2) {
      final low = double.tryParse(rangeParts[0].trim());
      final high = double.tryParse(rangeParts[1].trim());
      if (low != null && high != null) {
        return val < low || val > high;
      }
    }
    if (normalRange.startsWith('<')) {
      final max = double.tryParse(normalRange.substring(1).replaceAll(RegExp(r'[^0-9.]'), ''));
      if (max != null) return val >= max;
    }
    if (normalRange.startsWith('>')) {
      final min = double.tryParse(normalRange.substring(1).replaceAll(RegExp(r'[^0-9.]'), ''));
      if (min != null) return val <= min;
    }
    return false;
  }

  @override
  void dispose() {
    _referredByCtrl.dispose();
    _remarksCtrl.dispose();
    _specimenCtrl.dispose();
    for (var r in _resultRows) {
      r.resultCtrl?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(title: const Text('Create Report')),
      body: Row(
        children: [
          // Left: Patient & test selection
          SizedBox(
            width: 360,
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Patient', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PatientModel>(
                      value: _selectedPatient,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        hintText: 'Select Patient',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: _patients.map((p) => DropdownMenuItem(
                        value: p,
                        child: Text('${p.name} (${p.age}/${p.gender[0]})'),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedPatient = v),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _referredByCtrl,
                      decoration: const InputDecoration(labelText: 'Referred By', prefixIcon: Icon(Icons.medical_services_outlined)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _specimenCtrl,
                      decoration: const InputDecoration(labelText: 'Specimen', prefixIcon: Icon(Icons.biotech_rounded)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _remarksCtrl,
                      decoration: const InputDecoration(labelText: 'Remarks'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Available Tests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _availableTests.length,
                        itemBuilder: (_, i) {
                          final test = _availableTests[i];
                          final added = _addedTestIds.contains(test.id);
                          final paramCount = _testParams[test.id]?.length ?? 0;
                          return ListTile(
                            dense: true,
                            title: Text(test.testName, style: const TextStyle(fontSize: 13)),
                            subtitle: Text(
                              'Rs. ${test.price.toStringAsFixed(0)}${paramCount > 0 ? ' · $paramCount params' : ''}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: added
                                ? const Icon(Icons.check_circle, color: AppTheme.success, size: 20)
                                : IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor, size: 20),
                                    onPressed: () => _addTest(test),
                                  ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Right: Selected tests with result inputs
          Expanded(
            child: Card(
              margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Test Results (${_resultRows.where((r) => !r.isHeader).length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        ElevatedButton.icon(
                          onPressed: _saving ? null : _saveReport,
                          icon: _saving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save, size: 18),
                          label: const Text('Save Report'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_resultRows.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.science_outlined, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text('Select tests from the left panel', style: TextStyle(color: Colors.grey.shade400)),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: SingleChildScrollView(
                          child: SizedBox(
                            width: double.infinity,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Test / Parameter')),
                                DataColumn(label: Text('Normal Range')),
                                DataColumn(label: Text('Unit')),
                                DataColumn(label: Text('Result')),
                                DataColumn(label: Text('')),
                              ],
                              rows: _resultRows.asMap().entries.map((entry) {
                                final r = entry.value;
                                if (r.isHeader) {
                                  return DataRow(
                                    color: WidgetStateProperty.all(AppTheme.primaryColor.withValues(alpha: 0.05)),
                                    cells: [
                                      DataCell(Row(
                                        children: [
                                          const Icon(Icons.list_alt, size: 16, color: AppTheme.primaryColor),
                                          const SizedBox(width: 6),
                                          Text(r.testName, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                                        ],
                                      )),
                                      const DataCell(Text('')),
                                      const DataCell(Text('')),
                                      const DataCell(Text('')),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error, size: 18),
                                          onPressed: () => _removeTest(r.testId),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return DataRow(cells: [
                                  DataCell(Text(r.testName)),
                                  DataCell(Text(r.normalRange)),
                                  DataCell(Text(r.unit)),
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: TextField(
                                        controller: r.resultCtrl,
                                        decoration: const InputDecoration(
                                          hintText: 'Enter result',
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    r.paramName == null
                                        ? IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error, size: 18),
                                            onPressed: () => _removeTest(r.testId),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ]);
                              }).toList(),
                            ),
                          ),
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
}

class _ResultRow {
  final int testId;
  final String testName;
  final String? paramName;
  final String normalRange;
  final String unit;
  final bool isHeader;
  final TextEditingController? resultCtrl;

  _ResultRow({
    required this.testId,
    required this.testName,
    this.paramName,
    this.normalRange = '',
    this.unit = '',
    this.isHeader = false,
    this.resultCtrl,
  });
}
