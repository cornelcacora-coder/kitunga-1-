import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';

const _red = Color(0xFFE51A1A);

/// Le compte se connecte avec e-mail et mot de passe (sinon : Google…).
bool kitungaHasPasswordLogin() =>
    FirebaseAuth.instance.currentUser?.providerData
        .any((p) => p.providerId == 'password') ??
    false;

/// Après confirmation du lien reçu, l'e-mail de connexion change : le profil
/// (User.email) est remis à jour à la connexion suivante.
Future<void> kitungaSyncEmail() async {
  final user = FirebaseAuth.instance.currentUser;
  final ref = currentUserReference;
  final email = user?.email;
  if (user == null || ref == null || email == null || email.isEmpty) return;
  try {
    final doc = await ref.get();
    final data = doc.data() as Map<String, dynamic>?;
    if (doc.exists && data?['email'] != email) {
      await ref.update({'email': email});
    }
  } catch (_) {}
}

/// Tests : remplace Firebase. Renvoie null si réussi, sinon le code d'erreur.
@visibleForTesting
Future<String?> Function(String password, String email)? changeEmailOverride;

Future<String?> _change(String password, String next) async {
  if (changeEmailOverride != null) return changeEmailOverride!(password, next);
  final user = FirebaseAuth.instance.currentUser;
  final email = user?.email;
  if (user == null || email == null) return 'no-user';
  try {
    await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password));
    // Firebase envoie un lien à la nouvelle adresse ; l'e-mail ne change
    // qu'une fois ce lien ouvert (l'adresse doit vraiment exister).
    await user.verifyBeforeUpdateEmail(next);
    return null;
  } on FirebaseAuthException catch (e) {
    return e.code;
  } catch (_) {
    return 'network-request-failed';
  }
}

String _message(String code) => switch (code) {
      'wrong-password' || 'invalid-credential' || 'invalid-login-credentials' =>
        'Mot de passe incorrect.',
      'invalid-email' => 'Adresse e-mail invalide.',
      'email-already-in-use' => 'Cette adresse est déjà utilisée par un autre '
          'compte.',
      'too-many-requests' =>
        'Trop d\'essais. Patientez quelques minutes puis réessayez.',
      'network-request-failed' => 'Connexion impossible. Réessayez.',
      'no-user' => 'Reconnectez-vous puis réessayez.',
      _ => 'L\'adresse n\'a pas pu être changée. Réessayez.',
    };

/// Changement de l'adresse e-mail de connexion.
class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({super.key});

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String? _error;
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final next = _email.text.trim();
    final code = await _change(_password.text, next);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (code == null) {
        _sentTo = next;
      } else {
        _error = _message(code);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    InputDecoration deco(String label, IconData icon, {Widget? suffix}) =>
        InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: theme.secondaryText),
          suffixIcon: suffix,
          filled: true,
          fillColor: theme.secondaryBackground,
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.alternate)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _red, width: 1.4)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        );
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.primaryText),
        title: Text('Changer l\'e-mail',
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.primaryText)),
      ),
      body: _sentTo != null
          ? ListView(padding: const EdgeInsets.all(24), children: [
              const Icon(Icons.mark_email_read_rounded,
                  size: 64, color: Color(0xFF1E9E5A)),
              const SizedBox(height: 16),
              Text('Vérifiez votre nouvelle adresse',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryText)),
              const SizedBox(height: 8),
              Text(
                  'Un lien a été envoyé à $_sentTo. Ouvrez-le pour confirmer : '
                  'votre e-mail de connexion changera ensuite, et il faudra '
                  'vous reconnecter avec la nouvelle adresse.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 14.5, height: 1.45, color: theme.secondaryText)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                    backgroundColor: _red,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: const Text('Compris'),
              ),
            ])
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Adresse actuelle : ${currentUserEmail.isEmpty ? '—' : currentUserEmail}',
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: theme.secondaryText)),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('new-email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration:
                        deco('Nouvelle adresse e-mail', Icons.mail_outline),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                        return 'Adresse e-mail invalide.';
                      }
                      if (t.toLowerCase() == currentUserEmail.toLowerCase()) {
                        return 'C\'est déjà votre adresse.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('email-password'),
                    controller: _password,
                    obscureText: !_show,
                    decoration: deco('Mot de passe actuel', Icons.lock_outline,
                        suffix: IconButton(
                          tooltip: _show ? 'Masquer' : 'Afficher',
                          icon: Icon(_show
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(() => _show = !_show),
                        )),
                    validator: (v) => (v ?? '').isEmpty
                        ? 'Indiquez votre mot de passe.'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: GoogleFonts.poppins(
                            color: _red, fontWeight: FontWeight.w500)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: _red,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : Text('Envoyer le lien de confirmation',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
    );
  }
}
