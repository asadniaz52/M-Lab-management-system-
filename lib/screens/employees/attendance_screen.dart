import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/employee_model.dart';
import '../../theme/app_theme.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  List<EmployeeModel> _allEmployees = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _dateStr => _selectedDate.toIso8601String().substring(0, 10);

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final emps = await DBHelper.getAllEmployees();
    final activeEmps = emps.where((e) => e['status'] == 'active').toList();
    final att = await DBHelper.getAttendanceByDate(_dateStr);

    setState(() {
      _allEmployees = activeEmps.map((e) => EmployeeModel.fromMap(e)).toList();
      _attendanceRecords = att;
      _loading = false;
    });
  }

  String _getStatus(int employeeId) {
    final rec = _attendanceRecords.where((a) => a['employeeId'] == employeeId);
    if (rec.isEmpty) return 'unmarked';
    return rec.first['status'] ?? 'present';
  }

  String _getCheckIn(int employeeId) {
    final rec = _attendanceRecords.where((a) => a['employeeId'] == employeeId);
    if (rec.isEmpty) return '';
    return rec.first['checkIn'] ?? '';
  }

  Future<void> _markAttendance(int employeeId, String status) async {
    final existing = await DBHelper.getAttendanceRecord(employeeId, _dateStr);
    final now = TimeOfDay.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    if (existing != null) {
      await DBHelper.updateAttendance(existing['id'] as int, {
        'status': status,
        'checkIn': status == 'present' ? (existing['checkIn']?.toString().isEmpty == true ? timeStr : existing['checkIn']) : '',
      });
    } else {
      await DBHelper.insertAttendance({
        'employeeId': employeeId,
        'date': _dateStr,
        'checkIn': status == 'present' ? timeStr : '',
        'checkOut': '',
        'status': status,
      });
    }
    _loadData();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(title: const Text('Daily Attendance')),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Text('Date: $_dateStr', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: _pickDate,
                      child: const Text('Change Date'),
                    ),
                    const Spacer(),
                    // Summary
                    _summaryChip('Present', _allEmployees.where((e) => _getStatus(e.id!) == 'present').length, AppTheme.success),
                    const SizedBox(width: 8),
                    _summaryChip('Absent', _allEmployees.where((e) => _getStatus(e.id!) == 'absent').length, AppTheme.error),
                    const SizedBox(width: 8),
                    _summaryChip('Leave', _allEmployees.where((e) => _getStatus(e.id!) == 'leave').length, AppTheme.warning),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Attendance table
            Expanded(
              child: Card(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _allEmployees.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text('No active staff members', style: TextStyle(color: Colors.grey.shade400)),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: SizedBox(
                              width: double.infinity,
                              child: DataTable(
                                columnSpacing: 24,
                                columns: const [
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Type')),
                                  DataColumn(label: Text('Department')),
                                  DataColumn(label: Text('Check In')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: _allEmployees.map((emp) {
                                  final status = _getStatus(emp.id!);
                                  final checkIn = _getCheckIn(emp.id!);
                                  return DataRow(cells: [
                                    DataCell(Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                                    DataCell(Text(emp.type.toUpperCase(), style: TextStyle(fontSize: 11, color: emp.type == 'internee' ? AppTheme.cardOrange : AppTheme.cardBlue))),
                                    DataCell(Text(emp.department)),
                                    DataCell(Text(checkIn.isNotEmpty ? checkIn : '-')),
                                    DataCell(_statusBadge(status)),
                                    DataCell(Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _actionBtn('P', AppTheme.success, () => _markAttendance(emp.id!, 'present'), status == 'present'),
                                        _actionBtn('A', AppTheme.error, () => _markAttendance(emp.id!, 'absent'), status == 'absent'),
                                        _actionBtn('L', AppTheme.warning, () => _markAttendance(emp.id!, 'leave'), status == 'leave'),
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

  Widget _summaryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text('$label: $count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'present':
        color = AppTheme.success;
        label = 'PRESENT';
        break;
      case 'absent':
        color = AppTheme.error;
        label = 'ABSENT';
        break;
      case 'leave':
        color = AppTheme.warning;
        label = 'LEAVE';
        break;
      default:
        color = Colors.grey;
        label = 'UNMARKED';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap, bool active) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: active ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: active ? Colors.white : color)),
        ),
      ),
    );
  }
}
