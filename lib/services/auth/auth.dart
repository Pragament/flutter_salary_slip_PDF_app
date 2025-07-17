import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail_xoauth2.dart';

class BulkEmailService {
  // Google Sign-In and Firebase Auth
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  // Send bulk emails using mailer and Gmail XOAUTH2
  Future<void> sendBulkEmails({
    required String userEmail,
    required String accessToken,
    required List<Map<String, String>> employees, // [{name, email, ...}]
  }) async {
    final smtpServer = gmailSmtpXoauth2(userEmail, accessToken);

    for (final employee in employees) {
      final message = Message()
        ..from = Address(userEmail, 'Your Name')
        ..recipients.add(employee['email']!)
        ..subject = 'Employee Details'
        ..text = 'Hello  [1m${employee['name']} [0m,\nYour details: ...';

      try {
        await send(message, smtpServer);
      } catch (e) {
        print('Failed to send to  [1m${employee['email']} [0m: $e');
      }
    }
  }

  // Helper to send emails using just UserCredential
  Future<void> sendBulkEmailsForUserCredential({
    required UserCredential userCredential,
    required List<Map<String, String>> employees,
  }) async {
    final user = userCredential.user;
    if (user == null) return;
    // Get GoogleSignInAccount from email
    final googleSignIn = GoogleSignIn();
    final googleUser = await googleSignIn.signInSilently();
    final googleAuth = await googleUser?.authentication;
    if (googleAuth == null) return;
    await sendBulkEmails(
      userEmail: user.email!,
      accessToken: googleAuth.accessToken!,
      employees: employees,
    );
  }
}
