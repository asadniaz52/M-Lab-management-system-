import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/employee_model.dart';
import '../../theme/app_theme.dart';
import 'attendance_screen.dart';
import '../../services/certificate_generator.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<EmployeeModel> _employees = [];
  List<EmployeeModel> _internees = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final emps = await DBHelper.getEmployeesByType('employee');
    final interns = await DBHelper.getEmployeesByType('internee');
    setState(() {
      _employees = emps.map((e) => EmployeeModel.fromMap(e)).toList();
      _internees = interns.map((e) => EmployeeModel.fromMap(e)).toList();
      _loading = false;
    });
  }

  void _showEmployeeDialog([EmployeeModel? emp]) {
    final nameCtrl = TextEditingController(text: emp?.name ?? '');
    final phoneCtrl = TextEditingController(text: emp?.phone ?? '');
    final deptCtrl = TextEditingController(text: emp?.department ?? '');
    String type = emp?.type ?? 'employee';
    String status = emp?.status ?? 'active';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(emp == null ? 'Add Staff Member' : 'Edit Staff Member'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline))),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined))),
                const SizedBox(height: 12),
                TextField(controller: deptCtrl, decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.business_outlined))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type', prefixIcon: Icon(Icons.badge_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'employee', child: Text('Employee')),
                    DropdownMenuItem(value: 'internee', child: Text('Internee')),
                  ],
                  onChanged: (v) => setS(() => type = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.toggle_on_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: (v) => setS(() => status = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final data = {
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'department': deptCtrl.text.trim(),
                  'type': type,
                  'status': status,
                  'joinDate': emp?.joinDate ?? DateTime.now().toIso8601String().substring(0, 10),
                  'endDate': '',
                };
                if (emp == null) {
                  await DBHelper.insertEmployee(data);
                } else {
                  await DBHelper.updateEmployee(emp.id!, data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              child: Text(emp == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEmployee(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Staff Member?'),
        content: const Text('This will also delete all attendance records.'),
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
    if (confirmed == true) {
      await DBHelper.deleteEmployee(id);
      _loadData();
    }
  }

  Future<void> _generateCertificate(EmployeeModel emp) async {
    final labSettings = await DBHelper.getLabSettings();
    if (labSettings == null) return;

    DateTime startDate = DateTime.tryParse(emp.joinDate) ?? DateTime.now();
    DateTime endDate = (emp.endDate != null && emp.endDate!.isNotEmpty) ? (DateTime.tryParse(emp.endDate!) ?? DateTime.now()) : DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Certificate Dates'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start Date'),
                subtitle: Text(startDate.toIso8601String().substring(0, 10)),
                trailing: const Icon(Icons.calendar_today, size: 20),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: startDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) setS(() => startDate = d);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End Date'),
                subtitle: Text(endDate.toIso8601String().substring(0, 10)),
                trailing: const Icon(Icons.calendar_today, size: 20),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: endDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) setS(() => endDate = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generate')),
          ],
        ),
      ),
    );

    if (result == true) {
      final updatedEmp = emp.copyWith(joinDate: startDate.toIso8601String(), endDate: endDate.toIso8601String());
      await CertificateGenerator.generateCertificate(
        employee: updatedEmp,
        labSettings: labSettings,
      );
    }
  }

  Widget _buildList(List<EmployeeModel> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No staff members found', style: TextStyle(color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Department')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Join Date')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: list.map((e) {
            return DataRow(cells: [
              DataCell(Text(e.name, style: const TextStyle(fontWeight: FontWeight.w500))),
              DataCell(Text(e.phone)),
              DataCell(Text(e.department)),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: e.type == 'internee' ? AppTheme.cardOrange.withValues(alpha: 0.1) : AppTheme.cardBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  e.type.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: e.type == 'internee' ? AppTheme.cardOrange : AppTheme.cardBlue),
                ),
              )),
              DataCell(Text(e.joinDate.length >= 10 ? e.joinDate.substring(0, 10) : e.joinDate)),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: e.status == 'active' ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  e.status.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: e.status == 'active' ? AppTheme.success : AppTheme.error),
                ),
              )),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.cardBlue), onPressed: () => _showEmployeeDialog(e), tooltip: 'Edit'),
                  IconButton(icon: const Icon(Icons.card_membership, size: 18, color: AppTheme.cardPurple), onPressed: () => _generateCertificate(e), tooltip: 'Certificate'),
                  IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error), onPressed: () => _deleteEmployee(e.id!), tooltip: 'Delete'),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Staff Management', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Manage employees, internees & attendance', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen()));
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: const Text('Attendance'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showEmployeeDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Staff'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            TabBar(
              controller: _tabCtrl,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primaryColor,
              tabs: [
                Tab(text: 'All (${_employees.length + _internees.length})'),
                Tab(text: 'Employees (${_employees.length})'),
                Tab(text: 'Internees (${_internees.length})'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _buildList([..._employees, ..._internees]),
                          _buildList(_employees),
                          _buildList(_internees),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
