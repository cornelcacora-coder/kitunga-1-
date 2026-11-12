import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/server_payment.dart';
import '/backend/subscription.dart' show kSubscriptionPlans;
import '/components/payment_method_widget.dart'
    show kPaymentOperators, operatorOfPhone;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Module « Mon abonnement » du client : état, formules (Trimestriel 300 F,
/// Semestriel 500 F,
/// Annuel 1000 F), paiement MTN MoMo ou Airtel Money, historique. Accessible à tout moment
/// depuis le profil (fonctions kitungaMySubscription, kitungaStartSubscription,
/// kitungaConfirmSubscription).

/// Tests : remplace le serveur.
Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data)?
    subscriptionBackendOverride;

/// Tests : délai entre deux vérifications du paiement.
Duration subscriptionPollDelay = const Duration(seconds: 5);

Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) =>
    subscriptionBackendOverride != null
        ? subscriptionBackendOverride!(name, data)
        : kitungaCallFunction(name, data);

String _day(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  return d == null ? '' : dateTimeFormat('d MMMM y', d);
}

/// « Trimestriel · 3 mois »… d'après les formules de l'application.
String planDisplayName(String key) {
  for (final p in kSubscriptionPlans) {
    if (p.key == key) return '${p.name} · ${p.duration}';
  }
  return key;
}

/// Ouvre le module (depuis le profil, ou quand une commande est refusée).
void openMySubscription(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => const MySubscriptionPage()));

class MySubscriptionPage extends StatefulWidget {
  const MySubscriptionPage(
      {super.key, this.fromSignup = false, this.initialPlan, this.phone});

  /// Dernière étape de l'inscription : bouton « Payer plus tard ».
  final bool fromSignup;
  final String? initialPlan;
  final String? phone;

  @override
  State<MySubscriptionPage> createState() => _MySubscriptionPageState();
}

class _MySubscriptionPageState extends State<MySubscriptionPage> {
  late Future<Map<String, dynamic>> _future = _load();
  late final _phone = TextEditingController(
      text: widget.phone ?? currentUserDocument?.phoneNumber ?? '');
  late String _plan = widget.initialPlan ?? 'quarterly';
  // MTN MoMo ou Airtel Money : proposé d'après le numéro du compte.
  late String _operator = operatorOfPhone(_phone.text) ?? 'MTN';
  String get _opLabel => kPaymentOperators[_operator]!.label;
  String get _opShort => _operator == 'Airtel' ? 'Airtel' : 'MTN';
  bool _paid = false;
  bool _paying = false;
  String? _message;
  bool _messageOk = false;

  Future<Map<String, dynamic>> _load() => _call('kitungaMySubscription', {});

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pay(int price) async {
    if (_phone.text.replaceAll(RegExp(r'\D'), '').length < 9) {
      return setState(() {
        _message = 'Saisissez votre numéro $_opLabel.';
        _messageOk = false;
      });
    }
    setState(() {
      _paying = true;
      _message = null;
    });
    try {
      final start = await _call('kitungaStartSubscription',
          {'plan': _plan, 'phone': _phone.text.trim(), 'operator': _operator});
      final ref = '${start['referenceId']}';
      // Le client valide sur son téléphone (code PIN) : 2 minutes.
      var status = 'pending';
      for (var i = 0; i < 24 && status == 'pending' && mounted; i++) {
        await Future.delayed(subscriptionPollDelay);
        try {
          final r = await _call('kitungaConfirmSubscription',
              {'referenceId': ref});
          status = '${r['status']}';
        } on ServerPaymentException {
          // Réseau coupé : on réessaie.
        }
      }
      if (!mounted) return;
      setState(() {
        _messageOk = status == 'paid';
        _message = switch (status) {
          'paid' => 'Paiement de $price F reçu : votre abonnement est actif. '
              'Vous pouvez commander.',
          'failed' => '$_opShort a refusé le paiement. Vérifiez votre solde puis '
              'réessayez.',
          _ => 'Validation $_opShort pas encore reçue. Si vous avez validé, votre '
              'abonnement s\'activera dans quelques minutes.',
        };
      });
      if (status == 'paid') {
        _paid = true;
        _reload();
      }
    } on ServerPaymentException catch (e) {
      setState(() {
        _message = e.message;
        _messageOk = false;
      });
    } catch (_) {
      setState(() {
        _message = 'Connexion impossible. Réessayez.';
        _messageOk = false;
      });
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final small = GoogleFonts.inter(color: theme.secondaryText, fontSize: 13.5);
    return Scaffold(
      backgroundColor: theme.secondaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0.0,
        iconTheme: IconThemeData(color: theme.primaryText),
        automaticallyImplyLeading: !widget.fromSignup,
        title: Text(widget.fromSignup ? 'Votre abonnement' : 'Mon abonnement',
            style: GoogleFonts.interTight(
                color: theme.primaryText,
                fontSize: 19.0,
                fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(
                child: CircularProgressIndicator(color: theme.primary));
          }
          if (snap.hasError) {
            return Center(
              child: TextButton(
                  onPressed: _reload, child: const Text('Réessayer')),
            );
          }
          final d = snap.data!;
          final plans = [
            for (final p in (d['plans'] as List? ?? const []))
              Map<String, dynamic>.from(p as Map),
          ];
          final history = [
            for (final h in (d['history'] as List? ?? const []))
              Map<String, dynamic>.from(h as Map),
          ];
          final chosen = plans.firstWhere((p) => p['key'] == _plan,
              orElse: () => plans.isEmpty ? {} : plans.first);
          final active = d['active'] == true;
          final days = (d['daysLeft'] as num?)?.toInt() ?? 0;
          if (d['required'] == false) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                  'Votre compte (commerce, livreur ou équipe Kitunga) commande '
                  'sans abonnement.',
                  style: small),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 32.0),
            children: [
              if (widget.fromSignup)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                      'Dernière étape : payez votre abonnement pour pouvoir '
                      'commander. Vous pouvez aussi le faire plus tard dans '
                      'Profil › Mon abonnement.',
                      style: small),
                ),
              // État de l'abonnement.
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: active
                        ? [const Color(0xFF1E9E5A), const Color(0xFF16804A)]
                        : [theme.primary, const Color(0xFFB71C1C)],
                  ),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(active ? 'Abonnement actif' : 'Pas d\'abonnement actif',
                        style: GoogleFonts.interTight(
                            color: Colors.white,
                            fontSize: 20.0,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4.0),
                    Text(
                        active
                            ? 'Jusqu\'au ${_day(d['until'])} · '
                                '$days jour${days > 1 ? 's' : ''} restant${days > 1 ? 's' : ''}'
                            : d['until'] != null
                                ? 'Terminé le ${_day(d['until'])}. Abonnez-vous '
                                    'pour commander de nouveau.'
                                : 'Abonnez-vous pour commander sur Kitunga.',
                        style: GoogleFonts.inter(
                            color: Colors.white, fontSize: 14.0)),
                  ],
                ),
              ),
              const SizedBox(height: 20.0),
              Text(active ? 'Prolonger mon abonnement' : 'Choisir une formule',
                  style: GoogleFonts.interTight(
                      color: theme.primaryText,
                      fontSize: 17.0,
                      fontWeight: FontWeight.w800)),
              if (active)
                Text('La durée s\'ajoute à la fin de votre abonnement actuel.',
                    style: small),
              const SizedBox(height: 10.0),
              for (final p in plans)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16.0),
                    onTap: _paying
                        ? null
                        : () => setState(() => _plan = '${p['key']}'),
                    child: Container(
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        color: theme.primaryBackground,
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(
                            color: _plan == p['key']
                                ? theme.primary
                                : theme.alternate,
                            width: _plan == p['key'] ? 2.0 : 1.0),
                      ),
                      child: Row(
                        children: [
                          Icon(
                              _plan == p['key']
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: theme.primary),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: Text(
                                planDisplayName('${p['key']}'),
                                style: GoogleFonts.inter(
                                    color: theme.primaryText,
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.w700)),
                          ),
                          Text('${p['price']} F',
                              style: GoogleFonts.interTight(
                                  color: theme.primary,
                                  fontSize: 17.0,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 4.0),
              // Choix de l'opérateur : MTN MoMo ou Airtel Money.
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: SegmentedButton<String>(
                  key: const ValueKey('subscription-operator'),
                  showSelectedIcon: false,
                  segments: [
                    for (final e in kPaymentOperators.entries)
                      ButtonSegment(
                        value: e.key,
                        label: Text(e.value.label),
                        icon: ClipOval(
                          child: Image.asset(e.value.logo,
                              width: 22.0, height: 22.0, fit: BoxFit.cover),
                        ),
                      ),
                  ],
                  selected: {_operator},
                  onSelectionChanged: _paying
                      ? null
                      : (v) => setState(() {
                            _operator = v.first;
                            _message = null;
                          }),
                ),
              ),
              TextField(
                controller: _phone,
                enabled: !_paying,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Numéro $_opLabel',
                  hintText: kPaymentOperators[_operator]!.hint,
                  prefixIcon: const Icon(Icons.phone_android_rounded),
                ),
              ),
              const SizedBox(height: 14.0),
              FilledButton(
                style: FilledButton.styleFrom(
                  // Jaune MTN, rouge Airtel.
                  backgroundColor: _operator == 'Airtel'
                      ? const Color(0xFFE40000)
                      : const Color(0xFFFFCB05),
                  foregroundColor:
                      _operator == 'Airtel' ? Colors.white : Colors.black,
                  minimumSize: const Size.fromHeight(50.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.0)),
                ),
                onPressed: _paying || chosen.isEmpty
                    ? null
                    : () => _pay((chosen['price'] as num).toInt()),
                child: _paying
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                              width: 18.0,
                              height: 18.0,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.0, color: Colors.black)),
                          SizedBox(width: 10.0),
                          Text('Validez sur votre téléphone (code PIN)…'),
                        ],
                      )
                    : Text('Payer ${chosen['price'] ?? ''} F avec $_opLabel',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(_message!,
                      style: GoogleFonts.inter(
                          color: _messageOk
                              ? const Color(0xFF1E9E5A)
                              : theme.error,
                          fontWeight: FontWeight.w600)),
                ),
              if (widget.fromSignup) ...[
                const SizedBox(height: 12.0),
                _paid
                    ? FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: theme.primary,
                            minimumSize: const Size.fromHeight(48.0)),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Continuer'),
                      )
                    : TextButton(
                        onPressed: _paying
                            ? null
                            : () => Navigator.pop(context, false),
                        child: const Text('Payer plus tard'),
                      ),
              ],
              if (history.isNotEmpty) ...[
                const SizedBox(height: 24.0),
                Text('Mes paiements',
                    style: GoogleFonts.interTight(
                        color: theme.primaryText,
                        fontSize: 17.0,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6.0),
                for (final h in history)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                        h['status'] == 'Réussi'
                            ? Icons.check_circle_rounded
                            : h['status'] == 'Echec'
                                ? Icons.cancel_rounded
                                : Icons.hourglass_top_rounded,
                        color: h['status'] == 'Réussi'
                            ? const Color(0xFF1E9E5A)
                            : h['status'] == 'Echec'
                                ? theme.error
                                : theme.secondaryText),
                    title: Text('${h['plan']} · ${h['amount']} F',
                        style: GoogleFonts.inter(
                            color: theme.primaryText,
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${_day(h['date'])} · ${h['status'] == 'Echec' ? 'Échec' : h['status']}',
                        style: small),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
