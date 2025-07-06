// lib/presentation/screens/verify_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/foundation/security/admin_security.dart';
import 'setnewpasswordscreen.dart';
import 'package:go_router/go_router.dart';

class VerifyPasswordScreen extends ConsumerStatefulWidget {
  const VerifyPasswordScreen({super.key});

  @override
  ConsumerState<VerifyPasswordScreen> createState() =>
      _VerifyPasswordScreenState();
}

class _VerifyPasswordScreenState extends ConsumerState<VerifyPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _error = false;

  Future<void> _verify() async {
    final adminSecurity = ref.read(adminSecurityProvider);
    final password = _passwordController.text.trim();

    final isValid = await adminSecurity.verifyPassword(password);

    if (isValid) {
      if (mounted) context.push('/set-new-password');
    } else {
      setState(() => _error = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Incorrect password. Please try again.'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Verify Admin Password")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text("Enter current admin password to continue."),
              SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: "Admin Password",
                    errorText: _error ? "Incorrect password" : null),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _verify,
                child: Text("Next"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}