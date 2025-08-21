import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../foundation/security/admin_security.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _showPassword = false;
  bool _changeSuccess = false;
  
  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty || 
        _newPasswordController.text.isEmpty || 
        _confirmPasswordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill all fields';
        _changeSuccess = false;
      });
      return;
    }
    
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'New passwords do not match';
        _changeSuccess = false;
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _changeSuccess = false;
    });
    
    try {
      final result = await AdminSecurity().changePassword(
        _currentPasswordController.text, 
        _newPasswordController.text
      );
      
      setState(() {
        _isLoading = false;
        if (result) {
          _changeSuccess = true;
          _errorMessage = null;
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        } else {
          _errorMessage = 'Current password is incorrect';
          _changeSuccess = false;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
        _changeSuccess = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('adminSettings'.tr()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'changeAdminPassword'.tr(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            TextField(
              controller: _currentPasswordController,
              decoration: InputDecoration(
                labelText: 'currentPassword'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _showPassword = !_showPassword;
                    });
                  },
                ),
              ),
              obscureText: !_showPassword,
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _newPasswordController,
              decoration: InputDecoration(
                labelText: 'newPassword'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_reset),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'confirmNewPassword'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                errorText: _errorMessage,
              ),
              obscureText: true,
              onSubmitted: (_) => _changePassword(),
            ),
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text('changePassword'.tr()),
              ),
            ),
            
            if (_changeSuccess) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'passwordChangedSuccess'.tr(),
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'adminInformation'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('adminInfoDescription'.tr()),
                    const SizedBox(height: 16),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.security),
                      title: Text('defaultPassword'.tr()),
                      subtitle: const Text('admin123'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.warning_amber_rounded),
                      title: Text('passwordWarning'.tr()),
                      subtitle: Text('passwordWarningDescription'.tr()),
                    ),
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