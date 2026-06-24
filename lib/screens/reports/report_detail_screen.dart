import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../database/db_helper.dart';
import '../../models/report_model.dart';
import '../../models/test_result_model.dart';
import '../../models/patient_model.dart';
import '../../theme/app_theme.dart';
import '../../services/pdf_report_generator.dart';

// â”€â”€ Colour tokens for this screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const _kPrimary   = Color(0xFF1C43B0); // deep indigo
const _kAccent    = Color(0xFF0099CC); // cyan-blue
const _kSuccess   = Color(0xFF16A34A);
const _kWarning   = Color(0xFFD97706);
const _kError     = Color(0xFFDC2626);
const _kBgLight   = Color(0xFFF0F4FF); // very pale blue tint
const _kBorder    = Color(0xFFCBD5E0);

class ReportDetailScreen extends StatefulWidget {
  final int reportId;
  const ReportDetailScreen({super.key, required this.reportId});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  ReportModel? _report;
  List<TestResultModel> _results = [];
  Map<String, dynamic>? _labSettings;
  Map<String, dynamic>? _linkedInvoice;
  PatientModel? _patient;
  bool _loading = true;
  bool _printing = false;

  // Focus node so keyboard shortcuts are captured
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final reportMap = await DBHelper.getReportById(widget.reportId);
    if (reportMap == null) return;
    final resultsData  = await DBHelper.getTestResults(widget.reportId);
    final labSettings  = await DBHelper.getLabSettings();
    final results      = resultsData.map((e) => TestResultModel.fromMap(e)).toList();
    final linkedInvoice = await DBHelper.getInvoiceByReportId(widget.reportId);
    PatientModel? patient;
    if (reportMap['patientId'] != null) {
      final pMap = await DBHelper.getPatientById(reportMap['patientId']);
      if (pMap != null) patient = PatientModel.fromMap(pMap);
    }

    setState(() {
      _report       = ReportModel.fromMap(reportMap, results);
      _results      = results;
      _labSettings  = labSettings;
      _linkedInvoice = linkedInvoice;
      _patient      = patient;
      _loading      = false;
    });
  }

  Future<void> _markCompleted() async {
    await DBHelper.updateReport(widget.reportId, {'status': 'completed'});
    _loadData();
  }

  Future<List<PreviousReportData>> _fetchPreviousReports() async {
    if (_report == null) return [];
    final prevReportMaps = await DBHelper.getPreviousReports(
      _report!.patientId,
      _report!.id!,
      limit: 3,
    );

    final List<PreviousReportData> previousReports = [];
    for (var prevMap in prevReportMaps) {
      final prevResultsData = await DBHelper.getTestResults(prevMap['id'] as int);
      final resultsByName = <String, String>{};
      for (var r in prevResultsData) {
        final name = r['testName'] as String? ?? '';
        final val  = r['result']   as String? ?? '';
        if (name.isNotEmpty && val.isNotEmpty) {
          resultsByName[name] = val;
        }
      }
      previousReports.add(PreviousReportData(
        date: prevMap['date'] as String? ?? '',
        resultsByTestName: resultsByName,
      ));
    }
    return previousReports;
  }

  Future<void> _printReport(bool includeHeaderFooter) async {
    if (_report == null || _labSettings == null || _printing) return;
    setState(() => _printing = true);
    try {
      final previousReports = await _fetchPreviousReports();
      await PdfReportGenerator.printReport(
        report: _report!,
        results: _results,
        labSettings: _labSettings!,
        includeHeaderFooter: includeHeaderFooter,
        previousReports: previousReports,
        patient: _patient,
        invoice: _linkedInvoice,
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  // Ctrl+P â†’ print with header+footer (full report)
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyP &&
        HardwareKeyboard.instance.isControlPressed) {
      _printReport(true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          title: Text('Report #${widget.reportId}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          actions: [
            if (_report != null && !_loading) ...[
              // â”€â”€ Report Only (no header/footer) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Tooltip(
                  message: 'Print without header & footer',
                  child: OutlinedButton.icon(
                    onPressed: _printing ? null : () => _printReport(false),
                    icon: _printing
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
                        : const Icon(Icons.article_outlined, size: 17, color: Colors.white70),
                    label: const Text('Report Only',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                ),
              ),
              // â”€â”€ Full Print (Ctrl+P) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Tooltip(
                  message: 'Print with header & footer  (Ctrl+P)',
                  child: ElevatedButton.icon(
                    onPressed: _printing ? null : () => _printReport(true),
                    icon: _printing
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.print, size: 17),
                    label: const Text('Print', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: Container(
                    width: 800,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder),
                      boxShadow: [
                        BoxShadow(
                          color: _kPrimary.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // â”€â”€ Report Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _kPrimary.withValues(alpha: 0.08),
                                _kAccent.withValues(alpha: 0.04),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft:  Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [_kPrimary, _kAccent],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.biotech_rounded, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _labSettings?['labName'] ?? 'Umar Medical Laboratory',
                                      style: const TextStyle(
                                          fontSize: 22, fontWeight: FontWeight.bold, color: _kPrimary),
                                    ),
                                    Text(
                                      _labSettings?['address'] ?? 'Bannu',
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              // Status badges
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Report #${_report!.id}',
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.bold, color: _kPrimary)),
                                  if (_linkedInvoice != null) ...[
                                    const SizedBox(height: 2),
                                    Text('Receipt INV-${_linkedInvoice!['id']}',
                                        style: const TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.w600, color: _kAccent)),
                                  ],
                                  const SizedBox(height: 6),
                                  _statusBadge(_report!.status),
                                  if ((_report?.verifiedBy ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    _verifiedBadge(),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: _kBorder),

                        // â”€â”€ Patient Info â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            children: [
                              Expanded(child: _infoRow('Patient Name', _report!.patientName)),
                              Expanded(
                                child: _infoRow(
                                  'Date',
                                  _report!.date.length >= 10
                                      ? _report!.date.substring(0, 10)
                                      : _report!.date,
                                ),
                              ),
                              Expanded(child: _infoRow('Referred By', _report!.referredBy ?? '-')),
                            ],
                          ),
                        ),
                        if ((_report?.verifiedBy ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.verified_user, size: 20, color: _kPrimary),
                                  const SizedBox(width: 12),
                                  Text('Verified by: ',
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                  Text(_report!.verifiedBy!,
                                      style: const TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w600, color: _kPrimary)),
                                  const SizedBox(width: 16),
                                  Text('Time: ',
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                  Text(
                                    _report!.verifiedAt != null &&
                                            _report!.verifiedAt!.length >= 16
                                        ? _report!.verifiedAt!
                                            .substring(0, 16)
                                            .replaceAll('T', ' ')
                                        : _report!.verifiedAt ?? '',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const Divider(height: 1, color: _kBorder),

                        // â”€â”€ Test Results â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: _kAccent,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text('Test Results',
                                      style: TextStyle(
                                          fontSize: 18, fontWeight: FontWeight.w600, color: _kPrimary)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: DataTable(
                                  headingRowColor:
                                      WidgetStateProperty.all(_kPrimary.withValues(alpha: 0.08)),
                                  headingTextStyle: const TextStyle(
                                      fontWeight: FontWeight.w700, color: _kPrimary),
                                  dataRowColor: WidgetStateProperty.resolveWith(
                                    (states) => Colors.transparent,
                                  ),
                                  dividerThickness: 0.8,
                                  columns: const [
                                    DataColumn(label: Text('Test Name')),
                                    DataColumn(label: Text('Result')),
                                    DataColumn(label: Text('Normal Range')),
                                    DataColumn(label: Text('Unit')),
                                  ],
                                  rows: _results.asMap().entries.map((entry) {
                                    final i = entry.key;
                                    final r = entry.value;
                                    final isAlt = i.isOdd;
                                    return DataRow(
                                      color: WidgetStateProperty.all(
                                        isAlt ? _kBgLight : Colors.white,
                                      ),
                                      cells: [
                                        DataCell(Text(r.testName,
                                            style: const TextStyle(fontWeight: FontWeight.w500))),
                                        DataCell(Text(
                                          r.result.isEmpty ? '-' : r.result,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: r.isAbnormal ? _kError : Colors.black,
                                          ),
                                        )),
                                        DataCell(Text(r.normalRange)),
                                        DataCell(Text(r.unit)),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // â”€â”€ Remarks â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                        if ((_report!.remarks ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _kBgLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _kBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Remarks',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: _kPrimary)),
                                  const SizedBox(height: 4),
                                  Text(_report!.remarks!,
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                                ],
                              ),
                            ),
                          ),

                        // â”€â”€ Footer â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _kPrimary.withValues(alpha: 0.04),
                            borderRadius: const BorderRadius.only(
                              bottomLeft:  Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                            border: Border(
                                top: BorderSide(color: _kBorder, width: 1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if ((_labSettings?['address'] ?? '').isNotEmpty)
                                Text('Address: ${_labSettings!['address']}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if ((_labSettings?['doctorName'] ?? '').isNotEmpty)
                                    Text('Doctor: ${_labSettings!['doctorName']}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  if ((_labSettings?['ceoName'] ?? '').isNotEmpty)
                                    Text('CEO: ${_labSettings!['ceoName']}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  if ((_labSettings?['inchargeName'] ?? '').isNotEmpty)
                                    Text('Incharge: ${_labSettings!['inchargeName']}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final isCompleted = status == 'completed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: (isCompleted ? _kSuccess : _kWarning).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isCompleted ? _kSuccess : _kWarning,
        ),
      ),
    );
  }

  Widget _verifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _kPrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 14, color: _kPrimary),
          SizedBox(width: 4),
          Text('Verified',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _kPrimary)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w500, color: _kPrimary)),
      ],
    );
  }
}
