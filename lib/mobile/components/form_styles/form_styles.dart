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
  OutlineInputBorder border(Color c, [double w = 1.0]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(color: theme.hint, fontSize: 15.0),
    prefixIcon: Icon(icon, color: theme.secondaryText, size: 22.0),
    suffixIcon: suffix,
    filled: true,
    fillColor: theme.primaryBackground,
    contentPadding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
    enabledBorder: border(Colors.transparent),
    focusedBorder: border(theme.primary, 1.5),
    errorBorder: border(theme.error),
    focusedErrorBorder: border(theme.error, 1.5),
  );
}

/// Libellé affiché au-dessus d'un champ.
class KitungaFieldLabel extends StatelessWidget {
  const KitungaFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: 8.0),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: FlutterFlowTheme.of(context).primaryText,
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

/// Bouton principal plein (avec indicateur de chargement).
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
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      height: 56.0,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primary,
          disabledBackgroundColor: theme.primary.withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          elevation: 0.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
        ),
        child: loading
            ? SizedBox(
                width: 22.0,
                height: 22.0,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Text(
                text,
                style: GoogleFonts.interTight(
                  color: Colors.white,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
