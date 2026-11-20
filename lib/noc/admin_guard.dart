import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rxdart/rxdart.dart';

import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/noc/ui/admin_kit.dart' show AdminThemeScope;

/// N'affiche [child] qu'à un compte dont le rôle est Admin. Le rôle est relu
/// dans Firestore, y compris à l'ouverture directe d'une adresse sur le web.
/// Cet écran protège l'interface : la protection des données reste assurée
/// par les règles Firestore.
class KitungaAdminGuard extends StatefulWidget {
  const KitungaAdminGuard(
      {super.key, required this.child, this.roles = const ['Admin']});

  final Widget child;

  /// Rôles autorisés (l'espace support accepte aussi « Support »).
  final List<String> roles;

  @override
  State<KitungaAdminGuard> createState() => _KitungaAdminGuardState();
}

class _KitungaAdminGuardState extends State<KitungaAdminGuard> {
  late final Stream<UserRecord?> _account = FirebaseAuth.instance
      .authStateChanges()
      .switchMap<UserRecord?>((user) => user == null
          ? Stream.value(null)
          : UserRecord.getDocument(UserRecord.collection.doc(user.uid)));

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return StreamBuilder<UserRecord?>(
      stream: _account,
      builder: (context, snapshot) {
        if (snapshot.hasData && widget.roles.contains(snapshot.data?.role)) {
          // Charte admin pour la page et les fenêtres qu'elle ouvre.
          return AdminThemeScope(child: widget.child);
        }
        final waiting = !snapshot.hasError &&
            snapshot.connectionState == ConnectionState.waiting;
        return Scaffold(
          backgroundColor: theme.primaryBackground,
          body: Center(
            child: waiting
                ? CircularProgressIndicator(color: theme.primary)
                : Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            size: 48.0, color: theme.secondaryText),
                        const SizedBox(height: 16.0),
                        Text(
                          'Accès réservé aux administrateurs',
                          textAlign: TextAlign.center,
                          style: theme.titleMedium,
                        ),
                        const SizedBox(height: 16.0),
                        TextButton(
                          onPressed: () => context.go('/'),
                          child: const Text('Retour à l\'accueil'),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}
