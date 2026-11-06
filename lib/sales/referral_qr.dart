import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Adresse publique des liens commerciaux (Firebase Hosting → /r/{code}).
/// À changer si un domaine propre est relié à l'hébergement.
const kKitungaReferralBase = 'https://kitunga-xtvpe4.web.app';

/// Lien public d'un code commercial.
String kitungaReferralLink(String code) => '$kKitungaReferralBase/r/$code';

/// QR code d'un lien commercial, avec le code en clair dessous (à saisir à
/// l'inscription si le QR ne peut pas être scanné). Noir sur blanc et
/// correction d'erreur moyenne : lisible imprimé sur une affiche.
class KitungaReferralQr extends StatelessWidget {
  const KitungaReferralQr({super.key, required this.code, this.size = 220.0});

  final String code;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: kitungaReferralLink(code),
            size: size,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            semanticsLabel: 'QR code du lien Kitunga $code',
          ),
          const SizedBox(height: 10.0),
          SelectableText(
            code,
            style: GoogleFonts.interTight(
              color: const Color(0xFF17181C),
              fontSize: 20.0,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }
}
