import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/invoice_model.dart';
import '../../theme/app_theme.dart';
import '../../services/pdf_invoice_generator.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final int invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  InvoiceModel? _invoice;
  List<InvoiceItemModel> _items = [];
  Map<String, dynamic>? _labSettings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final inv = await DBHelper.getInvoiceById(widget.invoiceId);
    final items = await DBHelper.getInvoiceItems(widget.invoiceId);
    final labSettings = await DBHelper.getLabSettings();

    setState(() {
      _invoice = inv != null ? InvoiceModel.fromMap(inv, items.map((e) => InvoiceItemModel.fromMap(e)).toList()) : null;
      _items = items.map((e) => InvoiceItemModel.fromMap(e)).toList();
      _labSettings = labSettings;
      _loading = false;
    });
  }

  Future<void> _printInvoice() async {
    if (_invoice == null || _labSettings == null) return;
    await PdfInvoiceGenerator.printInvoice(
      invoice: _invoice!,
      items: _items,
      labSettings: _labSettings!,
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
      appBar: AppBar(
        title: Text('Invoice #${widget.invoiceId}'),
        actions: [
          if (_invoice != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: _printInvoice,
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Print Invoice'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cardBlue),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invoice == null
              ? const Center(child: Text('Invoice not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: Container(
                      width: 700,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          // Header
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.05),
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_labSettings?['labName'] ?? 'Umar Medical Laboratory',
                                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
                                      Text(_labSettings?['address'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('INVOICE #${_invoice!.id}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(_invoice!.status).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(_invoice!.status.toUpperCase(),
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(_invoice!.status))),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          // Patient + date info
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              children: [
                                Expanded(child: _infoRow('Patient', _invoice!.patientName)),
                                Expanded(child: _infoRow('Date', _invoice!.date.substring(0, 10))),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          // Items Table
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: SizedBox(
                              width: double.infinity,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                                columns: const [
                                  DataColumn(label: Text('#')),
                                  DataColumn(label: Text('Test / Item')),
                                  DataColumn(label: Text('Price (Rs.)')),
                                ],
                                rows: _items.asMap().entries.map((entry) {
                                  return DataRow(cells: [
                                    DataCell(Text('${entry.key + 1}')),
                                    DataCell(Text(entry.value.testName, style: const TextStyle(fontWeight: FontWeight.w500))),
                                    DataCell(Text('Rs. ${entry.value.price.toStringAsFixed(0)}')),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          // Totals
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                width: 280,
                                child: Column(
                                  children: [
                                    _totalRow('Subtotal', 'Rs. ${_invoice!.totalAmount.toStringAsFixed(0)}'),
                                    const SizedBox(height: 6),
                                    _totalRow('Discount', 'Rs. ${_invoice!.discount.toStringAsFixed(0)}'),
                                    const Divider(),
                                    _totalRow('Net Total', 'Rs. ${_invoice!.netAmount.toStringAsFixed(0)}', bold: true),
                                    const SizedBox(height: 6),
                                    _totalRow('Paid', 'Rs. ${_invoice!.paidAmount.toStringAsFixed(0)}'),
                                    const SizedBox(height: 6),
                                    _totalRow('Due', 'Rs. ${_invoice!.dueAmount.toStringAsFixed(0)}',
                                        bold: true, color: _invoice!.dueAmount > 0 ? AppTheme.error : AppTheme.success),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
      ],
    );
  }
}
