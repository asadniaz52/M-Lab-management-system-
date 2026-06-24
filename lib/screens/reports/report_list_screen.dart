import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/report_model.dart';
import '../../theme/app_theme.dart';
import 'create_report_screen.dart';
import 'report_detail_screen.dart';
import 'edit_report_screen.dart';
import '../../services/pdf_summary_generator.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ReportListScreen extends StatefulWidget {
  const ReportListScreen({super.key});

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  List<ReportModel> _reports = [];
  String _statusFilter = 'all';
  String _searchQuery = '';
  bool _loading = true;

  Future<void> _printInvestigationsReport() async {
    final DateTimeRange? dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (dateRange == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            SizedBox(width: 16),
            Text('Generating summary report PDF...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    final fromStr = dateRange.start.toIso8601String().substring(0, 10);
    final toStr = dateRange.end.toIso8601String().substring(0, 10);

    final rows = await DBHelper.getInvestigationsReport(fromStr, toStr);
    final settings = await DBHelper.getLabSettings() ?? {};

    if (rows.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No investigations found in the selected date range.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    await PdfSummaryGenerator.printSummaryReport(
      rows: rows,
      fromDate: fromStr,
      toDate: toStr,
      labSettings: settings,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    List<Map<String, dynamic>> data;
    if (_statusFilter == 'all') {
      data = await DBHelper.getAllReports();
    } else {
      data = await DBHelper.getReportsByStatus(_statusFilter);
    }
    setState(() {
      _reports = data.map((e) => ReportModel.fromMap(e)).toList();
      _loading = false;
    });
  }

  Future<void> _deleteReport(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Delete this report and all its test results?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DBHelper.deleteReport(id);
      _loadReports();
    }
  }

  List<ReportModel> get _filteredReports {
    if (_searchQuery.isEmpty) return _reports;
    final q = _searchQuery.toLowerCase();
    return _reports.where((r) =>
        r.patientName.toLowerCase().contains(q) ||
        r.id.toString() == q ||
        (r.referredBy != null && r.referredBy!.toLowerCase().contains(q))
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredReports;
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Investigations', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    SizedBox(height: 4),
                    Text('Lab test investigations and reports', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                  ],
                ),
                Row(
                  children: [
                    if (Provider.of<AuthProvider>(context, listen: false).isAdmin)
                      OutlinedButton.icon(
                        onPressed: _printInvestigationsReport,
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: const Text('Print Summary'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Filter and Search
            Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Pending', 'pending'),
                const SizedBox(width: 8),
                _buildFilterChip('Completed', 'completed'),
                const Spacer(),
                SizedBox(
                  width: 300,
                  height: 40,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search by ID, Name or Doctor',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Card(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text('No reports found', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: SizedBox(
                              width: double.infinity,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('ID')),
                                  DataColumn(label: Text('Patient')),
                                  DataColumn(label: Text('Date')),
                                  DataColumn(label: Text('Referred By')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: filtered.map((r) {
                                  return DataRow(cells: [
                                    DataCell(Text('#${r.id}')),
                                    DataCell(Text(r.patientName, style: const TextStyle(fontWeight: FontWeight.w500))),
                                    DataCell(Text(r.date.substring(0, 10))),
                                    DataCell(Text(r.referredBy ?? '-')),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: r.status == 'completed'
                                              ? AppTheme.success.withValues(alpha: 0.1)
                                              : AppTheme.warning.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          r.status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: r.status == 'completed' ? AppTheme.success : AppTheme.warning,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility_outlined, size: 18, color: AppTheme.primaryColor),
                                          tooltip: 'View',
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => ReportDetailScreen(reportId: r.id!)),
                                            );
                                            _loadReports();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.cardBlue),
                                          tooltip: 'Edit',
                                          onPressed: () async {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => EditReportScreen(reportId: r.id!)),
                                            );
                                            if (result == true) _loadReports();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                                          tooltip: 'Delete',
                                          onPressed: () => _deleteReport(r.id!),
                                        ),
                                      ],
                                    )),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (_) {
        setState(() {
          _statusFilter = value;
          _loading = true;
          _searchQuery = ''; // Reset search on filter change
        });
        _loadReports();
      },
    );
  }
}
