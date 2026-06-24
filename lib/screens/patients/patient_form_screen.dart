import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/patient_model.dart';
import '../../theme/app_theme.dart';

class PatientFormScreen extends StatefulWidget {
  final PatientModel? patient;
  const PatientFormScreen({super.key, this.patient});

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _nicCtrl;
  String _gender = 'Male';
  bool _saving = false;

  bool get isEdit => widget.patient != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.patient?.name ?? '');
    _ageCtrl = TextEditingController(text: widget.patient?.age.toString() ?? '');
    _phoneCtrl = TextEditingController(text: widget.patient?.phone ?? '');
    _addressCtrl = TextEditingController(text: widget.patient?.address ?? '');
    _nicCtrl = TextEditingController(text: widget.patient?.nic ?? '');
    _gender = widget.patient?.gender ?? 'Male';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _nicCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final patient = PatientModel(
      id: widget.patient?.id,
      name: _nameCtrl.text.trim(),
      age: int.parse(_ageCtrl.text.trim()),
      gender: _gender,
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      nic: _nicCtrl.text.trim(),
    );

    if (isEdit) {
      await DBHelper.updatePatient(widget.patient!.id!, patient.toMap());
    } else {
      await DBHelper.insertPatient(patient.toMap());
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Patient' : 'Add Patient'),
      ),
      body: Center(
        child: Container(
          width: 600,
          margin: const EdgeInsets.all(28),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isEdit ? 'Edit Patient Details' : 'New Patient Registration',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ageCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Age *', prefixIcon: Icon(Icons.cake_outlined)),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter age';
                              if (int.tryParse(v) == null) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _gender,
                            decoration: const InputDecoration(labelText: 'Gender *', prefixIcon: Icon(Icons.wc_outlined)),
                            items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                            onChanged: (v) => setState(() => _gender = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneCtrl,
                            decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone_outlined)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _nicCtrl,
                            decoration: const InputDecoration(labelText: 'CNIC / NIC', prefixIcon: Icon(Icons.credit_card_outlined), hintText: 'XXXXX-XXXXXXX-X'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_outlined)),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(isEdit ? 'Update' : 'Save Patient'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
