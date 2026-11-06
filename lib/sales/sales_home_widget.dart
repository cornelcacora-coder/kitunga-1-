import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

/// Accueil d'un compte Commercial : remplace l'accueil client (un commercial
/// ne commande pas). Campagnes, QR code et résultats s'ajoutent dans les
/// phases suivantes du module commercial.
class SalesHomeWidget extends StatelessWidget {
  const SalesHomeWidget({super.key});

  static const _red = Color(0xFFE51A1A);
  static const _deepRed = Color(0xFF9E0E0E);
  static const _ink = Color(0xFF17181C);
  static const _muted = Color(0xFF6B6F76);

  Future<void> _signOut(BuildContext context) async {
    GoRouter.of(context).prepareAuthEvent();
    await authManager.signOut();
    if (!context.mounted) return;
    GoRouter.of(context).clearRedirectLocation();
    context.goNamedAuth(IntroWidget.routeName, context.mounted);
  }

  @override
  Widget build(BuildContext context) {
    final uid = currentUserUid;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .doc('sales_agents/$uid')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: _red));
          }
          final agent = snapshot.data?.data();
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _header(context, agent),
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (agent == null)
                      _notice(
                        Icons.error_outline_rounded,
                        'Fiche commerciale introuvable',
                        'Votre compte n\'est pas encore relié à une fiche '
                            'commerciale. Contactez l\'administrateur Kitunga.',
                      )
                    else if (agent['status'] == 'suspended')
                      _notice(
                        Icons.pause_circle_outline_rounded,
                        'Compte suspendu',
                        'Vos liens ne rapportent plus de commission pour le '
                            'moment. Contactez l\'administrateur Kitunga.',
                      )
                    else
                      _notice(
                        Icons.campaign_outlined,
                        'Votre espace est prêt',
                        'Votre campagne, votre QR code et vos résultats '
                            's\'afficheront ici dès qu\'une campagne vous '
                            'sera affectée.',
                      ),
                    const SizedBox(height: 24.0),
                    OutlinedButton.icon(
                      onPressed: () => _signOut(context),
                      icon: const Icon(Icons.logout_rounded, size: 20.0),
                      label: Text(
                        'Se déconnecter',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _red,
                        side: const BorderSide(color: _red),
                        minimumSize: const Size.fromHeight(50.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, Map<String, dynamic>? agent) {
    final name = (agent?['display_name'] as String?) ?? '';
    final code = (agent?['agent_code'] as String?) ?? '';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_red, _deepRed],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.0)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/logo/kitunga_logo_white.png', height: 56.0),
              const SizedBox(height: 18.0),
              Text(
                'ESPACE COMMERCIAL',
                style: GoogleFonts.interTight(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                name.isEmpty ? 'Bienvenue' : name,
                style: GoogleFonts.interTight(
                  color: Colors.white,
                  fontSize: 26.0,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (code.isNotEmpty) ...[
                const SizedBox(height: 10.0),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 5.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Text(
                    code,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _notice(IconData icon, String title, String text) {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18.0,
            offset: Offset(0.0, 6.0),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _red, size: 26.0),
          const SizedBox(width: 14.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.interTight(
                    color: _ink,
                    fontSize: 16.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6.0),
                Text(
                  text,
                  style: GoogleFonts.inter(
                      color: _muted, fontSize: 13.5, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
