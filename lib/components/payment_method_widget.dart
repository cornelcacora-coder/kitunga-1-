import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/backend/server_payment.dart';
import 'payment_method_model.dart';
export 'payment_method_model.dart';

/// Opérateurs Mobile Money proposés au paiement.
const kPaymentOperators = {
  'MTN': (label: 'MTN MoMo', logo: 'assets/images/unnamed.png',
      prefixes: ['06'], hint: '06 xxx xx xx'),
  'Airtel': (label: 'Airtel Money', logo: 'assets/images/Airtel.png',
      prefixes: ['05', '04'], hint: '05 xxx xx xx'),
};

/// Remplace la réponse du serveur dans les tests.
@visibleForTesting
Future<bool> Function()? airtelAvailableOverride;

Future<bool>? _airtelAvailable;

/// Airtel Money est-il disponible ? Le serveur répond « oui » dès que les
/// clés Airtel sont installées : rien à changer dans l'application.
/// En cas de doute (hors ligne…), Airtel reste grisé.
Future<bool> kitungaAirtelAvailable() {
  if (airtelAvailableOverride != null) return airtelAvailableOverride!();
  return _airtelAvailable ??= kitungaCallFunction('kitungaPaymentOptions', {})
      .then((r) => r['airtel'] == true)
      .catchError((_) {
    _airtelAvailable = null; // nouvel essai au prochain affichage
    return false;
  });
}

/// « +242 06 123 45 67 » → « 061234567 » (numéro national à 9 chiffres).
String nationalPhone(String raw) {
  var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('00')) d = d.substring(2);
  if (d.startsWith('242') && d.length == 12) d = d.substring(3);
  if (d.length == 8) d = '0$d';
  return d;
}

/// Opérateur d'un numéro (MTN 06, Airtel 05 / 04), ou null.
String? operatorOfPhone(String raw) {
  final d = nationalPhone(raw);
  if (d.length < 2) return null;
  for (final e in kPaymentOperators.entries) {
    if (e.value.prefixes.contains(d.substring(0, 2))) return e.key;
  }
  return null;
}

/// Choix du paiement : MTN MoMo ou Airtel Money, et numéro qui paiera.
class PaymentMethodWidget extends StatefulWidget {
  const PaymentMethodWidget({
    super.key,
    bool? selected,
    this.icon,
    String? airtelNumber,
    String? mtnNumber,
    this.isMoMo,
  })  : this.selected = selected ?? true,
        this.airtelNumber = airtelNumber ?? '',
        this.mtnNumber = mtnNumber ?? '';

  final bool selected;
  final Widget? icon;
  final String airtelNumber;
  final String mtnNumber;
  final Future Function()? isMoMo;

  @override
  State<PaymentMethodWidget> createState() => _PaymentMethodWidgetState();
}

class _PaymentMethodWidgetState extends State<PaymentMethodWidget> {
  late PaymentMethodModel _model;
  bool _airtelOn = false;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PaymentMethodModel());
    _model.isMoMoValue = true;
    // Le numéro du compte décide de l'opérateur proposé d'abord.
    _model.operator = 'MTN';
    _fillPhone();
    kitungaAirtelAvailable().then((on) {
      if (!mounted || !on) return;
      setState(() {
        _airtelOn = true;
        // Le numéro du compte décide de l'opérateur proposé d'abord.
        final airtel = operatorOfPhone(widget.airtelNumber) == 'Airtel';
        final mtn = operatorOfPhone(widget.mtnNumber) == 'MTN';
        if (!mtn && airtel) {
          _model.operator = 'Airtel';
          _fillPhone();
        }
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  /// Propose le numéro connu s'il correspond à l'opérateur choisi.
  void _fillPhone() {
    final known = [widget.mtnNumber, widget.airtelNumber]
        .firstWhere((n) => operatorOfPhone(n) == _model.operator,
            orElse: () => '');
    final current = _model.phoneController.text;
    if (current.isEmpty || operatorOfPhone(current) != _model.operator) {
      _model.phoneController.text = nationalPhone(known);
    }
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  Future<void> _choose(String operator) async {
    setState(() {
      _model.operator = operator;
      _model.isMoMoValue = true;
      _fillPhone();
    });
    await widget.isMoMo?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final op = kPaymentOperators[_model.operator]!;
    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: theme.accent2, width: 1.0),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in kPaymentOperators.entries)
            _tile(context, e.key, e.value.label, e.value.logo),
          const SizedBox(height: 8.0),
          TextField(
            key: const ValueKey('payment-phone'),
            controller: _model.phoneController,
            keyboardType: TextInputType.phone,
            onChanged: (_) => _model.onUpdate(),
            decoration: InputDecoration(
              labelText: 'Numéro ${op.label} qui paiera',
              hintText: op.hint,
              prefixText: '+242 ',
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, String key, String label, String logo) {
    final theme = FlutterFlowTheme.of(context);
    final selected = _model.operator == key;
    // Airtel Money grisé tant que ses clés ne sont pas installées.
    final soon = key == 'Airtel' && !_airtelOn;
    return Opacity(
      opacity: soon ? 0.5 : 1.0,
      child: InkWell(
      key: ValueKey('payment-$key'),
      borderRadius: BorderRadius.circular(16.0),
      onTap: soon ? null : () => _choose(key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: selected ? const Color(0x1AE30613) : Colors.transparent,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Row(
          children: [
            ClipOval(
              child: Image.asset(logo,
                  width: 34.0, height: 34.0, fit: BoxFit.cover),
            ),
            const SizedBox(width: 14.0),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.interTight(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.0,
                      color: theme.primaryText)),
            ),
            if (soon)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: theme.alternate,
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Text('Bientôt disponible',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: theme.secondaryText)),
              )
            else
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? theme.primary : theme.secondaryText,
              ),
          ],
        ),
      ),
    ),
    );
  }
}
