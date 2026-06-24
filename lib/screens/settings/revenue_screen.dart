import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../theme/app_theme.dart';

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  double _todayRevenue = 0;
  double _monthRevenue = 0;
  double _totalRevenue = 0;
  List<Map<String, dynamic>> _revenueByDate = [];
  List<Map<String, dynamic>> _topTests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final today = await DBHelper.getTodayRevenue();
    final month = await DBHelper.getMonthRevenue();
    final total = await DBHelper.getTotalRevenue();
    final byDate = await DBHelper.getRevenueByDate(14);
    final topTests = await DBHelper.getTopTests(8);

    setState(() {
      _todayRevenue = today;
      _monthRevenue = month;
      _totalRevenue = total;
      _revenueByDate = byDate;
      _topTests = topTests;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Revenue', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                            SizedBox(height: 4),
                            Text('Financial overview — Admin only', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Stat cards
                    Row(
                      children: [
                        _statCard("Today's Earnings", 'Rs. ${_todayRevenue.toStringAsFixed(0)}',
                            Icons.today_rounded, AppTheme.cardGreen),
                        const SizedBox(width: 20),
                        _statCard('This Month', 'Rs. ${_monthRevenue.toStringAsFixed(0)}',
                            Icons.calendar_month_rounded, AppTheme.cardBlue),
                        const SizedBox(width: 20),
                        _statCard('Total Revenue', 'Rs. ${_totalRevenue.toStringAsFixed(0)}',
                            Icons.account_balance_wallet_rounded, AppTheme.cardPurple),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Revenue by date (bar chart)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.bar_chart_rounded, color: AppTheme.cardBlue, size: 22),
                                SizedBox(width: 8),
                                Text('Revenue — Last 14 Days',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (_revenueByDate.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(40),
                                child: Center(child: Text('No revenue data yet', style: TextStyle(color: AppTheme.textSecondary))),
                              )
                            else
                              SizedBox(
                                height: 220,
                                child: _RevenueBarChart(data: _revenueByDate),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Top tests + recent invoices
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top tests
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.science_rounded, color: AppTheme.cardOrange, size: 22),
                                      SizedBox(width: 8),
                                      Text('Top Tests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  if (_topTests.isEmpty)
                                    const Center(child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Text('No test data yet', style: TextStyle(color: AppTheme.textSecondary)),
                                    ))
                                  else
                                    ...(_topTests.asMap().entries.map((entry) {
                                      final i = entry.key;
                                      final t = entry.value;
                                      final maxCount = (_topTests.first['count'] as int?) ?? 1;
                                      final count = (t['count'] as int?) ?? 0;
                                      final rev = (t['revenue'] as num?)?.toDouble() ?? 0;
                                      final ratio = maxCount > 0 ? count / maxCount : 0.0;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 24,
                                                  height: 24,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    color: i < 3 ? AppTheme.cardOrange.withValues(alpha: 0.15) : Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text('${i + 1}', style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: i < 3 ? AppTheme.cardOrange : AppTheme.textSecondary,
                                                  )),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(child: Text(t['testName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
                                                Text('$count times', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                                const SizedBox(width: 8),
                                                Text('Rs. ${rev.toStringAsFixed(0)}',
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.cardGreen)),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: ratio.toDouble(),
                                                backgroundColor: Colors.grey.shade100,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  i < 3 ? AppTheme.cardOrange : AppTheme.cardBlue,
                                                ),
                                                minHeight: 6,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    })),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Quick summary
                        SizedBox(
                          width: 280,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.insights_rounded, color: AppTheme.cardPurple, size: 22),
                                      SizedBox(width: 8),
                                      Text('Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _summaryRow('Today', 'Rs. ${_todayRevenue.toStringAsFixed(0)}', AppTheme.cardGreen),
                                  const Divider(height: 24),
                                  _summaryRow('This Month', 'Rs. ${_monthRevenue.toStringAsFixed(0)}', AppTheme.cardBlue),
                                  const Divider(height: 24),
                                  _summaryRow('All Time', 'Rs. ${_totalRevenue.toStringAsFixed(0)}', AppTheme.cardPurple),
                                  const Divider(height: 24),
                                  _summaryRow('Days Tracked', '${_revenueByDate.length}', AppTheme.textSecondary),
                                  const Divider(height: 24),
                                  _summaryRow('Unique Tests', '${_topTests.length}', AppTheme.cardOrange),
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
            ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

/// Custom bar chart painter for revenue by date
class _RevenueBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _RevenueBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxVal = data.map((d) => (d['total'] as num).toDouble()).fold(0.0, (a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((d) {
        final val = (d['total'] as num).toDouble();
        final ratio = maxVal > 0 ? val / maxVal : 0.0;
        final dateStr = d['day'] as String? ?? '';
        final label = dateStr.length >= 10 ? dateStr.substring(5) : dateStr; // MM-DD

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (val > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      val >= 1000 ? '${(val / 1000).toStringAsFixed(1)}k' : val.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.cardBlue),
                      textAlign: TextAlign.center,
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  height: (160 * ratio).clamp(4.0, 160.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppTheme.cardBlue, AppTheme.primaryColor],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary), textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
