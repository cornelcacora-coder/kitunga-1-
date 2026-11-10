import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/backend/order_status.dart';
import '/backend/server_payment.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/upload_data.dart';
import '/mobile/components/returns/kitunga_returns.dart' show KitungaReturnSection;

/// Remise sécurisée et reçu, côté application :
/// - client : code de remise à donner au livreur, bouton « Voir le reçu » ;
/// - livreur : remise avec le code du client et une photo, ou signalement
///   d'un problème ;
/// - tous : écran du reçu (numéro unique, articles, paiement, livraison).

/// Remplace le serveur dans les tests.
@visibleForTesting
Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data)?
    deliveryBackendOverride;

/// Remplace la prise de photo dans les tests (adresse renvoyée directement).
@visibleForTesting
Future<String?> Function()? deliveryPhotoOverride;

Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) =>
    deliveryBackendOverride != null
        ? deliveryBackendOverride!(name, data)
        : kitungaCallFunction(name, data);

String _fcfa(num v) => '${NumberFormat.decimalPattern('fr').format(v)} F';

const _red = Color(0xFFE51A1A);
const _green = Color(0xFF17A35B);

// ── Client : code de remise ──────────────────────────────────────────────

/// Code de remise de la commande, à donner au livreur à la réception.
class KitungaDeliveryCodeCard extends StatefulWidget {
  const KitungaDeliveryCodeCard({super.key, required this.order});

  final OrdersRecord order;

  /// Le code s'affiche pour le client tant que la commande n'est pas livrée.
  static bool showsFor(OrdersRecord o, DocumentReference? me) =>
      me != null &&
      o.userRef == me &&
      OrderStatus.inProgress.contains(o.status);

  @override
  State<KitungaDeliveryCodeCard> createState() =>
      _KitungaDeliveryCodeCardState();
}

class _KitungaDeliveryCodeCardState extends State<KitungaDeliveryCodeCard> {
  late Future<Map<String, dynamic>> _code =
      _call('kitungaDeliveryCode', {'orderId': widget.order.reference.id});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: _red.withValues(alpha: 0.25)),
      ),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _code,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return SizedBox(
              height: 72.0,
              child: Center(
                  child: CircularProgressIndicator(color: theme.primary)),
            );
          }
          if (snap.hasError) {
            return Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: theme.secondaryText),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Text('Code de remise indisponible pour le moment.',
                      style: GoogleFonts.inter(color: theme.secondaryText)),
                ),
                TextButton(
                  onPressed: () => setState(() => _code = _call(
                      'kitungaDeliveryCode',
                      {'orderId': widget.order.reference.id})),
                  child: const Text('Réessayer'),
                ),
              ],
            );
          }
          final code = snap.data!['code'] as String?;
          if (code == null) return const SizedBox.shrink();
          final locked = snap.data!['locked'] == true;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: _red),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text('Code de remise',
                        style: GoogleFonts.interTight(
                            color: theme.primaryText,
                            fontSize: 16.0,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Semantics(
                label: 'Code de remise ${code.split('').join(' ')}',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final c in code.split(''))
                      Container(
                        width: 52.0,
                        height: 62.0,
                        margin: const EdgeInsets.symmetric(horizontal: 5.0),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.secondaryBackground,
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(color: _red, width: 1.6),
                        ),
                        child: Text(c,
                            style: GoogleFonts.interTight(
                                color: theme.primaryText,
                                fontSize: 30.0,
                                fontWeight: FontWeight.w900)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12.0),
              Text(
                  locked
                      ? 'Remise bloquée après plusieurs codes faux. Le support '
                          'Kitunga vous contactera.'
                      : 'Donnez ce code au livreur seulement quand vous avez '
                          'votre commande en main. Ne le communiquez jamais '
                          'par téléphone.',
                  style: GoogleFonts.inter(
                      color: locked ? _red : theme.secondaryText,
                      fontSize: 13.0,
                      height: 1.4)),
            ],
          );
        },
      ),
    );
  }
}

// ── Reçu ─────────────────────────────────────────────────────────────────

/// Bouton « Voir le reçu » (commande livrée).
class KitungaReceiptButton extends StatelessWidget {
  const KitungaReceiptButton({super.key, required this.order});

  final OrdersRecord order;

  static bool showsFor(OrdersRecord o) =>
      [OrderStatus.delivered, OrderStatus.received, OrderStatus.notReceived]
          .contains(o.status);

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.primaryText,
          side: BorderSide(color: theme.alternate),
          padding: const EdgeInsets.symmetric(vertical: 14.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
        ),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => KitungaReceiptPage(orderId: order.reference.id))),
        icon: const Icon(Icons.receipt_long_rounded, size: 20.0),
        label: Text('Voir le reçu',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Code de remise (client) et reçu (commande livrée), sous le suivi.
class KitungaDeliveryExtras extends StatelessWidget {
  const KitungaDeliveryExtras({super.key, required this.order});

  final OrdersRecord order;

  @override
  Widget build(BuildContext context) {
    final showCode =
        KitungaDeliveryCodeCard.showsFor(order, currentUserReference);
    final showReceipt = KitungaReceiptButton.showsFor(order);
    if (!showCode && !showReceipt) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: showCode
          ? KitungaDeliveryCodeCard(order: order)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KitungaReceiptButton(order: order),
                // Boutiques et magasins : retour ou échange (7 jours).
                KitungaReturnSection(order: order),
              ],
            ),
    );
  }
}

/// Écran du reçu d'une commande livrée.
class KitungaReceiptPage extends StatefulWidget {
  const KitungaReceiptPage({super.key, required this.orderId});

  final String orderId;

  @override
  State<KitungaReceiptPage> createState() => _KitungaReceiptPageState();
}

class _KitungaReceiptPageState extends State<KitungaReceiptPage> {
  late Future<Map<String, dynamic>> _receipt =
      _call('kitungaOrderReceipt', {'orderId': widget.orderId});

  String _date(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    return d == null ? '—' : DateFormat('d MMMM yyyy à HH:mm', 'fr').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    TextStyle s(double size,
            {FontWeight w = FontWeight.w500, Color? c}) =>
        GoogleFonts.inter(
            color: c ?? theme.primaryText, fontSize: size, fontWeight: w);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0.0,
        title: Text('Reçu', style: s(18.0, w: FontWeight.w800)),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _receipt,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(
                child: CircularProgressIndicator(color: theme.primary));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 48.0, color: theme.secondaryText),
                    const SizedBox(height: 12.0),
                    Text('${snap.error}',
                        textAlign: TextAlign.center,
                        style: s(14.0, c: theme.secondaryText)),
                    TextButton(
                      onPressed: () => setState(() => _receipt = _call(
                          'kitungaOrderReceipt', {'orderId': widget.orderId})),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }
          final r = snap.data!;
          final lines = (r['lines'] as List? ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final pay = r['payment'] as Map?;
          final seller = Map<String, dynamic>.from(r['seller'] as Map? ?? {});
          final client = Map<String, dynamic>.from(r['client'] as Map? ?? {});
          Widget row(String a, String b, {bool bold = false}) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: Text(a,
                            style: s(13.5,
                                c: bold ? null : theme.secondaryText,
                                w: bold ? FontWeight.w800 : FontWeight.w500))),
                    const SizedBox(width: 12.0),
                    Flexible(
                      child: Text(b,
                          textAlign: TextAlign.right,
                          style: s(bold ? 16.0 : 13.5,
                              w: bold ? FontWeight.w900 : FontWeight.w600)),
                    ),
                  ],
                ),
              );
          final divider = Divider(height: 24.0, color: theme.alternate);
          return ListView(
            padding: const EdgeInsets.all(20.0),
            children: [
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(22.0),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 20.0,
                        offset: Offset(0, 8)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/logo/kitunga_logo.png', height: 64.0),
                    const SizedBox(height: 10.0),
                    Text('Reçu de commande',
                        textAlign: TextAlign.center,
                        style: s(18.0, w: FontWeight.w800)),
                    const SizedBox(height: 4.0),
                    GestureDetector(
                      onLongPress: () {
                        Clipboard.setData(
                            ClipboardData(text: '${r['number']}'));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Numéro copié')));
                      },
                      child: Text('N° ${r['number']}',
                          textAlign: TextAlign.center,
                          style: s(14.0, w: FontWeight.w700, c: _red)),
                    ),
                    if (r['codeVerified'] == true) ...[
                      const SizedBox(height: 10.0),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 6.0),
                          decoration: BoxDecoration(
                            color: _green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded,
                                  size: 16.0, color: _green),
                              const SizedBox(width: 6.0),
                              Flexible(
                                child: Text('Remise confirmée par code',
                                    textAlign: TextAlign.center,
                                    style: s(12.5,
                                        w: FontWeight.w700, c: _green)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    divider,
                    row('Commande', '${r['orderReference'] ?? ''}'),
                    row('Commandée le', _date(r['orderedAt'] as String?)),
                    row('Livrée le', _date(r['deliveredAt'] as String?)),
                    row('Commerce', '${seller['name'] ?? ''}'),
                    row('Client', '${client['name'] ?? ''}'),
                    if ('${r['address'] ?? ''}'.isNotEmpty)
                      row('Adresse', '${r['address']}'),
                    if ('${r['deliverer'] ?? ''}'.isNotEmpty)
                      row('Livreur', '${r['deliverer']}'),
                    divider,
                    for (final l in lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${l['quantity']} × ${l['name']}',
                                      style: s(14.0, w: FontWeight.w600)),
                                  if ('${l['options'] ?? ''}'.isNotEmpty)
                                    Text('${l['options']}',
                                        style:
                                            s(12.5, c: theme.secondaryText)),
                                  Text(
                                      '${_fcfa(l['unitPrice'] as num? ?? 0)} l\'unité',
                                      style: s(12.0, c: theme.secondaryText)),
                                ],
                              ),
                            ),
                            Text(_fcfa(l['total'] as num? ?? 0),
                                style: s(14.0, w: FontWeight.w700)),
                          ],
                        ),
                      ),
                    divider,
                    row('Sous-total', _fcfa(r['subtotal'] as num? ?? 0)),
                    row('Livraison', _fcfa(r['deliveryFees'] as num? ?? 0)),
                    const SizedBox(height: 4.0),
                    row('Total payé', _fcfa(r['total'] as num? ?? 0), bold: true),
                    divider,
                    row('Paiement',
                        pay == null ? 'Non enregistré' : '${pay['method']}'),
                    if (pay != null) row('Référence', '${pay['reference']}'),
                    const SizedBox(height: 14.0),
                    Text(
                        'Kitunga · Brazzaville — reçu généré automatiquement. '
                        'Conservez-le en cas de réclamation.',
                        textAlign: TextAlign.center,
                        style: s(11.5, c: theme.secondaryText)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Livreur : remise et problèmes ────────────────────────────────────────

/// Le livreur prend une commande prête. Le serveur garantit qu'un seul
/// livreur l'obtient ; l'autre voit un message. true si prise.
Future<bool> kitungaTakeDelivery(
    BuildContext context, OrdersRecord order) async {
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  try {
    await _call('kitungaTakeDelivery', {'orderId': order.reference.id});
    messenger.showSnackBar(const SnackBar(
        content: Text('Commande prise en charge. Bonne route !')));
    return true;
  } on ServerPaymentException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Connexion impossible. Réessayez.')));
  }
  return false;
}

/// Remise de la commande : code du client + photo. true si livrée.
Future<bool> kitungaCompleteDelivery(
    BuildContext context, OrdersRecord order) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: MediaQuery.viewInsetsOf(context),
      child: _CompleteDeliverySheet(order: order),
    ),
  );
  return ok == true;
}

Future<String?> _takePhoto(BuildContext context) async {
  if (deliveryPhotoOverride != null) return deliveryPhotoOverride!();
  final media = await selectMedia(
      maxWidth: 1280.0, maxHeight: 1280.0, imageQuality: 80, multiImage: false);
  if (media == null || media.isEmpty) return null;
  if (!context.mounted || !validateFileFormat(media.first.storagePath, context)) {
    return null;
  }
  return uploadData(media.first.storagePath, media.first.bytes);
}

class _CompleteDeliverySheet extends StatefulWidget {
  const _CompleteDeliverySheet({required this.order});

  final OrdersRecord order;

  @override
  State<_CompleteDeliverySheet> createState() => _CompleteDeliverySheetState();
}

class _CompleteDeliverySheetState extends State<_CompleteDeliverySheet> {
  final _code = TextEditingController();
  String? _photo;
  bool _busy = false;
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _photoTap() async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    final url = await _takePhoto(context);
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (url != null) _photo = url;
      if (url == null) _error = 'Photo non envoyée. Réessayez.';
    });
  }

  Future<void> _submit() async {
    if (_code.text.trim().length != 4) {
      return setState(() => _error = 'Saisissez les 4 chiffres du client.');
    }
    if (_photo == null) {
      return setState(() => _error = 'Prenez une photo de la remise.');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _call('kitungaConfirmDelivery', {
        'orderId': widget.order.reference.id,
        'code': _code.text.trim(),
        'photoUrl': _photo,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: _green,
          content: Text('Commande livrée. Merci !')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Material(
      color: theme.secondaryBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 14.0, 20.0, 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                      color: theme.alternate,
                      borderRadius: BorderRadius.circular(2.0)),
                ),
              ),
              const SizedBox(height: 14.0),
              Text('Remettre la commande',
                  style: GoogleFonts.interTight(
                      color: theme.primaryText,
                      fontSize: 20.0,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4.0),
              Text(
                  'Demandez au client le code à 4 chiffres affiché dans son '
                  'application, puis photographiez la commande remise.',
                  style: GoogleFonts.inter(
                      color: theme.secondaryText, fontSize: 13.5, height: 1.4)),
              const SizedBox(height: 16.0),
              TextField(
                controller: _code,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.interTight(
                    color: theme.primaryText,
                    fontSize: 30.0,
                    letterSpacing: 18.0,
                    fontWeight: FontWeight.w900),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  filled: true,
                  fillColor: theme.primaryBackground,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12.0),
              OutlinedButton.icon(
                onPressed: _busy || _uploading ? null : _photoTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _photo != null ? _green : theme.primaryText,
                  side: BorderSide(
                      color: _photo != null ? _green : theme.alternate),
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.0)),
                ),
                icon: _uploading
                    ? const SizedBox(
                        width: 18.0,
                        height: 18.0,
                        child: CircularProgressIndicator(strokeWidth: 2.0))
                    : Icon(_photo != null
                        ? Icons.check_circle_rounded
                        : Icons.photo_camera_rounded),
                label: Text(_photo != null
                    ? 'Photo prise (reprendre)'
                    : 'Photographier la remise'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10.0),
                Text(_error!,
                    style: GoogleFonts.inter(
                        color: _red, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 14.0),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0)),
                ),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20.0,
                        height: 20.0,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.0, color: Colors.white))
                    : Text('Confirmer la remise',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800, fontSize: 15.0)),
              ),
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final reported =
                            await kitungaReportDeliveryIssue(context, widget.order);
                        if (reported && context.mounted) {
                          Navigator.pop(context, false);
                        }
                      },
                icon: const Icon(Icons.report_gmailerrorred_rounded, size: 18.0),
                label: const Text('Problème : client injoignable, refus…'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Problèmes de livraison proposés au livreur (mêmes clés que le serveur).
const kDeliveryIssues = {
  'absent': 'Client injoignable',
  'refused': 'Commande refusée par le client',
  'address': 'Adresse introuvable',
  'damaged': 'Colis abîmé',
  'other': 'Autre problème',
};

/// Signalement d'un problème : l'admin est alerté. true si envoyé.
Future<bool> kitungaReportDeliveryIssue(
    BuildContext context, OrdersRecord order) async {
  final r = await showDialog<(String, String)>(
    context: context,
    builder: (_) => const _IssueDialog(),
  );
  if (r == null || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await _call('kitungaReportDeliveryIssue',
        {'orderId': order.reference.id, 'type': r.$1, 'note': r.$2});
    messenger.showSnackBar(const SnackBar(
        content: Text('Problème signalé. Kitunga vous recontacte.')));
    return true;
  } catch (e) {
    messenger.showSnackBar(
        SnackBar(backgroundColor: _red, content: Text('$e')));
    return false;
  }
}

class _IssueDialog extends StatefulWidget {
  const _IssueDialog();

  @override
  State<_IssueDialog> createState() => _IssueDialogState();
}

class _IssueDialogState extends State<_IssueDialog> {
  String _type = 'absent';
  final _note = TextEditingController();
  bool _missing = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Signaler un problème'),
      content: SizedBox(
        width: 380.0,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioGroup<String>(
                groupValue: _type,
                onChanged: (v) => setState(() => _type = v ?? _type),
                child: Column(
                  children: [
                    for (final e in kDeliveryIssues.entries)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: e.key,
                        title: Text(e.value),
                      ),
                  ],
                ),
              ),
              TextField(
                controller: _note,
                maxLength: 300,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Précisions',
                  errorText: _missing ? 'Décrivez le problème' : null,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            if (_type == 'other' && _note.text.trim().isEmpty) {
              return setState(() => _missing = true);
            }
            Navigator.pop(context, (_type, _note.text.trim()));
          },
          child: const Text('Envoyer'),
        ),
      ],
    );
  }
}
