import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Style commun des champs des formulaires (connexion, inscription…).
InputDecoration kitungaInputDecoration(
  BuildContext context,
  String hint,
  IconData icon, {
  Widget? suffix,
}) {
  final theme = FlutterFlowTheme.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  OutlineInputBorder border(Color c, [double w = 1.0]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(22.0),
        borderSide: BorderSide(color: c, width: w),
      );

  final baseBorderColor = isDark ? const Color(0xFF2C3238) : const Color(0xFFE2E8F0);
  final bgColor = isDark ? const Color(0xFF1E242B) : const Color(0xFFF8FAFC);

  return InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(
      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
      fontSize: 14.5,
    ),
    prefixIcon: Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 12.0),
      child: Icon(
        icon,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        size: 20.0,
      ),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
    suffixIcon: suffix,
    filled: true,
    fillColor: bgColor,
    contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 18.0),
    enabledBorder: border(baseBorderColor, 1.0),
    focusedBorder: border(const Color(0xFFE51A1A), 1.5),
    errorBorder: border(theme.error, 1.0),
    focusedErrorBorder: border(theme.error, 1.5),
  );
}

/// Libellé affiché au-dessus d'un champ.
class KitungaFieldLabel extends StatelessWidget {
  const KitungaFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
        child: Text(
          text,
          style: GoogleFonts.interTight(
            color: FlutterFlowTheme.of(context).primaryText,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

/// Bouton principal rouge avec dégradé et ombre douce.
class KitungaPrimaryButton extends StatelessWidget {
  const KitungaPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26.0),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE51A1A),
            Color(0xFFC70000),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x35E51A1A),
            blurRadius: 14.0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26.0),
          onTap: loading ? null : onPressed,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22.0,
                    height: 22.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    text,
                    style: GoogleFonts.interTight(
                      color: Colors.white,
                      fontSize: 16.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Séparateur ornemental avec sac de shopping (─── 🛍️ ───).
class KitungaOrnamentDivider extends StatelessWidget {
  const KitungaOrnamentDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 50.0,
          height: 1.2,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0x00E51A1A), Color(0xFFE51A1A)],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.0),
          child: Icon(
            Icons.shopping_bag_rounded,
            color: Color(0xFFE51A1A),
            size: 18.0,
          ),
        ),
        Container(
          width: 50.0,
          height: 1.2,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE51A1A), Color(0x00E51A1A)],
            ),
          ),
        ),
      ],
    );
  }
}

/// Peintre d'arrière-plan signature Kitunga (vagues fluides rouges, cercles doux et filigrane chariot).
class KitungaAuthBackgroundPainter extends CustomPainter {
  final bool isDark;
  const KitungaAuthBackgroundPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (isDark) return;

    // 1. Cercles doux décoratifs en haut à gauche
    final bubblePaint1 = Paint()
      ..color = const Color(0x15E51A1A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.10, 85.0), 42.0, bubblePaint1);

    final bubblePaint2 = Paint()
      ..color = const Color(0x0BE51A1A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.04, 45.0), 28.0, bubblePaint2);

    // 2. Vague fluide rouge en haut à droite
    final topWavePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color(0xFFD00D0D),
          Color(0xFFE51A1A),
          Color(0xFFFF4D4D),
        ],
      ).createShader(Rect.fromLTWH(size.width * 0.55, 0, size.width * 0.45, 140));

    final topPath = Path();
    topPath.moveTo(size.width * 0.60, 0);
    topPath.lineTo(size.width, 0);
    topPath.lineTo(size.width, 115);
    topPath.cubicTo(
      size.width * 0.88,
      105,
      size.width * 0.75,
      60,
      size.width * 0.60,
      0,
    );
    topPath.close();
    canvas.drawPath(topPath, topWavePaint);

    // 3. Filigrane chariot discret au centre-droit
    final cartPaint = Paint()
      ..color = const Color(0x0EE51A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final cartPath = Path();
    final cx = size.width * 0.84;
    final cy = size.height * 0.32;
    cartPath.moveTo(cx - 30, cy - 25);
    cartPath.lineTo(cx - 20, cy - 25);
    cartPath.lineTo(cx - 5, cy + 10);
    cartPath.lineTo(cx + 35, cy + 10);
    cartPath.lineTo(cx + 45, cy - 15);
    cartPath.lineTo(cx - 10, cy - 15);
    canvas.drawPath(cartPath, cartPaint);
    canvas.drawCircle(Offset(cx + 2, cy + 20), 5.5, cartPaint);
    canvas.drawCircle(Offset(cx + 28, cy + 20), 5.5, cartPaint);

    // 4. Vague fluide rouge en bas (swoop bas-gauche et bas)
    final bottomWavePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          Color(0xFFB70000),
          Color(0xFFE51A1A),
          Color(0xFFFF3333),
        ],
      ).createShader(Rect.fromLTWH(0, size.height - 130, size.width, 130));

    final bottomPath = Path();
    bottomPath.moveTo(0, size.height);
    bottomPath.lineTo(0, size.height - 50);
    bottomPath.cubicTo(
      size.width * 0.15,
      size.height - 75,
      size.width * 0.30,
      size.height - 35,
      size.width * 0.50,
      size.height - 45,
    );
    bottomPath.cubicTo(
      size.width * 0.75,
      size.height - 58,
      size.width * 0.88,
      size.height - 18,
      size.width,
      size.height - 25,
    );
    bottomPath.lineTo(size.width, size.height);
    bottomPath.close();
    canvas.drawPath(bottomPath, bottomWavePaint);

    // Voile doux translucide rouge au-dessus de la vague du bas
    final bottomSoftPaint = Paint()
      ..color = const Color(0x18E51A1A)
      ..style = PaintingStyle.fill;
    final bottomSoftPath = Path();
    bottomSoftPath.moveTo(0, size.height);
    bottomSoftPath.lineTo(0, size.height - 70);
    bottomSoftPath.cubicTo(
      size.width * 0.20,
      size.height - 95,
      size.width * 0.35,
      size.height - 45,
      size.width * 0.55,
      size.height - 58,
    );
    bottomSoftPath.cubicTo(
      size.width * 0.80,
      size.height - 72,
      size.width * 0.90,
      size.height - 25,
      size.width,
      size.height - 35,
    );
    bottomSoftPath.lineTo(size.width, size.height);
    bottomSoftPath.close();
    canvas.drawPath(bottomSoftPath, bottomSoftPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Wrapper réutilisable qui applique l'arrière-plan signature Kitunga
class KitungaScaffoldBackground extends StatelessWidget {
  final Widget child;
  const KitungaScaffoldBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: KitungaAuthBackgroundPainter(isDark: isDark),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

