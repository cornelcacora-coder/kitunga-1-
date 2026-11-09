import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/mobile/components/form_styles/form_styles.dart';

/// Changement du mot de passe, pour tous les comptes (client, vendeur,
/// livreur, commercial). Le mot de passe actuel est vérifié (Firebase exige
/// une connexion récente) ; rien n'est changé tant que la confirmation ne
/// correspond pas, et le succès n'est annoncé que s'il a vraiment eu lieu.

/// Tests : remplace Firebase. Renvoie null si réussi, sinon le code d'erreur.
Future<String?> Function(String current, String next)? changePasswordOverride;

Future<String?> _change(String current, String next) async {
  if (changePasswordOverride != null) {
    return changePasswordOverride!(current, next);
  }
  final user = FirebaseAuth.instance.currentUser;
  final email = user?.email;
  if (user == null || email == null) return 'no-user';
  try {
    await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: current));
    await user.updatePassword(next);
    return null;
  } on FirebaseAuthException catch (e) {
    return e.code;
  } catch (_) {
    return 'network-request-failed';
  }
}

String _message(String code) => switch (code) {
      'wrong-password' || 'invalid-credential' || 'invalid-login-credentials' =>
        'Mot de passe actuel incorrect.',
      'weak-password' => 'Nouveau mot de passe trop faible (6 caractères au '
          'moins, mélangez lettres et chiffres).',
      'too-many-requests' =>
        'Trop d\'essais. Patientez quelques minutes puis réessayez.',
      'network-request-failed' => 'Connexion impossible. Réessayez.',
      'no-user' => 'Reconnectez-vous puis réessayez.',
      _ => 'Le mot de passe n\'a pas pu être changé. Réessayez.',
    };

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final code = await _change(_current.text, _next.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (code != null) {
      setState(() => _error = _message(code));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Mot de passe modifié. Utilisez-le à votre '
            'prochaine connexion.')));
    Navigator.of(context).pop(true);
  }

  Widget _field(TextEditingController c, String label, String hint,
      String? Function(String?) validator) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KitungaFieldLabel(label),
        TextFormField(
          controller: c,
          obscureText: !_show,
          enabled: !_busy,
          validator: validator,
          style: GoogleFonts.inter(color: theme.primaryText, fontSize: 15.0),
          decoration: kitungaInputDecoration(
            context,
            hint,
            Icons.lock_outline_rounded,
            suffix: IconButton(
              tooltip: _show ? 'Masquer' : 'Afficher',
              icon: Icon(_show
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () => setState(() => _show = !_show),
            ),
          ),
        ),
        const SizedBox(height: 16.0),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.secondaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0.0,
        iconTheme: IconThemeData(color: theme.primaryText),
        title: Text('Changer le mot de passe',
            style: GoogleFonts.interTight(
                color: theme.primaryText,
                fontSize: 19.0,
                fontWeight: FontWeight.w800)),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 32.0),
          children: [
            _field(_current, 'Mot de passe actuel', 'Votre mot de passe',
                (v) => (v ?? '').isEmpty ? 'Saisissez votre mot de passe.' : null),
            _field(_next, 'Nouveau mot de passe', '6 caractères au moins',
                (v) {
              final s = v ?? '';
              if (s.length < 6) return '6 caractères au moins.';
              if (s == _current.text) {
                return 'Choisissez un mot de passe différent de l\'actuel.';
              }
              return null;
            }),
            _field(_confirm, 'Confirmer le nouveau mot de passe',
                'Le même mot de passe', (v) {
              return v != _next.text
                  ? 'Les deux mots de passe ne correspondent pas.'
                  : null;
            }),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(_error!,
                    style: GoogleFonts.inter(
                        color: theme.error, fontWeight: FontWeight.w600)),
              ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.primary,
                minimumSize: const Size.fromHeight(50.0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0)),
              ),
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.0, color: Colors.white))
                  : const Text('Enregistrer le nouveau mot de passe'),
            ),
          ],
        ),
      ),
    );
  }
}
