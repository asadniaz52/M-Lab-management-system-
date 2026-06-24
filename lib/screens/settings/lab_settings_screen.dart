import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../database/db_helper.dart';
import '../../theme/app_theme.dart';

class LabSettingsScreen extends StatefulWidget {
  const LabSettingsScreen({super.key});

  @override
  State<LabSettingsScreen> createState() => _LabSettingsScreenState();
}

class _LabSettingsScreenState extends State<LabSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labNameCtrl = TextEditingController();
  final _labNameUrduCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _doctorNameCtrl = TextEditingController();
  final _ceoNameCtrl = TextEditingController();
  final _ceoEducationCtrl = TextEditingController();
  final _inchargeNameCtrl = TextEditingController();
  final _inchargeEducationCtrl = TextEditingController();
  final _watermarkCtrl = TextEditingController();
  final _registrationNoCtrl = TextEditingController();
  String _headerImagePath = '';
  bool _printHeaderFooter = true;
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _signatures = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await DBHelper.getLabSettings();
    if (settings != null) {
      _labNameCtrl.text = settings['labName'] ?? '';
      _labNameUrduCtrl.text = settings['labNameUrdu'] ?? 'عمر میڈیکل لیبارٹری';
      _addressCtrl.text = settings['address'] ?? '';
      _phoneCtrl.text = settings['phone'] ?? '';
      _emailCtrl.text = settings['email'] ?? '';
      _doctorNameCtrl.text = settings['doctorName'] ?? '';
      _ceoNameCtrl.text = settings['ceoName'] ?? '';
      _ceoEducationCtrl.text = settings['ceoEducation'] ?? '';
      _inchargeNameCtrl.text = settings['inchargeName'] ?? '';
      _inchargeEducationCtrl.text = settings['inchargeEducation'] ?? '';
      _watermarkCtrl.text = settings['watermarkText'] ?? '';
      _registrationNoCtrl.text = settings['registrationNo'] ?? '';
      _headerImagePath = settings['headerImagePath'] ?? '';
      _printHeaderFooter = (settings['printHeaderFooter'] ?? 1) == 1;
    }
    final sigs = await DBHelper.getFooterSignatures();
    setState(() {
      _signatures = sigs;
      _loading = false;
    });
  }

  Future<void> _deleteSignature(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Signature'),
        content: const Text('Are you sure you want to delete this signature from reports?'),
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
      await DBHelper.deleteFooterSignature(id);
      _loadSettings();
    }
  }

  void _showSignatureDialog([Map<String, dynamic>? sig]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: sig?['name'] ?? '');
    final designationCtrl = TextEditingController(text: sig?['designation'] ?? '');
    final educationCtrl = TextEditingController(text: sig?['education'] ?? '');
    final sortCtrl = TextEditingController(text: (sig?['sortOrder'] ?? (_signatures.length + 1)).toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(sig == null ? 'Add Signature' : 'Edit Signature'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name *', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: designationCtrl,
                    decoration: const InputDecoration(labelText: 'Designation / Role (optional)', prefixIcon: Icon(Icons.badge_outlined)),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: educationCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Education & Qualifications (one per line) *', 
                      prefixIcon: Icon(Icons.school_outlined),
                      hintText: 'MBBS\nMCPS\nFCPS',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: sortCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sort Order (number)', prefixIcon: Icon(Icons.sort_rounded)),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (int.tryParse(v) == null) return 'Must be a number';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              
              final data = {
                'name': nameCtrl.text.trim(),
                'designation': designationCtrl.text.trim(),
                'education': educationCtrl.text.trim(),
                'sortOrder': int.parse(sortCtrl.text.trim()),
              };
              
              if (sig == null) {
                await DBHelper.insertFooterSignature(data);
              } else {
                await DBHelper.updateFooterSignature(sig['id'], data);
              }
              
              if (ctx.mounted) {
                Navigator.pop(ctx);
                _loadSettings();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickHeaderImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _headerImagePath = result.files.single.path!);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    await DBHelper.updateLabSettings({
      'labName': _labNameCtrl.text.trim(),
      'labNameUrdu': _labNameUrduCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'doctorName': _doctorNameCtrl.text.trim(),
      'ceoName': _ceoNameCtrl.text.trim(),
      'ceoEducation': _ceoEducationCtrl.text.trim(),
      'inchargeName': _inchargeNameCtrl.text.trim(),
      'inchargeEducation': _inchargeEducationCtrl.text.trim(),
      'watermarkText': _watermarkCtrl.text.trim(),
      'registrationNo': _registrationNoCtrl.text.trim(),
      'headerImagePath': _headerImagePath,
      'printHeaderFooter': _printHeaderFooter ? 1 : 0,
    });

    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  Future<void> _exportBackup() async {
    try {
      final dbPath = await DBHelper.getDatabasePath();
      final extension = dbPath.split('.').last;
      
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Select where to save database backup',
        fileName: 'BashirLab_Backup_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}.$extension',
        type: FileType.any,
      );

      if (result != null) {
        await DBHelper.backupDatabase(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup exported successfully!'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export backup: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select the database backup file (.db)',
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Restore Backup'),
            content: const Text('Are you sure you want to restore this backup? This will overwrite all current tests, reports, and invoices with the backup data. The app will close and must be restarted.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Restore & Exit'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await DBHelper.restoreDatabase(path);
          exit(0);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore backup: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _labNameCtrl.dispose();
    _labNameUrduCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _doctorNameCtrl.dispose();
    _ceoNameCtrl.dispose();
    _ceoEducationCtrl.dispose();
    _inchargeNameCtrl.dispose();
    _inchargeEducationCtrl.dispose();
    _watermarkCtrl.dispose();
    _registrationNoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Settings', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  const Text('Manage laboratory profile, printing & branding', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                  const SizedBox(height: 28),
                  Center(
                    child: SizedBox(
                      width: 700,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Lab Info Card
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(Icons.biotech_rounded, color: AppTheme.primaryColor, size: 26),
                                        ),
                                        const SizedBox(width: 14),
                                        const Text('Laboratory Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    TextFormField(
                                      controller: _labNameCtrl,
                                      decoration: const InputDecoration(labelText: 'Laboratory Name (English) *', prefixIcon: Icon(Icons.business_outlined)),
                                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _labNameUrduCtrl,
                                      textDirection: TextDirection.rtl,
                                      decoration: const InputDecoration(
                                        labelText: 'Laboratory Name (Urdu / اردو نام)',
                                        prefixIcon: Icon(Icons.translate_rounded),
                                        hintText: 'بشیر کلینیکل لیبارٹری',
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _registrationNoCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Registration No (e.g. Reg No.HRA/500/R Bw/LAB/9)',
                                        prefixIcon: Icon(Icons.confirmation_number_outlined),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _addressCtrl,
                                      decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_outlined)),
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _phoneCtrl,
                                            decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _emailCtrl,
                                            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // dynamic Staff Info Card
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 46,
                                              height: 46,
                                              decoration: BoxDecoration(
                                                color: AppTheme.cardPurple.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Icon(Icons.people_rounded, color: AppTheme.cardPurple, size: 26),
                                            ),
                                            const SizedBox(width: 14),
                                            const Text('Report Footer Signatures', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () => _showSignatureDialog(),
                                          icon: const Icon(Icons.add, size: 16),
                                          label: const Text('Add Signature', style: TextStyle(fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Text('Add, edit, or delete the doctors and technicians shown in the report footer.',
                                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                    const SizedBox(height: 20),
                                    if (_signatures.isEmpty)
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Text('No signatures configured. Click "Add Signature" to add.',
                                              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                                        ),
                                      )
                                    else
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _signatures.length,
                                        separatorBuilder: (_, __) => const Divider(height: 16),
                                        itemBuilder: (context, index) {
                                          final sig = _signatures[index];
                                          final educationLines = (sig['education'] as String? ?? '').split('\n').where((l) => l.trim().isNotEmpty).toList();
                                          
                                          return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(
                                              sig['name'] ?? '',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if ((sig['designation'] as String? ?? '').isNotEmpty)
                                                  Text(sig['designation'], style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: AppTheme.primaryColor)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  educationLines.join(' | '),
                                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                                ),
                                              ],
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.cardBlue),
                                                  onPressed: () => _showSignatureDialog(sig),
                                                  tooltip: 'Edit',
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                                                  onPressed: () => _deleteSignature(sig['id']),
                                                  tooltip: 'Delete',
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Print & Branding Card
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            color: AppTheme.cardBlue.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(Icons.print_rounded, color: AppTheme.cardBlue, size: 26),
                                        ),
                                        const SizedBox(width: 14),
                                        const Text('Print & Branding', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    // Header Image
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.grey.shade300),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.image_outlined, color: AppTheme.textSecondary),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    _headerImagePath.isEmpty ? 'No header image selected' : _headerImagePath.split('\\').last.split('/').last,
                                                    style: TextStyle(fontSize: 13, color: _headerImagePath.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (_headerImagePath.isNotEmpty)
                                                  IconButton(
                                                    icon: const Icon(Icons.close, size: 18, color: AppTheme.error),
                                                    onPressed: () => setState(() => _headerImagePath = ''),
                                                    tooltip: 'Remove',
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton.icon(
                                          onPressed: _pickHeaderImage,
                                          icon: const Icon(Icons.upload_file, size: 18),
                                          label: const Text('Upload Header'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _watermarkCtrl,
                                      decoration: const InputDecoration(labelText: 'Watermark Text', prefixIcon: Icon(Icons.water_drop_outlined)),
                                    ),
                                    const SizedBox(height: 14),
                                    SwitchListTile(
                                      title: const Text('Print Header & Footer by default', style: TextStyle(fontSize: 14)),
                                      subtitle: const Text('You can still choose at print time', style: TextStyle(fontSize: 12)),
                                      value: _printHeaderFooter,
                                      activeThumbColor: AppTheme.primaryColor,
                                      onChanged: (v) => setState(() => _printHeaderFooter = v),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Backup & Restore Card
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            color: AppTheme.success.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(Icons.backup_rounded, color: AppTheme.success, size: 26),
                                        ),
                                        const SizedBox(width: 14),
                                        const Text('Database Backup & Restore', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Text('Export a backup file of all patients, tests, parameters, reports, and invoices, or import an existing backup file.',
                                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                    const SizedBox(height: 24),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.success,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 16),
                                            ),
                                            onPressed: _exportBackup,
                                            icon: const Icon(Icons.download_rounded, size: 20),
                                            label: const Text('Export Backup File', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 16),
                                              side: const BorderSide(color: AppTheme.primaryColor),
                                            ),
                                            onPressed: _importBackup,
                                            icon: const Icon(Icons.upload_rounded, size: 20),
                                            label: const Text('Import / Restore Backup', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: _saving
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.save, size: 18),
                                label: const Text('Save Settings'),
                              ),
                            ),
                          ],
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
