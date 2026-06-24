import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/patient_model.dart';
import '../../theme/app_theme.dart';
import '../reports/report_detail_screen.dart';
import '../invoices/invoice_detail_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  final PatientModel patient;
  const PatientProfileScreen({super.key, required this.patient});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _invoices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final reports = await DBHelper.getReportsByPatientId(widget.patient.id!);
    final invoices = await DBHelper.getInvoicesByPatientId(widget.patient.id!);
    setState(() {
      _reports = reports;
      _invoices = invoices;
      _loading = false;
    });
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '-';
    return isoDate.length >= 10 ? isoDate.substring(0, 10) : isoDate;
  }

  Color _invoiceStatusColor(String status) {
    switch (status) {
      case 'paid': return AppTheme.success;
      case 'partial': return AppTheme.warning;
      default: return AppTheme.error;
    }
  }

  Color _reportStatusColor(String status) {
    return status == 'completed' ? AppTheme.success : AppTheme.warning;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    final totalPaid = _invoices.fold<double>(0, (sum, inv) => sum + ((inv['paidAmount'] as num?)?.toDouble() ?? 0));
    final totalDue = _invoices.fold<double>(0, (sum, inv) {
      final net = ((inv['totalAmount'] as num?)?.toDouble() ?? 0) - ((inv['discount'] as num?)?.toDouble() ?? 0);
      final paid = (inv['paidAmount'] as num?)?.toDouble() ?? 0;
      return sum + (net - paid).clamp(0.0, double.infinity);
    });

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Patient: ${p.name}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(
                totalDue > 0 ? 'Due: Rs. ${totalDue.toStringAsFixed(0)}' : 'Fully Paid',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: totalDue > 0 ? AppTheme.error : AppTheme.success,
                ),
              ),
              backgroundColor: totalDue > 0
                  ? AppTheme.error.withValues(alpha: 0.1)
                  : AppTheme.success.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient info card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                                child: Text(
                                  p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P',
                                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                    const SizedBox(height: 4),
                                    Text('${p.age} years  •  ${p.gender}  •  ${p.phone.isNotEmpty ? p.phone : "No phone"}',
                                        style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                                    if (p.nic.isNotEmpty)
                                      Text('NIC: ${p.nic}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                                    if (p.address.isNotEmpty)
                                      Text('Address: ${p.address}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _statChip('${_reports.length} Reports', AppTheme.cardBlue),
                                  const SizedBox(height: 8),
                                  _statChip('${_invoices.length} Invoices', AppTheme.cardPurple),
                                  const SizedBox(height: 8),
                                  _statChip('Rs. ${totalPaid.toStringAsFixed(0)} Paid', AppTheme.success),
                                ],
                              ),
                            ],
                          ),
                          // Confidential notice
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.cardOrange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.cardOrange.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock_outline_rounded, size: 16, color: AppTheme.cardOrange),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'All reports & results in this profile are strictly private and confidential. Sharing without patient consent is prohibited.',
                                    style: TextStyle(fontSize: 12, color: AppTheme.cardOrange, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Reports history
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reports column
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.assignment_rounded, color: AppTheme.cardBlue, size: 20),
                                    SizedBox(width: 8),
                                    Text('Visit Reports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_reports.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Center(child: Text('No reports found', style: TextStyle(color: AppTheme.textSecondary))),
                                  )
                                else
                                  ..._reports.map((r) {
                                    final status = r['status'] as String? ?? 'pending';
                                    final verifiedBy = r['verifiedBy'] as String? ?? '';
                                    return InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => ReportDetailScreen(reportId: r['id'] as int)),
                                      ).then((_) => _loadData()),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: _reportStatusColor(status).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(Icons.science_rounded, size: 18, color: _reportStatusColor(status)),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Report #${r['id']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                                  Text(_formatDate(r['date']), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                _statusBadge(status.toUpperCase(), _reportStatusColor(status)),
                                                if (verifiedBy.isNotEmpty)
                                                  const SizedBox(height: 4),
                                                if (verifiedBy.isNotEmpty)
                                                  _statusBadge('✓ Verified', AppTheme.cardPurple),
                                              ],
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 18),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Invoices column
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.receipt_long_rounded, color: AppTheme.cardPurple, size: 20),
                                    SizedBox(width: 8),
                                    Text('Payment History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_invoices.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Center(child: Text('No invoices found', style: TextStyle(color: AppTheme.textSecondary))),
                                  )
                                else
                                  ..._invoices.map((inv) {
                                    final status = inv['status'] as String? ?? 'unpaid';
                                    final total = (inv['totalAmount'] as num?)?.toDouble() ?? 0;
                                    final discount = (inv['discount'] as num?)?.toDouble() ?? 0;
                                    final paid = (inv['paidAmount'] as num?)?.toDouble() ?? 0;
                                    final net = total - discount;
                                    final due = (net - paid).clamp(0.0, double.infinity);
                                    return InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: inv['id'] as int)),
                                      ).then((_) => _loadData()),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: _invoiceStatusColor(status).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(Icons.receipt_rounded, size: 18, color: _invoiceStatusColor(status)),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('INV-${inv['id']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                                  Text(_formatDate(inv['date']), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text('Rs. ${net.toStringAsFixed(0)}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                if (due > 0)
                                                  Text('Due: Rs. ${due.toStringAsFixed(0)}',
                                                      style: const TextStyle(fontSize: 11, color: AppTheme.error)),
                                              ],
                                            ),
                                            const SizedBox(width: 8),
                                            _statusBadge(status.toUpperCase(), _invoiceStatusColor(status)),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 18),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
