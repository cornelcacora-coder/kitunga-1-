import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Coordonnées de l'entreprise qui édite Kitunga (NTEMO CONSULTING), pour
/// que les clients, vendeurs et livreurs puissent la joindre.
const kCompanyName = 'NTEMO CONSULTING';
const kCompanyAddress = 'Brazzaville, République du Congo';
const kCompanyEmail = 'contact@ntemoconsulting.com';
const kCompanyWebsite = 'https://ntemoconsulting.com';
const kCompanyHours = 'Du lundi au samedi, 8h - 18h';

/// Numéros (appel et WhatsApp), au format national.
const kCompanyPhones = ['064313808', '050195768'];

/// « 064313808 » → « +242 06 431 38 08 ».
String companyPhoneLabel(String n) =>
    '+242 ${n.substring(0, 2)} ${n.substring(2, 5)} ${n.substring(5, 7)} '
    '${n.substring(7)}';

String _tel(String n) => 'tel:+242$n';
String _whatsapp(String n) =>
    'https://wa.me/242$n?text=${Uri.encodeComponent('Bonjour Kitunga, ')}';

/// Carte « Nous contacter » : téléphone, WhatsApp, e-mail, site web.
class KitungaContactCard extends StatelessWidget {
  const KitungaContactCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final text = GoogleFonts.inter(color: theme.primaryText, fontSize: 14.5);
    Widget action(IconData icon, String label, String url, Color color) =>
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.0)),
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          ),
          onPressed: () => launchURL(url),
          icon: Icon(icon, size: 18.0),
          label: Text(label,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        );
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kCompanyName,
              style: GoogleFonts.interTight(
                  color: theme.primaryText,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2.0),
          Text('$kCompanyAddress\n$kCompanyHours',
              style: GoogleFonts.inter(
                  color: theme.secondaryText, fontSize: 13.0)),
          for (final n in kCompanyPhones) ...[
            const SizedBox(height: 12.0),
            Text(companyPhoneLabel(n),
                style: text.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6.0),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                action(Icons.call_rounded, 'Appeler', _tel(n), theme.primary),
                action(Icons.chat_rounded, 'WhatsApp', _whatsapp(n),
                    const Color(0xFF1FA855)),
              ],
            ),
          ],
          const SizedBox(height: 14.0),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              action(
                  Icons.mail_outline_rounded,
                  kCompanyEmail,
                  Uri(
                    scheme: 'mailto',
                    path: kCompanyEmail,
                    query:
                        'subject=${Uri.encodeComponent('Assistance Kitunga')}',
                  ).toString(),
                  theme.primaryText),
              action(Icons.language_rounded, 'ntemoconsulting.com',
                  kCompanyWebsite, theme.primaryText),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fenêtre « Nous contacter » (centre d'aide).
Future<void> showKitungaContact(BuildContext context) {
  final theme = FlutterFlowTheme.of(context);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.primaryBackground,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0))),
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20.0, 18.0, 20.0, 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nous contacter',
                style: GoogleFonts.interTight(
                    color: theme.primaryText,
                    fontSize: 20.0,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4.0),
            Text(
                'Une question sur une commande, un paiement ou votre compte ? '
                'Appelez-nous ou écrivez-nous sur WhatsApp.',
                style: GoogleFonts.inter(
                    color: theme.secondaryText, fontSize: 13.5)),
            const SizedBox(height: 14.0),
            const KitungaContactCard(),
          ],
        ),
      ),
    ),
  );
}
