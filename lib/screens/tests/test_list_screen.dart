import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/test_model.dart';
import '../../models/test_parameter_model.dart';
import '../../theme/app_theme.dart';

class TestListScreen extends StatefulWidget {
  const TestListScreen({super.key});

  @override
  State<TestListScreen> createState() => _TestListScreenState();
}

class _TestListScreenState extends State<TestListScreen> {
  List<TestModel> _tests = [];
  Map<int, int> _paramCounts = {};
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];
  bool _loading = true;
  final ScrollController _horizontalScrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTests();
    _searchCtrl.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _horizontalScrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTests() async {
    final data = await DBHelper.getAllTests();
    final tests = data.map((e) => TestModel.fromMap(e)).toList();
    final cats = tests.map((t) => t.category).toSet().toList()..sort();

    // Load parameter counts
    final counts = <int, int>{};
    for (var t in tests) {
      counts[t.id!] = await DBHelper.getTestParameterCount(t.id!);
    }

    setState(() {
      _tests = tests;
      _categories = ['All', ...cats];
      _paramCounts = counts;
      _loading = false;
    });
  }

  List<TestModel> get _filteredTests {
    final query = _searchCtrl.text.toLowerCase().trim();
    return _tests.where((t) {
      final matchesCategory = _selectedCategory == 'All' || t.category == _selectedCategory;
      final matchesSearch = query.isEmpty ||
          t.testName.toLowerCase().contains(query) ||
          t.category.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _showTestDialog([TestModel? test]) {
    final nameCtrl = TextEditingController(text: test?.testName ?? '');
    final rangeCtrl = TextEditingController(text: test?.normalRange ?? '');
    final unitCtrl = TextEditingController(text: test?.unit ?? '');
    final priceCtrl = TextEditingController(text: test?.price.toString() ?? '');
    final catCtrl = TextEditingController(text: test?.category ?? 'General');
    final printPageCtrl = TextEditingController(text: (test?.printPage ?? 0).toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(test != null ? 'Edit Test' : 'Add New Test'),
        content: SizedBox(
          width: 450,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Test Name *'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: rangeCtrl,
                        decoration: const InputDecoration(labelText: 'Normal Range'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(labelText: 'Unit'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Price (Rs.) *'),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Autocomplete<String>(
                        initialValue: TextEditingValue(text: catCtrl.text),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return _categories.where((c) => c != 'All');
                          }
                          return _categories.where((c) =>
                              c != 'All' &&
                              c.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (String selection) {
                          catCtrl.text = selection;
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          controller.addListener(() {
                            catCtrl.text = controller.text;
                          });
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(labelText: 'Category'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: printPageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Print Page (0 = default by category)',
                    helperText: 'Assign custom page number for PDF grouping',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final data = {
                'testName': nameCtrl.text.trim(),
                'normalRange': rangeCtrl.text.trim(),
                'unit': unitCtrl.text.trim(),
                'price': double.parse(priceCtrl.text.trim()),
                'category': catCtrl.text.trim().isEmpty ? 'General' : catCtrl.text.trim(),
                'printPage': int.tryParse(printPageCtrl.text.trim()) ?? 0,
              };
              if (test != null) {
                await DBHelper.updateTest(test.id!, data);
              } else {
                await DBHelper.insertTest(data);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _loadTests();
            },
            child: Text(test != null ? 'Update' : 'Add Test'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTest(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Test'),
        content: const Text('This will also delete all sub-parameters. Are you sure?'),
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
      await DBHelper.deleteTest(id);
      _loadTests();
    }
  }

  void _showParametersDialog(TestModel test) {
    showDialog(
      context: context,
      builder: (ctx) => _ParametersDialog(test: test),
    ).then((_) => _loadTests());
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lab Tests', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    SizedBox(height: 4),
                    Text('Manage available test definitions & sub-parameters', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showTestDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Test'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // Search field
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search tests...',
                        hintStyle: TextStyle(fontSize: 14, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.primaryColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () => _searchCtrl.clear(),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Category filter
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final cat = _categories[i];
                        final selected = cat == _selectedCategory;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: selected,
                          selectedColor: AppTheme.primaryColor,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : AppTheme.textSecondary,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          onSelected: (_) => setState(() => _selectedCategory = cat),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Card(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Scrollbar(
                        controller: _horizontalScrollCtrl,
                        thumbVisibility: true,
                        trackVisibility: true,
                        child: SingleChildScrollView(
                          controller: _horizontalScrollCtrl,
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columnSpacing: 24,
                              columns: const [
                                DataColumn(label: Text('Test Name')),
                                DataColumn(label: Text('Category')),
                                DataColumn(label: Text('Normal Range')),
                                DataColumn(label: Text('Unit')),
                                DataColumn(label: Text('Price (Rs.)')),
                                DataColumn(label: Text('Page')),
                                DataColumn(label: Text('Parameters')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: _filteredTests.map((t) {
                                final count = _paramCounts[t.id] ?? 0;
                                return DataRow(cells: [
                                  DataCell(SizedBox(
                                    width: 180,
                                    child: Text(t.testName, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                                  )),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(t.category, style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
                                  )),
                                  DataCell(Text(t.normalRange)),
                                  DataCell(Text(t.unit)),
                                  DataCell(Text(t.price.toStringAsFixed(0))),
                                  DataCell(
                                    t.printPage > 0
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppTheme.cardPurple.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text('P${t.printPage}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.cardPurple)),
                                          )
                                        : const Text('Auto', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  ),
                                  DataCell(
                                    InkWell(
                                      onTap: () => _showParametersDialog(t),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: count > 0 ? AppTheme.cardOrange.withValues(alpha: 0.1) : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.list_alt, size: 14, color: count > 0 ? AppTheme.cardOrange : AppTheme.textSecondary),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$count params',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: count > 0 ? AppTheme.cardOrange : AppTheme.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.cardBlue),
                                        onPressed: () => _showTestDialog(t),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                                        onPressed: () => _deleteTest(t.id!),
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
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Sub-Parameters Dialog =====
class _ParametersDialog extends StatefulWidget {
  final TestModel test;
  const _ParametersDialog({required this.test});

  @override
  State<_ParametersDialog> createState() => _ParametersDialogState();
}

class _ParametersDialogState extends State<_ParametersDialog> {
  List<TestParameterModel> _params = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadParams();
  }

  Future<void> _loadParams() async {
    final data = await DBHelper.getTestParameters(widget.test.id!);
    setState(() {
      _params = data.map((e) => TestParameterModel.fromMap(e)).toList();
      _loading = false;
    });
  }

  void _addParam() {
    _showParamDialog();
  }

  void _editParam(TestParameterModel param) {
    _showParamDialog(param);
  }

  void _showParamDialog([TestParameterModel? param]) {
    final nameCtrl = TextEditingController(text: param?.paramName ?? '');
    final rangeCtrl = TextEditingController(text: param?.normalRange ?? '');
    final unitCtrl = TextEditingController(text: param?.unit ?? '');
    final maleCtrl = TextEditingController(text: param?.normalRangeMale ?? '');
    final femaleCtrl = TextEditingController(text: param?.normalRangeFemale ?? '');
    final childCtrl = TextEditingController(text: param?.normalRangeChild ?? '');
    final formKey = GlobalKey<FormState>();
    String selectedRangeType = param?.rangeType ?? 'normal';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(param != null ? 'Edit Parameter' : 'Add Parameter'),
          content: SizedBox(
            width: 450,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Parameter Name *'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                    const SizedBox(height: 16),
                    // Range Type selector
                    DropdownButtonFormField<String>(
                      value: selectedRangeType,
                      decoration: const InputDecoration(labelText: 'Range Type'),
                      items: const [
                        DropdownMenuItem(value: 'normal', child: Text('Normal (numeric range)')),
                        DropdownMenuItem(value: 'negative', child: Text('Negative / Value based')),
                        DropdownMenuItem(value: 'nil', child: Text('Nil (no range)')),
                        DropdownMenuItem(value: 'multi', child: Text('Multiple (Male / Female / Child)')),
                      ],
                      onChanged: (v) {
                        setDialogState(() => selectedRangeType = v ?? 'normal');
                      },
                    ),
                    const SizedBox(height: 12),
                    // Conditional fields based on range type
                    if (selectedRangeType == 'normal')
                      TextFormField(
                        controller: rangeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Normal Range',
                          hintText: 'e.g. 70-110 mg/dL',
                        ),
                      ),
                    if (selectedRangeType == 'negative')
                      TextFormField(
                        controller: rangeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Expected Value',
                          hintText: 'e.g. Negative, Non-Reactive',
                        ),
                      ),
                    if (selectedRangeType == 'multi') ...[
                      TextFormField(
                        controller: maleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Male Normal Range',
                          hintText: 'e.g. 4.5-5.5',
                          prefixIcon: Icon(Icons.male, size: 18),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: femaleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Female Normal Range',
                          hintText: 'e.g. 3.8-5.0',
                          prefixIcon: Icon(Icons.female, size: 18),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: childCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Child Normal Range',
                          hintText: 'e.g. 3.5-4.5',
                          prefixIcon: Icon(Icons.child_care, size: 18),
                        ),
                      ),
                    ],
                    // nil: no fields needed
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

                // For multi type, build a combined normalRange string
                String finalRange = rangeCtrl.text.trim();
                if (selectedRangeType == 'multi') {
                  final parts = <String>[];
                  if (maleCtrl.text.trim().isNotEmpty) parts.add('M: ${maleCtrl.text.trim()}');
                  if (femaleCtrl.text.trim().isNotEmpty) parts.add('F: ${femaleCtrl.text.trim()}');
                  if (childCtrl.text.trim().isNotEmpty) parts.add('C: ${childCtrl.text.trim()}');
                  finalRange = parts.join(' | ');
                } else if (selectedRangeType == 'nil') {
                  finalRange = '';
                }

                final data = {
                  'paramName': nameCtrl.text.trim(),
                  'normalRange': finalRange,
                  'unit': unitCtrl.text.trim(),
                  'rangeType': selectedRangeType,
                  'normalRangeMale': maleCtrl.text.trim(),
                  'normalRangeFemale': femaleCtrl.text.trim(),
                  'normalRangeChild': childCtrl.text.trim(),
                };

                if (param != null) {
                  await DBHelper.updateTestParameter(param.id!, data);
                } else {
                  await DBHelper.insertTestParameter({
                    ...data,
                    'parentTestId': widget.test.id,
                    'sortOrder': _params.length + 1,
                  });
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _loadParams();
              },
              child: Text(param != null ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteParam(int id) async {
    await DBHelper.deleteTestParameter(id);
    _loadParams();
  }

  String _rangeTypeLabel(String type) {
    switch (type) {
      case 'negative': return 'Negative';
      case 'nil': return 'Nil';
      case 'multi': return 'Multi';
      default: return 'Normal';
    }
  }

  Color _rangeTypeColor(String type) {
    switch (type) {
      case 'negative': return AppTheme.error;
      case 'nil': return AppTheme.textSecondary;
      case 'multi': return AppTheme.cardPurple;
      default: return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.list_alt, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Expanded(child: Text('Parameters: ${widget.test.testName}', overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 400,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_params.length} parameter(s)', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ElevatedButton.icon(
                        onPressed: _addParam,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Parameter'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _params.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.info_outline, size: 40, color: Colors.grey.shade300),
                                const SizedBox(height: 8),
                                Text('No sub-parameters defined', style: TextStyle(color: Colors.grey.shade400)),
                                const SizedBox(height: 4),
                                Text('Add parameters like Hb, TLC, DLC etc.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _params.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final p = _params[i];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  child: Text('${i + 1}', style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor)),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(child: Text(p.paramName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _rangeTypeColor(p.rangeType).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(_rangeTypeLabel(p.rangeType),
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _rangeTypeColor(p.rangeType))),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  'Range: ${p.displayRange.isEmpty ? "-" : p.displayRange}  |  Unit: ${p.unit.isEmpty ? "-" : p.unit}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.cardBlue), onPressed: () => _editParam(p)),
                                    IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.error), onPressed: () => _deleteParam(p.id!)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}
