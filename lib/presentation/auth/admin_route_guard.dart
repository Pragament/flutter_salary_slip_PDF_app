import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../foundation/security/admin_security.dart';

class AdminLockScreen extends ConsumerStatefulWidget {
  final Widget child;
  final String? redirectPath;

  const AdminLockScreen({
    super.key,
    required this.child,
    this.redirectPath,
  });

  @override
  ConsumerState<AdminLockScreen> createState() => _AdminLockScreenState();
}

class _AdminLockScreenState extends ConsumerState<AdminLockScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _showPassword = false;
  bool _authenticated = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isValid = await AdminSecurity().verifyPassword(_passwordController.text);

      if (isValid) {
        if (widget.redirectPath != null && context.mounted) {
          // If redirectPath is provided, use it
          context.go(widget.redirectPath!);
        } else {
          // Otherwise, show the child directly
          setState(() {
            _authenticated = true;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid password';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If authenticated and no redirectPath, display the child widget directly
    if (_authenticated && widget.redirectPath == null) {
      return widget.child;
    }
    
    // Otherwise, show the login screen
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Access'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.admin_panel_settings,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Admin Authentication Required',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please enter your admin password to continue',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  errorText: _errorMessage,
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
                onSubmitted: (_) => _authenticate(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _authenticate,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Login'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}