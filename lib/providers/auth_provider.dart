import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  static const String _userIdKey = 'logged_in_user_id';

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  String? get error => _error;
  bool get isAdmin => _currentUser?.role == 'admin';

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// Try to restore session from saved preferences
  Future<bool> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt(_userIdKey);
      if (userId == null) return false;

      final userData = await DBHelper.getUserById(userId);
      if (userData != null) {
        _currentUser = UserModel.fromMap(userData);
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final hashedPassword = _hashPassword(password);
      final userData = await DBHelper.getUser(username, hashedPassword);

      if (userData != null) {
        _currentUser = UserModel.fromMap(userData);
        // Save session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_userIdKey, _currentUser!.id!);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Invalid username or password';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Login failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signup({
    required String username,
    required String password,
    required String fullName,
    required String phone,
    String? role,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final exists = await DBHelper.usernameExists(username);
      if (exists) {
        _error = 'Username already exists';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final userCount = await DBHelper.getUserCount();
      final assignedRole = userCount == 0 ? 'admin' : (role ?? 'technician');

      final hashedPassword = _hashPassword(password);
      final user = UserModel(
        username: username,
        password: hashedPassword,
        fullName: fullName,
        role: assignedRole,
        phone: phone,
        createdAt: DateTime.now().toIso8601String(),
      );

      final id = await DBHelper.insertUser(user.toMap());
      _currentUser = UserModel(
        id: id,
        username: user.username,
        password: user.password,
        fullName: user.fullName,
        role: user.role,
        phone: user.phone,
        createdAt: user.createdAt,
      );

      // Save session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_userIdKey, id);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Signup failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword({
    required String username,
    required String phone,
    required String newPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userData = await DBHelper.getUserByUsername(username);
      if (userData == null) {
        _error = 'Invalid username or phone number';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final storedPhone = userData['phone'] as String?;
      if (storedPhone == null || storedPhone.trim().isEmpty) {
        _error = 'No registered phone number found for this user. Please contact the Administrator.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (storedPhone.trim() != phone.trim()) {
        _error = 'Invalid username or phone number';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final hashedPassword = _hashPassword(newPassword);
      final id = userData['id'] as int;
      await DBHelper.updateUser(id, {'password': hashedPassword});

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Password reset failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    _currentUser = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
