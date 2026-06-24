import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../theme/app_theme.dart';
import '../../services/pdf_price_list_generator.dart';

class PriceListScreen extends StatefulWidget {
  const PriceListScreen({super.key});

  @override
  State<PriceListScreen> createState() => _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen> {
  List<Map<String, dynamic>> _tests = [];
  Map<String, List<Map<String, dynamic>>> _grouped = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  Future<void> _loadTests() async {
    final tests = await DBHelper.getAllTests();
    final groups = <String, List<Map<String, dynamic>>>{};
    for (var t in tests) {
      final cat = t['category'] ?? 'General';
      groups.putIfAbsent(cat, () => []);
      groups[cat]!.add(t);
    }
    setState(() {
      _tests = tests;
      _grouped = groups;
      _loading = false;
    });
  }

  Future<void> _printPriceList() async {
    final labSettings = await DBHelper.getLabSettings();
    if (labSettings == null) return;
    await PdfPriceListGenerator.printPriceList(tests: _tests, labSettings: labSettings);
  }

  @override
  Widget build(BuildContext context) {
    final sortedCats = _grouped.keys.toList()..sort();

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Price List', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text('All available tests grouped by category', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _printPriceList,
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('Print Price List'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: sortedCats.length,
                      itemBuilder: (_, i) {
                        final cat = sortedCats[i];
                        final catTests = _grouped[cat]!;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(cat, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: DataTable(
                                    columnSpacing: 24,
                                    headingRowHeight: 36,
                                    dataRowMinHeight: 36,
                                    dataRowMaxHeight: 44,
                                    columns: const [
                                      DataColumn(label: Text('#')),
                                      DataColumn(label: Text('Test Name')),
                                      DataColumn(label: Text('Price (Rs.)')),
                                    ],
                                    rows: catTests.asMap().entries.map((entry) {
                                      return DataRow(cells: [
                                        DataCell(Text('${entry.key + 1}')),
                                        DataCell(Text(entry.value['testName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                                        DataCell(Text('Rs. ${(entry.value['price'] as num).toStringAsFixed(0)}',
                                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryColor))),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
