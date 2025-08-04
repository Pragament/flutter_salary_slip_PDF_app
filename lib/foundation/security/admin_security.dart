// lib/foundation/security/admin_security.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSecurity {
  static const String _adminPasswordKey = 'admin_password';
  static const String _defaultPassword = 'admin123';
  static const String _authFlagKey = 'isAdminAuthenticated';

  // Check if the user is authenticated
  Future<bool> isAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_authFlagKey) ?? false;
  }

  // Get the current stored password
  Future<String> getStoredPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_adminPasswordKey) ?? _defaultPassword;
  }

  // Verify password and mark user as authenticated if correct
  Future<bool> verifyPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPassword = prefs.getString(_adminPasswordKey) ?? _defaultPassword;

    if (password == storedPassword) {
      await prefs.setBool(_authFlagKey, true);
      return true;
    }
    return false;
  }

  // Change password with old password check
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPassword = prefs.getString(_adminPasswordKey) ?? _defaultPassword;

    if (oldPassword == storedPassword) {
      await prefs.setString(_adminPasswordKey, newPassword);
      return true;
    }
    return false;
  }

  // Set new password directly
  Future<void> setNewPassword(String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_adminPasswordKey, newPassword);
    await prefs.setBool(_authFlagKey, false);
  }

  // Clear authentication
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authFlagKey, false);
  }
}

// Riverpod provider
final adminSecurityProvider = Provider<AdminSecurity>((ref) => AdminSecurity());