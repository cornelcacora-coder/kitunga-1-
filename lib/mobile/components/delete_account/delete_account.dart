import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/mobile/components/form_styles/form_styles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Suppression définitive du compte (exigence Google Play).
///
/// Ordre : reconnexion (Firebase exige une connexion récente), puis
/// effacement du profil et des paniers, puis suppression du compte
/// Firebase. Si la reconnexion échoue, rien n'est effacé.
Future<void> showDeleteAccountDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (_) => _DeleteAccountDialog(),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  User? get _user => FirebaseAuth.instance.currentUser;

  // Compte e-mail : mot de passe demandé. Visiteur (anonyme) : non.
  bool get _needsPassword =>
      _user?.providerData.any((p) => p.providerId == 'password') ?? false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final user = _user;
    if (user == null) return;
    if (_needsPassword && _passwordController.text.isEmpty) {
      setState(() => _error = 'Saisissez votre mot de passe pour confirmer.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_needsPassword) {
        await user.reauthenticateWithCredential(EmailAuthProvider.credential(
          email: user.email ?? '',
          password: _passwordController.text,
        ));
      }

      // Données personnelles : paniers puis profil.
      final userRef = UserRecord.collection.doc(user.uid);
      final carts =
          await CartRecord.collection.where('user_ref', isEqualTo: userRef).get();
      for (final doc in carts.docs) {
        await doc.reference.delete();
      }
      await userRef.delete();

      await user.delete();

      if (!mounted) return;
      // Récupérés avant de fermer la fenêtre (son contexte disparaît ensuite).
      final router = GoRouter.of(context);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      router.clearRedirectLocation();
      router.goNamed(IntroWidget.routeName);
      messenger.showSnackBar(
        SnackBar(content: Text('Votre compte a été supprimé.')),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = switch (e.code) {
            'wrong-password' ||
            'invalid-credential' =>
              'Mot de passe incorrect.',
            'requires-recent-login' =>
              'Par sécurité, déconnectez-vous puis reconnectez-vous avant de supprimer votre compte.',
            'network-request-failed' =>
              'Pas de connexion internet. Réessayez.',
            _ => 'Impossible de supprimer le compte. Réessayez plus tard.',
          });
    } catch (_) {
      setState(() =>
          _error = 'Impossible de supprimer le compte. Réessayez plus tard.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return AlertDialog(
      backgroundColor: theme.secondaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      title: Text(
        'Supprimer mon compte',
        style: GoogleFonts.interTight(
          color: theme.primaryText,
          fontSize: 20.0,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cette action est définitive. Votre profil, vos coordonnées, votre photo et vos paniers seront effacés, et vous ne pourrez plus vous connecter avec ce compte.',
              style: GoogleFonts.inter(
                color: theme.secondaryText,
                fontSize: 14.0,
                height: 1.5,
              ),
            ),
            if (_needsPassword) ...[
              SizedBox(height: 16.0),
              TextField(
                controller: _passwordController,
                obscureText: true,
                enabled: !_loading,
                style:
                    GoogleFonts.inter(color: theme.primaryText, fontSize: 15.0),
                decoration: kitungaInputDecoration(
                    context, 'Votre mot de passe', Icons.lock_outline_rounded),
              ),
            ],
            if (_error != null) ...[
              SizedBox(height: 12.0),
              Text(
                _error!,
                style: GoogleFonts.inter(color: theme.error, fontSize: 13.0),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Annuler',
            style: GoogleFonts.inter(
              color: theme.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        FilledButton(
          onPressed: _loading ? null : _delete,
          style: FilledButton.styleFrom(backgroundColor: theme.error),
          child: _loading
              ? SizedBox(
                  width: 18.0,
                  height: 18.0,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.0, color: Colors.white),
                )
              : Text(
                  'Supprimer',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }
}
