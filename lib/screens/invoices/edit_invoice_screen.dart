import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../theme/app_theme.dart';

class EditInvoiceScreen extends StatefulWidget {
  final int invoiceId;
  const EditInvoiceScreen({super.key, required this.invoiceId});

  @override
  State<EditInvoiceScreen> createState() => _EditInvoiceScreenState();
}

class _EditInvoiceScreenState extends State<EditInvoiceScreen> {
  Map<String, dynamic>? _invoice;
  List<Map<String, dynamic>> _items = [];
  final _discountCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  double get _total => _items.fold(0, (sum, item) => sum + ((item['price'] as num?)?.toDouble() ?? 0));
  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _net => _total - _discount;
  double get _paid => double.tryParse(_paidCtrl.text) ?? 0;
  double get _due => _net - _paid;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final inv = await DBHelper.getInvoiceById(widget.invoiceId);
    final items = await DBHelper.getInvoiceItems(widget.invoiceId);

    setState(() {
      _invoice = inv;
      _items = items;
      _discountCtrl.text = (inv?['discount'] ?? 0).toString();
      _paidCtrl.text = (inv?['paidAmount'] ?? 0).toString();
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    String status;
    if (_paid >= _net) {
      status = 'paid';
    } else if (_paid > 0) {
      status = 'partial';
    } else {
      status = 'unpaid';
    }

    await DBHelper.updateInvoice(widget.invoiceId, {
      'discount': _discount,
      'paidAmount': _paid,
      'totalAmount': _total,
      'status': status,
    });

    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Edit Invoice #${widget.invoiceId}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
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
              padding: const EdgeInsets.all(28),
              child: Center(
                child: SizedBox(
                  width: 700,
                  child: Column(
                    children: [
                      // Patient info
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline, color: AppTheme.textSecondary),
                              const SizedBox(width: 12),
                              Text(
                                'Patient: ${_invoice?['patientName'] ?? ''}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              Text(
                                'Date: ${(_invoice?['date'] ?? '').toString().substring(0, 10)}',
                                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Items (read-only)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Invoice Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('#')),
                                    DataColumn(label: Text('Item')),
                                    DataColumn(label: Text('Price')),
                                  ],
                                  rows: _items.asMap().entries.map((entry) {
                                    return DataRow(cells: [
                                      DataCell(Text('${entry.key + 1}')),
                                      DataCell(Text(entry.value['testName'] ?? '')),
                                      DataCell(Text('Rs. ${((entry.value['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}')),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Payment section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Payment Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 16),
                              _summaryRow('Subtotal', 'Rs. ${_total.toStringAsFixed(0)}'),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Text('Discount: ', style: TextStyle(fontSize: 14)),
                                  SizedBox(
                                    width: 120,
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
                              const SizedBox(height: 12),
                              _summaryRow('Net Total', 'Rs. ${_net.toStringAsFixed(0)}', bold: true),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Text('Paid Amount: ', style: TextStyle(fontSize: 14)),
                                  SizedBox(
                                    width: 120,
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
                              const SizedBox(height: 12),
                              _summaryRow('Due Amount', 'Rs. ${_due.toStringAsFixed(0)}',
                                  bold: true, color: _due > 0 ? AppTheme.error : AppTheme.success),
                            ],
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
