import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/db_helper.dart';
import '../../models/report_model.dart';
import '../../models/patient_model.dart';
import '../../models/test_result_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/pdf_report_generator.dart';
import '../../theme/app_theme.dart';

class EnterResultsScreen extends StatefulWidget {
  const EnterResultsScreen({super.key});

  @override
  State<EnterResultsScreen> createState() => _EnterResultsScreenState();
}

class _EnterResultsScreenState extends State<EnterResultsScreen> {
  final _receiptCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  
  Map<String, dynamic>? _invoice;
  Map<String, dynamic>? _report;
  List<TestResultModel> _results = [];
  final Map<int, TextEditingController> _resultCtrls = {};
  
  bool _loading = false;
  bool _saving = false;
  bool _printing = false;
  String? _error;
  int? _expandedIndex;

  /// Grouped results by category
  Map<String, List<TestResultModel>> get _grouped {
    final map = <String, List<TestResultModel>>{};
    for (var r in _results) {
      final cat = r.category.isNotEmpty ? r.category : 'General';
      map.putIfAbsent(cat, () => []);
      map[cat]!.add(r);
    }
    return Map.fromEntries(map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  Future<void> _lookupReceipt() async {
    final id = int.tryParse(_receiptCtrl.text.trim());
    if (id == null) {
      setState(() => _error = 'Please enter a valid receipt number');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _invoice = null;
      _report = null;
      _results = [];
      _resultCtrls.clear();
      _remarksCtrl.clear();
    });

    final invoice = await DBHelper.getInvoiceById(id);
    if (invoice == null) {
      setState(() {
        _loading = false;
        _error = 'Receipt #$id not found';
      });
      return;
    }

    Map<String, dynamic>? report;
    if (invoice['reportId'] != null && (invoice['reportId'] as int) > 0) {
      report = await DBHelper.getReportById(invoice['reportId'] as int);
    }

    if (report == null) {
      setState(() {
        _loading = false;
        _error = 'No report linked to receipt #$id. Please create a report first from invoices.';
        _invoice = invoice;
      });
      return;
    }

    final resultsData = await DBHelper.getTestResults(report['id'] as int);
    final results = resultsData.map((e) => TestResultModel.fromMap(e)).toList();

    for (var r in results) {
      _resultCtrls[r.id!] = TextEditingController(text: r.result);
    }

    setState(() {
      _invoice = invoice;
      _report = report;
      _results = results;
      _remarksCtrl.text = report?['remarks'] ?? '';
      _expandedIndex = null;
      _loading = false;
    });
  }

  Future<void> _saveResults() async {
    if (_report == null) return;
    setState(() => _saving = true);

    // Read auth before async gap
    final auth = context.read<AuthProvider>();
    final verifierName = auth.currentUser?.fullName ?? 'Unknown';

    bool allFilled = true;
    for (var r in _results) {
      final val = _resultCtrls[r.id]?.text.trim() ?? '';
      final isAbn = _isAbnormal(val, r.normalRange);
      await DBHelper.updateTestResult(r.id!, {
        'result': val,
        'isAbnormal': isAbn ? 1 : 0,
        'printPage': 0,
      });
      if (val.isEmpty) allFilled = false;
    }

    // Refresh results list so PDF generator picks up new printPage values immediately
    final updatedResultsData = await DBHelper.getTestResults(_report!['id'] as int);
    _results = updatedResultsData.map((e) => TestResultModel.fromMap(e)).toList();

    await DBHelper.updateReport(_report!['id'] as int, {
      'status': allFilled ? 'completed' : 'pending',
      'remarks': _remarksCtrl.text.trim(),
    });

    // Auto-verify: the person who enters results is the verifier
    final isAlreadyVerified = (_report!['verifiedBy'] as String? ?? '').isNotEmpty;
    if (!isAlreadyVerified && allFilled) {
      await DBHelper.verifyReport(_report!['id'] as int, verifierName);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(allFilled ? 'Results saved & verified — Report completed!' : 'Results saved — Some pending'),
          backgroundColor: allFilled ? AppTheme.success : AppTheme.warning,
        ),
      );
      _lookupReceipt();
    }
    setState(() => _saving = false);
  }

  Future<void> _printReport() async {
    if (_report == null) return;
    await _saveResults(); // Save immediately before printing
    setState(() => _printing = true);

    try {
      final labSettings = await DBHelper.getLabSettings();
      if (labSettings == null) return;

      final reportModel = ReportModel.fromMap(_report!, _results);
      PatientModel? patient;
      if (_report!['patientId'] != null) {
        final pMap = await DBHelper.getPatientById(_report!['patientId']);
        if (pMap != null) patient = PatientModel.fromMap(pMap);
      }

      final prevReportMaps = await DBHelper.getPreviousReports(
        reportModel.patientId,
        reportModel.id ?? 0,
        limit: 3,
      );

      final List<PreviousReportData> previousReports = [];
      for (var prevMap in prevReportMaps) {
        final prevResultsData = await DBHelper.getTestResults(prevMap['id'] as int);
        final resultsByName = <String, String>{};
        for (var r in prevResultsData) {
          final name = r['testName'] as String? ?? '';
          final val = r['result'] as String? ?? '';
          if (name.isNotEmpty && val.isNotEmpty) {
            resultsByName[name] = val;
          }
        }
        previousReports.add(PreviousReportData(
          date: prevMap['date'] as String? ?? '',
          resultsByTestName: resultsByName,
        ));
      }

      await PdfReportGenerator.printReport(
        report: reportModel,
        results: _results,
        labSettings: labSettings,
        includeHeaderFooter: true,
        previousReports: previousReports,
        patient: patient,
        invoice: _invoice,
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  bool _isAbnormal(String resultStr, String normalRange) {
    if (resultStr.isEmpty || normalRange.isEmpty || normalRange == '-') return false;
    
    final resLower = resultStr.trim().toLowerCase();
    if (resLower == 'positive') return true;
    if (resLower == 'negative') return false;

    final val = double.tryParse(resultStr);
    if (val == null) return false;
    final rangeParts = normalRange.replaceAll(RegExp(r'[^0-9.\-]'), ' ').trim().split(RegExp(r'\s*-\s*'));
    if (rangeParts.length == 2) {
      final low = double.tryParse(rangeParts[0].trim());
      final high = double.tryParse(rangeParts[1].trim());
      if (low != null && high != null) return val < low || val > high;
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
    _receiptCtrl.dispose();
    _remarksCtrl.dispose();
    for (var c in _resultCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = (_report?['verifiedBy'] as String? ?? '').isNotEmpty;
    final status = _report?['status'] as String? ?? 'pending';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text('Enter Results', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            const Text('Search by INV number to enter test results and print reports', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 20),

            // Search bar
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _receiptCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Enter INV / Invoice Number',
                          prefixIcon: Icon(Icons.receipt_long_outlined),
                        ),
                        onSubmitted: (_) => _lookupReceipt(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _lookupReceipt,
                      icon: _loading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.search, size: 18),
                      label: const Text('Lookup'),
                    ),
                    if (_report != null) ...[
                      const SizedBox(width: 12),
                      Container(width: 1, height: 32, color: Colors.grey.shade300),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _saving || _printing ? null : _saveResults,
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded, size: 18),
                        label: const Text('Save Results'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cardBlue),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _saving || _printing ? null : _printReport,
                        icon: _printing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.print, size: 18),
                        label: const Text('Save & Print'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_error != null)
              Card(
                color: AppTheme.error.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.error),
                      const SizedBox(width: 12),
                      Text(_error!, style: const TextStyle(color: AppTheme.error)),
                    ],
                  ),
                ),
              ),

            // Patient + report info bar
            if (_report != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        '${_report!['patientName']}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(width: 20),
                      _infoPill('Report #${_report!['id']}', AppTheme.cardBlue),
                      const SizedBox(width: 8),
                      _infoPill('INV-${_invoice!['id']}', AppTheme.cardOrange),
                      const SizedBox(width: 8),
                      _infoPill(
                        status.toUpperCase(),
                        status == 'completed' ? AppTheme.success : AppTheme.warning,
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 8),
                        _infoPill('✓ Verified by ${_report!['verifiedBy']}', AppTheme.cardPurple),
                      ],
                      const Spacer(),
                      Text('${_results.length} tests', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ),

            if (_report != null && _results.isNotEmpty) ...[
              const SizedBox(height: 8),
              // Grouped results by category
              Expanded(
                child: Card(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._grouped.entries.toList().asMap().entries.map((mapEntry) {
                          final index = mapEntry.key;
                          final entry = mapEntry.value;
                          final cat = entry.key;
                          final catResults = entry.value;
                          final isExpanded = _expandedIndex == index;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    setState(() {
                                      _expandedIndex = isExpanded ? null : index;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          cat,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor),
                                        ),
                                        Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: AppTheme.primaryColor),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isExpanded)
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Results table for this category
                                        SizedBox(
                                          width: double.infinity,
                                          child: DataTable(
                                            columnSpacing: 24,
                                            headingRowHeight: 38,
                                            dataRowMinHeight: 48,
                                            dataRowMaxHeight: 56,
                                            columns: const [
                                              DataColumn(label: Text('Test / Parameter')),
                                              DataColumn(label: Text('Normal Range')),
                                              DataColumn(label: Text('Unit')),
                                              DataColumn(label: Text('Result')),
                                              DataColumn(label: Text('Status')),
                                            ],
                                            rows: catResults.map((r) {
                                              final ctrl = _resultCtrls[r.id];
                                              final currentVal = ctrl?.text ?? r.result;
                                              final isAbn = _isAbnormal(currentVal, r.normalRange);
                                              final hasBResult = currentVal.isNotEmpty;
          
                                              return DataRow(
                                                color: WidgetStateProperty.resolveWith<Color?>((states) {
                                                  if (isAbn && hasBResult) return AppTheme.error.withValues(alpha: 0.04);
                                                  return null;
                                                }),
                                                cells: [
                                                  DataCell(Text(r.testName,
                                                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
                                                  DataCell(Text(r.normalRange.isEmpty ? '-' : r.normalRange,
                                                      style: const TextStyle(fontSize: 12))),
                                                  DataCell(Text(r.unit.isEmpty ? '-' : r.unit,
                                                      style: const TextStyle(fontSize: 12))),
                                                  DataCell(
                                                    SizedBox(
                                                      width: 160,
                                                      child: TextField(
                                                        controller: ctrl,
                                                        onChanged: (_) => setState(() {}),
                                                        style: TextStyle(
                                                          color: isAbn && hasBResult ? AppTheme.error : Colors.black,
                                                          fontWeight: isAbn && hasBResult ? FontWeight.bold : FontWeight.normal,
                                                        ),
                                                        decoration: InputDecoration(
                                                          hintText: 'Enter result',
                                                          isDense: true,
                                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                          filled: hasBResult,
                                                          fillColor: hasBResult
                                                              ? (isAbn
                                                                  ? AppTheme.error.withValues(alpha: 0.07)
                                                                  : AppTheme.success.withValues(alpha: 0.06))
                                                              : null,
                                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                                          enabledBorder: OutlineInputBorder(
                                                            borderRadius: BorderRadius.circular(6),
                                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    !hasBResult
                                                        ? Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                            decoration: BoxDecoration(
                                                              color: AppTheme.warning.withValues(alpha: 0.1),
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child: const Text('PENDING',
                                                                style: TextStyle(color: AppTheme.warning, fontSize: 10, fontWeight: FontWeight.w600)),
                                                          )
                                                        : isAbn
                                                            ? Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                                decoration: BoxDecoration(
                                                                  color: AppTheme.error.withValues(alpha: 0.1),
                                                                  borderRadius: BorderRadius.circular(8),
                                                                ),
                                                                child: const Text('ABNORMAL',
                                                                    style: TextStyle(color: AppTheme.error, fontSize: 10, fontWeight: FontWeight.w600)),
                                                              )
                                                            : Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                                decoration: BoxDecoration(
                                                                  color: AppTheme.success.withValues(alpha: 0.1),
                                                                  borderRadius: BorderRadius.circular(8),
                                                                ),
                                                                child: const Text('NORMAL',
                                                                    style: TextStyle(color: AppTheme.success, fontSize: 10, fontWeight: FontWeight.w600)),
                                                              ),
                                                  ),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                        if (index < _grouped.length - 1)
                                          Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  setState(() {
                                                    _expandedIndex = index + 1;
                                                  });
                                                },
                                                icon: const Icon(Icons.arrow_downward, size: 16),
                                                label: const Text('Next Test'),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                        // ── Remarks Section ───────────────────────────────────
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _remarksCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Remarks',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
