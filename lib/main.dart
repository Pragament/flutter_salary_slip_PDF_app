import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail_xoauth2.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'flavors/flavor_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const flavor = String.fromEnvironment("flavor", defaultValue: "dev");
  await dotenv.load(fileName: getEnvFileName(flavor));
  FlavorConfig.initialize(flavorString: flavor);
  await Firebase.initializeApp();
  runApp(MySignInGate());
}

String getEnvFileName(String flavor) {
  switch (flavor) {
    case "prod":
      return ".env";
    case "qa":
      return ".env.qa";
    default:
      return ".env.dev";
  }
}

class MySignInGate extends StatefulWidget {
  @override
  State<MySignInGate> createState() => _MySignInGateState();
}

class _MySignInGateState extends State<MySignInGate> {
  User? _user;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
  }

  Future<void> _signInWithGoogleAndSendEmail() async {
    setState(() { _loading = true; _error = null; });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() { _loading = false; });
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      setState(() { _user = userCredential.user; });
      // Send email to the signed-in user
      final smtpServer = gmailSmtpXoauth2(_user!.email!, googleAuth.accessToken!);
      final message = Message()
        ..from = Address(_user!.email!, _user!.displayName ?? 'User')
        ..recipients.add(_user!.email!)
        ..subject = 'Welcome to the App!'
        ..text = 'Hello ${_user!.displayName ?? _user!.email},\nThis is your account details email.';
      await send(message, smtpServer);
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user != null) {
      // User is signed in, show the main app
      return Builder(
        builder: (context) {
          startApp();
          return const SizedBox.shrink();
        },
      );
    }
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Sign in to Continue')),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('Sign in with Google'),
                      onPressed: _signInWithGoogleAndSendEmail,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
