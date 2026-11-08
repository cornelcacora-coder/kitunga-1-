import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

/// Page de connexion du centre d'administration (adresse /admin).
class AdminLoginWidget extends StatefulWidget {
  const AdminLoginWidget({super.key});

  static String routeName = 'AdminLogin';
  static String routePath = '/admin';

  @override
  State<AdminLoginWidget> createState() => _AdminLoginWidgetState();
}

class _AdminLoginWidgetState extends State<AdminLoginWidget> {
  static const _red = Color(0xFFE51A1A);
  static const _deepRed = Color(0xFF9E0E0E);
  static const _ink = Color(0xFF17181C);
  static const _muted = Color(0xFF6B6F76);
  static const _field = Color(0xFFF4F4F6);

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Rôle relu dans Firestore : juste après la connexion, le profil gardé en
  /// mémoire n'est pas forcément encore chargé.
  Future<bool> _isAdminAccount(String? uid) async {
    if (uid == null) return false;
    try {
      final profile =
          await UserRecord.getDocumentOnce(UserRecord.collection.doc(uid));
      return profile.role == 'Admin';
    } catch (_) {
      return false;
    }
  }

  Future<void> _signIn() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      GoRouter.of(context).prepareAuthEvent();
      final user = await authManager.signInWithEmail(
        context,
        _email.text.trim(),
        _password.text,
      );
      if (user == null || !mounted) return;

      if (await _isAdminAccount(user.uid)) {
        if (mounted) {
          context.goNamedAuth(
              AdminDashboardWidget.routeName, context.mounted);
        }
        return;
      }
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Accès refusé'),
          content: const Text(
              'Ce compte ne dispose pas d\'un accès administrateur.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      // Un compte refusé ne reste pas connecté.
      if (mounted) GoRouter.of(context).prepareAuthEvent();
      await authManager.signOut();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_red, _deepRed],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, screen) => SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: screen.maxHeight - 32.0),
                child: Center(
                  child: screen.maxWidth >= 912.0
                      ? _wideCard()
                      : _narrowCard(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardFrame({required Widget child, double? width, double? height}) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 40.0,
            offset: Offset(0.0, 18.0),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _wideCard() {
    return _cardFrame(
      width: 880.0,
      height: 540.0,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _WidePanelPainter())),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 11,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(44.0, 36.0, 90.0, 0.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _logo(96.0),
                      const SizedBox(height: 18.0),
                      _welcome(32.0),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 10,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0.0, 44.0, 0.0),
                  child: Center(child: _form()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _narrowCard() {
    return _cardFrame(
      width: 440.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 250.0,
            child: Stack(
              children: [
                Positioned.fill(
                    child: CustomPaint(painter: _NarrowPanelPainter())),
                Padding(
                  padding: const EdgeInsets.fromLTRB(26.0, 24.0, 26.0, 0.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _logo(74.0),
                      const SizedBox(height: 8.0),
                      _welcome(26.0),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26.0, 12.0, 26.0, 28.0),
            child: _form(),
          ),
        ],
      ),
    );
  }

  /// Logo blanc dessiné directement sur le rouge, avec une ombre douce.
  Widget _logo(double height) {
    const asset = 'assets/logo/kitunga_logo_white.png';
    return SizedBox(
      height: height + 8.0,
      child: Stack(
        children: [
          Transform.translate(
            offset: const Offset(0.0, 4.0),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
              child: Image.asset(
                asset,
                height: height,
                color: const Color(0x47000000),
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
          ),
          Image.asset(asset, height: height),
        ],
      ),
    );
  }

  Widget _welcome(double titleSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BIENVENUE',
          style: GoogleFonts.interTight(
            color: Colors.white,
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          'CENTRE DES OPÉRATIONS',
          style: GoogleFonts.interTight(
            color: Colors.white,
            fontSize: 14.0,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10.0),
        Text(
          'Commandes, livraisons et partenaires\nKitunga, au même endroit.',
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 12.5,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldStyle(String label, IconData icon, {Widget? trailing}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      hintText: label,
      hintStyle: GoogleFonts.inter(color: _muted, fontSize: 14.0),
      prefixIcon: Icon(icon, color: _ink, size: 20.0),
      suffixIcon: trailing,
      filled: true,
      fillColor: _field,
      contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: _red, width: 1.5),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: _deepRed, width: 1.0),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: _deepRed, width: 1.5),
      ),
    );
  }

  Widget _form() {
    final inputStyle = GoogleFonts.inter(color: _ink, fontSize: 14.0);
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Connexion',
              style: GoogleFonts.interTight(
                color: _ink,
                fontSize: 28.0,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              'Accès réservé aux administrateurs Kitunga',
              style: GoogleFonts.inter(color: _muted, fontSize: 13.0),
            ),
            const SizedBox(height: 26.0),
            TextFormField(
              controller: _email,
              style: inputStyle,
              cursorColor: _red,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration:
                  _fieldStyle('Adresse e-mail', Icons.person_rounded),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Saisissez votre adresse e-mail'
                  : null,
            ),
            const SizedBox(height: 14.0),
            TextFormField(
              controller: _password,
              style: inputStyle,
              cursorColor: _red,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _signIn(),
              decoration: _fieldStyle(
                'Mot de passe',
                Icons.lock_rounded,
                trailing: Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                    style: TextButton.styleFrom(foregroundColor: _red),
                    child: Text(
                      _hidePassword ? 'AFFICHER' : 'MASQUER',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Saisissez votre mot de passe'
                  : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    context.pushNamed(ForgotPasswordWidget.routeName),
                style: TextButton.styleFrom(foregroundColor: _red),
                child: Text(
                  'Mot de passe oublié ?',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8.0),
            SizedBox(
              height: 52.0,
              child: ElevatedButton(
                onPressed: _loading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  disabledBackgroundColor: _red.withValues(alpha: 0.6),
                  foregroundColor: Colors.white,
                  elevation: 0.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22.0,
                        height: 22.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Se connecter',
                        style: GoogleFonts.interTight(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Paint _redFill(Rect area, List<Color> colors) => Paint()
  ..shader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: colors,
  ).createShader(area);

/// Formes rouges de la carte large : grand disque, disque d'angle et sphère.
class _WidePanelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const main = [Color(0xFFEE2A2A), Color(0xFFC21212)];
    const deep = [Color(0xFFD01515), Color(0xFF960C0C)];
    const light = [Color(0xFFF24A4A), Color(0xFFB81010)];

    void disc(Offset c, double r, List<Color> colors) => canvas.drawCircle(
        c, r, _redFill(Rect.fromCircle(center: c, radius: r), colors));

    disc(Offset(w * 0.19, h * 0.20), h * 0.52, main);
    disc(Offset(w * 0.02, h * 1.02), h * 0.34, deep);
    canvas.drawCircle(
      Offset(w * 0.335, h * 0.775),
      h * 0.205,
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16.0),
    );
    disc(Offset(w * 0.33, h * 0.76), h * 0.20, light);
    disc(Offset(w * 1.0, h * 1.0), h * 0.17, main);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bandeau rouge arrondi de la carte étroite (téléphone).
class _NarrowPanelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final area = Offset.zero & size;
    final curve = Path()
      ..lineTo(w, 0.0)
      ..lineTo(w, h * 0.68)
      ..quadraticBezierTo(w * 0.55, h * 1.12, 0.0, h * 0.92)
      ..close();
    canvas.drawPath(
      curve,
      _redFill(area, const [Color(0xFFEE2A2A), Color(0xFFC21212)]),
    );
    final c = Offset(w * 0.90, h * 0.16);
    canvas.drawCircle(
      c,
      h * 0.26,
      _redFill(Rect.fromCircle(center: c, radius: h * 0.26),
          const [Color(0xFFF24A4A), Color(0xFFB81010)]),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
