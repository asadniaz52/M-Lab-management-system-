import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/patient_model.dart';
import '../../theme/app_theme.dart';
import '../../services/pdf_patient_summary_generator.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'patient_form_screen.dart';
import 'patient_profile_screen.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  List<PatientModel> _patients = [];
  List<PatientModel> _filtered = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    final data = await DBHelper.getAllPatients();
    setState(() {
      _patients = data.map((e) => PatientModel.fromMap(e)).toList();
      _filtered = _patients;
      _loading = false;
    });
  }

  void _search(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _patients;
      } else {
        _filtered = _patients.where((p) =>
            p.name.toLowerCase().contains(query.toLowerCase()) ||
            p.phone.contains(query) ||
            p.nic.contains(query)).toList();
      }
    });
  }

  Future<void> _deletePatient(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Patient'),
        content: const Text('Are you sure you want to delete this patient?'),
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
      await DBHelper.deletePatient(id);
      _loadPatients();
    }
  }

  Future<void> _printPatientSummary() async {
    final settings = await DBHelper.getLabSettings() ?? {};
    await PdfPatientSummaryGenerator.printPatientSummaryReport(
      patients: _filtered,
      labSettings: settings,
    );
  }

  void _openProfile(PatientModel patient) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PatientProfileScreen(patient: patient)),
    ).then((_) => _loadPatients());
  }

  void _openForm([PatientModel? patient]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PatientFormScreen(patient: patient)),
    );
    if (result == true) _loadPatients();
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
            // Header
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patients', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    SizedBox(height: 4),
                    Text('Manage patient records (patients are created via Invoice)', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                  ],
                ),
                if (Provider.of<AuthProvider>(context, listen: false).isAdmin)
                  OutlinedButton.icon(
                    onPressed: _printPatientSummary,
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Print Summary'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            // Search
            SizedBox(
              width: 350,
              child: TextField(
                controller: _searchCtrl,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: 'Search by name, phone or NIC...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _search('');
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Table
            Expanded(
              child: Card(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text('No patients found', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: SizedBox(
                              width: double.infinity,
                              child: DataTable(
                                headingRowHeight: 48,
                                dataRowMinHeight: 48,
                                dataRowMaxHeight: 56,
                                columns: const [
                                  DataColumn(label: Text('ID')),
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Age')),
                                  DataColumn(label: Text('Gender')),
                                  DataColumn(label: Text('Phone')),
                                  DataColumn(label: Text('NIC')),
                                  DataColumn(label: Text('Address')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: _filtered.map((p) {
                                  return DataRow(cells: [
                                    DataCell(Text('#${p.id}')),
                                    DataCell(Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                                    DataCell(Text('${p.age}')),
                                    DataCell(Text(p.gender)),
                                    DataCell(Text(p.phone)),
                                    DataCell(Text(p.nic.isEmpty ? '-' : p.nic)),
                                    DataCell(Text(p.address, overflow: TextOverflow.ellipsis)),
                                    DataCell(Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.person_rounded, size: 18, color: AppTheme.cardPurple),
                                          onPressed: () => _openProfile(p),
                                          tooltip: 'View Profile',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.cardBlue),
                                          onPressed: () => _openForm(p),
                                          tooltip: 'Edit',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                                          onPressed: () => _deletePatient(p.id!),
                                          tooltip: 'Delete',
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
