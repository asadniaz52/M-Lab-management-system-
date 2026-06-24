import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/test_result_model.dart';
import '../../theme/app_theme.dart';

class EditReportScreen extends StatefulWidget {
  final int reportId;
  const EditReportScreen({super.key, required this.reportId});

  @override
  State<EditReportScreen> createState() => _EditReportScreenState();
}

class _EditReportScreenState extends State<EditReportScreen> {
  Map<String, dynamic>? _report;
  List<_EditableResult> _results = [];
  final _remarksCtrl = TextEditingController();
  final _referredByCtrl = TextEditingController();
  final _specimenCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final report = await DBHelper.getReportById(widget.reportId);
    final resultsData = await DBHelper.getTestResults(widget.reportId);

    setState(() {
      _report = report;
      _remarksCtrl.text = report?['remarks'] ?? '';
      _referredByCtrl.text = report?['referredBy'] ?? '';
      _specimenCtrl.text = report?['specimen'] ?? '';
      _results = resultsData.map((r) {
        final model = TestResultModel.fromMap(r);
        return _EditableResult(
          id: model.id!,
          testName: model.testName,
          normalRange: model.normalRange,
          unit: model.unit,
          resultCtrl: TextEditingController(text: model.result),
        );
      }).toList();
      _loading = false;
    });
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

  Future<void> _saveReport() async {
    setState(() => _saving = true);

    final allFilled = _results.every((r) => r.resultCtrl.text.trim().isNotEmpty);
    final status = allFilled ? 'completed' : 'pending';

    await DBHelper.updateReport(widget.reportId, {
      'status': status,
      'remarks': _remarksCtrl.text.trim(),
      'referredBy': _referredByCtrl.text.trim(),
      'specimen': _specimenCtrl.text.trim(),
    });

    for (var r in _results) {
      final resultVal = r.resultCtrl.text.trim();
      await DBHelper.updateTestResult(r.id, {
        'result': resultVal,
        'isAbnormal': _isAbnormal(resultVal, r.normalRange) ? 1 : 0,
      });
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    _referredByCtrl.dispose();
    _specimenCtrl.dispose();
    for (var r in _results) {
      r.resultCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Edit Report #${widget.reportId}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _saveReport,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 18),
              label: const Text('Save Changes'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient info card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Patient: ${_report?['patientName'] ?? ''}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('Date: ${(_report?['date'] ?? '').toString().substring(0, 10)}',
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 200,
                            child: TextFormField(
                              controller: _referredByCtrl,
                              decoration: const InputDecoration(labelText: 'Referred By', isDense: true),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 150,
                            child: TextFormField(
                              controller: _specimenCtrl,
                              decoration: const InputDecoration(labelText: 'Specimen', isDense: true),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Test results
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Test Results', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Test Name')),
                                DataColumn(label: Text('Normal Range')),
                                DataColumn(label: Text('Unit')),
                                DataColumn(label: Text('Result')),
                              ],
                              rows: _results.map((r) {
                                return DataRow(cells: [
                                  DataCell(Text(r.testName, style: const TextStyle(fontWeight: FontWeight.w500))),
                                  DataCell(Text(r.normalRange)),
                                  DataCell(Text(r.unit)),
                                  DataCell(
                                    SizedBox(
                                      width: 140,
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
                                ]);
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Remarks
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: TextFormField(
                        controller: _remarksCtrl,
                        decoration: const InputDecoration(labelText: 'Remarks'),
                        maxLines: 3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _EditableResult {
  final int id;
  final String testName;
  final String normalRange;
  final String unit;
  final TextEditingController resultCtrl;

  _EditableResult({
    required this.id,
    required this.testName,
    required this.normalRange,
    required this.unit,
    required this.resultCtrl,
  });
}
