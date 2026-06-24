import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<UserModel> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final data = await DBHelper.getAllUsers();
    setState(() {
      _users = data.map((e) => UserModel.fromMap(e)).toList();
      _loading = false;
    });
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<void> _deleteUser(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user?'),
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
      await DBHelper.deleteUser(id);
      _loadUsers();
    }
  }

  void _editRole(UserModel user) {
    String selectedRole = user.role;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Role: ${user.fullName}'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(labelText: 'Role'),
              items: ['admin', 'technician', 'operator'].map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
              onChanged: (v) {
                setDialogState(() => selectedRole = v!);
              },
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await DBHelper.updateUser(user.id!, {'role': selectedRole});
              if (ctx.mounted) Navigator.pop(ctx);
              _loadUsers();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showCreateUserDialog() {
    final formKey = GlobalKey<FormState>();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final fullNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedRole = 'technician';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New User'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: fullNameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: usernameCtrl,
                      decoration: const InputDecoration(labelText: 'Username *', prefixIcon: Icon(Icons.account_circle_outlined)),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password *', prefixIcon: Icon(Icons.lock_outline)),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 4) return 'Min 4 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role *', prefixIcon: Icon(Icons.shield_outlined)),
                      items: ['admin', 'technician', 'operator'].map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                      onChanged: (v) {
                        setDialogState(() => selectedRole = v!);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Create User'),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              // Check unique username
              final exists = await DBHelper.usernameExists(usernameCtrl.text.trim());
              if (exists) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Username already exists'), backgroundColor: AppTheme.error),
                  );
                }
                return;
              }
              await DBHelper.insertUser({
                'username': usernameCtrl.text.trim(),
                'password': _hashPassword(passwordCtrl.text.trim()),
                'fullName': fullNameCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'role': selectedRole,
                'createdAt': DateTime.now().toIso8601String(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _loadUsers();
            },
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return AppTheme.cardPurple;
      case 'operator':
        return AppTheme.cardOrange;
      default:
        return AppTheme.cardBlue;
    }
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
                    Text('User Management', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    SizedBox(height: 4),
                    Text('Manage system users and roles', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showCreateUserDialog,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Create User'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: SizedBox(
                          width: double.infinity,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('ID')),
                              DataColumn(label: Text('Full Name')),
                              DataColumn(label: Text('Username')),
                              DataColumn(label: Text('Phone')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Created')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: _users.map((u) {
                              return DataRow(cells: [
                                DataCell(Text('#${u.id}')),
                                DataCell(Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w500))),
                                DataCell(Text(u.username)),
                                DataCell(Text(u.phone)),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _roleColor(u.role).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      u.role.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _roleColor(u.role),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text((u.createdAt ?? '').length >= 10 ? u.createdAt!.substring(0, 10) : '')),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (u.id != 1) ...[
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.cardBlue),
                                        tooltip: 'Edit Role',
                                        onPressed: () => _editRole(u),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                                        tooltip: 'Delete',
                                        onPressed: () => _deleteUser(u.id!),
                                      ),
                                    ],
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
