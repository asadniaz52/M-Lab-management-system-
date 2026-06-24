import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/invoice_model.dart';
import '../../theme/app_theme.dart';
import '../../services/pdf_invoice_summary_generator.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'create_invoice_screen.dart';
import 'invoice_detail_screen.dart';
import 'edit_invoice_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  List<InvoiceModel> _invoices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    final data = await DBHelper.getAllInvoices();
    setState(() {
      _invoices = data.map((e) => InvoiceModel.fromMap(e)).toList();
      _loading = false;
    });
  }

  Future<void> _deleteInvoice(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text('Are you sure?'),
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
      await DBHelper.deleteInvoice(id);
      _loadInvoices();
    }
  }

  Future<void> _printInvoiceSummary() async {
    final now = DateTime.now();
    DateTime? fromDate = await showDatePicker(
      context: context,
      initialDate: now.subtract(const Duration(days: 30)),
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'Select Start Date',
    );
    if (fromDate == null) return;

    DateTime? toDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: fromDate,
      lastDate: now,
      helpText: 'Select End Date',
    );
    if (toDate == null) return;

    final fromStr = fromDate.toIso8601String().substring(0, 10);
    final toStr = toDate.toIso8601String().substring(0, 10);

    final allInvoices = await DBHelper.getAllInvoices();
    final summaryData = allInvoices.where((inv) {
      final dt = (inv['date'] as String?) ?? '';
      if (dt.isEmpty) return false;
      return dt.compareTo(fromStr) >= 0 && dt.compareTo(toStr + 'T23:59:59') <= 0;
    }).toList();

    final settings = await DBHelper.getLabSettings() ?? {};

    await PdfInvoiceSummaryGenerator.printInvoiceSummaryReport(
      rows: summaryData,
      fromDate: fromStr,
      toDate: toStr,
      labSettings: settings,
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return AppTheme.success;
      case 'partial':
        return AppTheme.warning;
      default:
        return AppTheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    Text('Invoices', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    SizedBox(height: 4),
                    Text('Manage billing and payments', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                  ],
                ),
                Row(
                  children: [
                    if (Provider.of<AuthProvider>(context, listen: false).isAdmin)
                      OutlinedButton.icon(
                        onPressed: _printInvoiceSummary,
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: const Text('Print Summary'),
                      ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
                        );
                        if (result == true) _loadInvoices();
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Invoice'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _invoices.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text('No invoices yet', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
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
                                  DataColumn(label: Text('Total')),
                                  DataColumn(label: Text('Discount')),
                                  DataColumn(label: Text('Paid')),
                                  DataColumn(label: Text('Due')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: _invoices.map((inv) {
                                  return DataRow(cells: [
                                    DataCell(Text('#${inv.id}')),
                                    DataCell(Text(inv.patientName, style: const TextStyle(fontWeight: FontWeight.w500))),
                                    DataCell(Text(inv.date.substring(0, 10))),
                                    DataCell(Text('Rs. ${inv.totalAmount.toStringAsFixed(0)}')),
                                    DataCell(Text('Rs. ${inv.discount.toStringAsFixed(0)}')),
                                    DataCell(Text('Rs. ${inv.paidAmount.toStringAsFixed(0)}')),
                                    DataCell(Text(
                                      'Rs. ${inv.dueAmount.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: inv.dueAmount > 0 ? AppTheme.error : AppTheme.success,
                                      ),
                                    )),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _statusColor(inv.status).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          inv.status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _statusColor(inv.status),
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
                                              MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: inv.id!)),
                                            );
                                            _loadInvoices();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.cardBlue),
                                          tooltip: 'Edit',
                                          onPressed: () async {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => EditInvoiceScreen(invoiceId: inv.id!)),
                                            );
                                            if (result == true) _loadInvoices();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                                          tooltip: 'Delete',
                                          onPressed: () => _deleteInvoice(inv.id!),
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
}
