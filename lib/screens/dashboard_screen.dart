import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/db_helper.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'invoices/create_invoice_screen.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _patientCount = 0;
  int _todayReports = 0;
  int _pendingReports = 0;
  double _todayRevenue = 0;
  double _monthRevenue = 0;
  int _verifiedCount = 0;
  List<Map<String, dynamic>> _verificationStats = [];
  List<Map<String, dynamic>> _recentReports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final patients = await DBHelper.getPatientCount();
    final todayRep = await DBHelper.getTodayReportCount();
    final pending = await DBHelper.getPendingReportCount();
    final todayRev = await DBHelper.getTodayRevenue();
    final monthRev = await DBHelper.getMonthRevenue();
    final recent = await DBHelper.getAllReports();
    final verified = await DBHelper.getVerifiedReportCount();
    final vStats = await DBHelper.getVerificationStats();

    setState(() {
      _patientCount = patients;
      _todayReports = todayRep;
      _pendingReports = pending;
      _todayRevenue = todayRev;
      _monthRevenue = monthRev;
      _recentReports = recent.take(8).toList();
      _verifiedCount = verified;
      _verificationStats = vStats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dashboard',
                              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Welcome back, ${auth.currentUser?.fullName ?? 'User'}!',
                              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _loadStats,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Quick Actions
                    Row(
                      children: [
                        _buildActionButton(
                          context,
                          'Create Invoice',
                          Icons.add_shopping_cart_rounded,
                          AppTheme.primaryColor,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
                          ).then((_) => _loadStats()),
                        ),

                      ],
                    ),
                    const SizedBox(height: 28),

                    // Stats cards
                    Row(
                      children: [
                        _buildStatCard('Total Patients', _patientCount.toString(), Icons.people_rounded, AppTheme.cardBlue),
                        const SizedBox(width: 20),
                        _buildStatCard("Today's Reports", _todayReports.toString(), Icons.assignment_rounded, AppTheme.cardGreen),
                        const SizedBox(width: 20),
                        _buildStatCard('Pending Reports', _pendingReports.toString(), Icons.pending_actions_rounded, AppTheme.cardOrange),
                        const SizedBox(width: 20),
                        if (isAdmin)
                          _buildStatCard("Today's Revenue", 'Rs. ${_todayRevenue.toStringAsFixed(0)}', Icons.account_balance_wallet_rounded, AppTheme.cardPurple)
                        else
                          _buildStatCard('Verified Reports', _verifiedCount.toString(), Icons.verified_rounded, AppTheme.cardPurple),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Revenue card (admin only)
                    if (isAdmin) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Revenue Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  _buildRevenueItem("Today's Earnings", 'Rs. ${_todayRevenue.toStringAsFixed(0)}', Icons.today_rounded, AppTheme.cardGreen),
                                  const SizedBox(width: 40),
                                  _buildRevenueItem("This Month", 'Rs. ${_monthRevenue.toStringAsFixed(0)}', Icons.calendar_month_rounded, AppTheme.cardBlue),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],

                    // Verification Stats
                    if (_verificationStats.isNotEmpty || isAdmin)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.verified_rounded, color: AppTheme.cardGreen, size: 22),
                                  const SizedBox(width: 8),
                                  const Text('Verification Stats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cardGreen.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text('$_verifiedCount verified', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.cardGreen)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_verificationStats.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(child: Text('No verified reports yet', style: TextStyle(color: AppTheme.textSecondary))),
                                )
                              else
                                ...(_verificationStats.map((stat) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: AppTheme.primaryColor,
                                          child: Text(
                                            (stat['verifiedBy'] as String? ?? 'U')[0].toUpperCase(),
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text(stat['verifiedBy'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w500))),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text('${stat['count']} reports', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.primaryColor)),
                                        ),
                                      ],
                                    ),
                                  );
                                })),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 28),

                    // Recent reports
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Recent Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            const SizedBox(height: 16),
                            if (_recentReports.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(40),
                                alignment: Alignment.center,
                                child: Column(
                                  children: [
                                    Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade300),
                                    const SizedBox(height: 12),
                                    Text('No reports yet', style: TextStyle(color: Colors.grey.shade400)),
                                  ],
                                ),
                              )
                            else
                              SizedBox(
                                width: double.infinity,
                                child: DataTable(
                                  headingRowHeight: 44,
                                  dataRowMinHeight: 44,
                                  dataRowMaxHeight: 52,
                                  columns: const [
                                    DataColumn(label: Text('ID')),
                                    DataColumn(label: Text('Patient')),
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('Verified By')),
                                  ],
                                  rows: _recentReports.map((r) {
                                    final status = r['status'] ?? 'pending';
                                    final verifiedBy = r['verifiedBy'] ?? '';
                                    return DataRow(cells: [
                                      DataCell(Text('#${r['id']}')),
                                      DataCell(Text(r['patientName'] ?? '')),
                                      DataCell(Text((r['date'] ?? '').toString().length >= 10 ? (r['date']).toString().substring(0, 10) : '')),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: status == 'completed' ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.warning.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: status == 'completed' ? AppTheme.success : AppTheme.warning),
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(verifiedBy.toString().isNotEmpty ? verifiedBy.toString() : '-')),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
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

  Widget _buildRevenueItem(String title, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
