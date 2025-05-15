// lib/foundation/security/admin_security.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSecurity {
  static const String _adminPasswordKey = 'admin_password';
  static const String _defaultPassword = 'admin123'; // Default admin password

  // Check if the user has admin access
  Future<bool> isAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    final isAdminAuthenticated = prefs.getBool('isAdminAuthenticated') ?? false;
    return isAdminAuthenticated;
  }

  // Verify the password
  Future<bool> verifyPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPassword = prefs.getString(_adminPasswordKey) ?? _defaultPassword;
    
    if (password == storedPassword) {
      // Set admin authentication flag
      await prefs.setBool('isAdminAuthenticated', true);
      return true;
    }
    
    return false;
  }

  // Change the admin password
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (await verifyPassword(oldPassword)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_adminPasswordKey, newPassword);
      return true;
    }
    
    return false;
  }

  // Clear admin authentication
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAdminAuthenticated', false);
  }
}

// Provider for admin security
final adminSecurityProvider = Provider<AdminSecurity>((ref) {
  return AdminSecurity();
});