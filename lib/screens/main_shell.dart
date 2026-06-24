import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'patients/patient_list_screen.dart';
import 'tests/test_list_screen.dart';
import 'tests/price_list_screen.dart';
import 'reports/report_list_screen.dart';
import 'reports/enter_results_screen.dart';
import 'invoices/invoice_list_screen.dart';
import 'employees/employee_list_screen.dart';
import 'settings/lab_settings_screen.dart';
import 'settings/user_management_screen.dart';
import 'settings/revenue_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  final List<_NavItem> _allNavItems = [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', adminOnly: false),
    _NavItem(icon: Icons.people_rounded, label: 'Patients', adminOnly: false),
    _NavItem(icon: Icons.science_rounded, label: 'Tests', adminOnly: false),
    _NavItem(icon: Icons.assignment_rounded, label: 'Investigations', adminOnly: false),
    _NavItem(icon: Icons.edit_note_rounded, label: 'Enter Results', adminOnly: false),
    _NavItem(icon: Icons.receipt_long_rounded, label: 'Invoices', adminOnly: false),
    _NavItem(icon: Icons.list_alt_rounded, label: 'Price List', adminOnly: false),
    _NavItem(icon: Icons.trending_up_rounded, label: 'Revenue', adminOnly: true),
    _NavItem(icon: Icons.badge_rounded, label: 'Staff', adminOnly: true),
    _NavItem(icon: Icons.settings_rounded, label: 'Settings', adminOnly: true),
    _NavItem(icon: Icons.admin_panel_settings_rounded, label: 'Users', adminOnly: true),
  ];

  final List<Widget> _allScreens = [
    const DashboardScreen(),
    const PatientListScreen(),
    const TestListScreen(),
    const ReportListScreen(),
    const EnterResultsScreen(),
    const InvoiceListScreen(),
    const PriceListScreen(),
    const RevenueScreen(),
    const EmployeeListScreen(),
    const LabSettingsScreen(),
    const UserManagementScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Build visible items based on role
    final List<int> visibleIndices = [];
    for (int i = 0; i < _allNavItems.length; i++) {
      if (!_allNavItems[i].adminOnly || auth.isAdmin) {
        visibleIndices.add(i);
      }
    }

    // Clamp selected index
    if (!visibleIndices.contains(_selectedIndex)) {
      _selectedIndex = 0;
    }

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 240,
            decoration: const BoxDecoration(
              color: AppTheme.sidebarBg,
            ),
            child: Column(
              children: [
                // Lab branding
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.biotech_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MUHAMMAD',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'MEDICAL LABORATORY',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),
                // Nav items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: visibleIndices.length,
                    itemBuilder: (context, i) {
                      final idx = visibleIndices[i];
                      final item = _allNavItems[idx];
                      final selected = _selectedIndex == idx;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _selectedIndex = idx),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppTheme.sidebarSelected
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item.icon,
                                    color: selected
                                        ? Colors.white
                                        : Colors.white54,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : Colors.white54,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // User info + logout
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.primaryColor,
                            child: Text(
                              (auth.currentUser?.fullName ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  auth.currentUser?.fullName ?? 'User',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  auth.currentUser?.role ?? '',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout_rounded,
                                color: Colors.white54, size: 20),
                            onPressed: () async {
                              await auth.logout();
                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen()),
                                  (route) => false,
                                );
                              }
                            },
                            tooltip: 'Logout',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: _allScreens[_selectedIndex],
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final bool adminOnly;
  const _NavItem({required this.icon, required this.label, this.adminOnly = false});
}
