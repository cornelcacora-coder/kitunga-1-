import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/order_status.dart';
import '/backend/server_payment.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/noc/admin/brazzaville_zones.dart' show kBrazzavilleZones;

/// Livreurs et contacts autour d'une commande :
/// - panneau du livreur : « En service » / « Hors service » et quartiers
///   couverts (il ne reçoit les nouvelles courses que s'il est en service) ;
/// - boutons Appeler / WhatsApp entre client, commerce et livreur.

/// Remplace le serveur dans les tests.
@visibleForTesting
Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data)?
    delivererBackendOverride;

/// Remplace l'état du livreur (document User) dans les tests.
@visibleForTesting
Stream<Map<String, dynamic>>? delivererStateOverride;

Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) =>
    delivererBackendOverride != null
        ? delivererBackendOverride!(name, data)
        : kitungaCallFunction(name, data);

/// Appel serveur du livreur (remplaçable dans les tests).
Future<Map<String, dynamic>> delivererCall(
        String name, Map<String, dynamic> data) =>
    _call(name, data);

/// Ouvre le choix des quartiers ; renvoie la liste choisie (null = annulé).
Future<List<String>?> pickDelivererZones(
        BuildContext context, List<String> initial) =>
    showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ZonesSheet(initial: initial),
    );

const _green = Color(0xFF17A35B);
const _whatsappGreen = Color(0xFF25D366);

/// Quartiers de livraison (mêmes noms que ceux choisis par le client).
List<String> get kDeliveryZones => kBrazzavilleZones.keys.toList();

/// Le livreur couvre-t-il ce quartier ? (aucun quartier choisi = tous)
bool delivererCovers(List<String> zones, String zone) =>
    zones.isEmpty || zone.isEmpty || zones.contains(zone);

Stream<Map<String, dynamic>> _myState() {
  if (delivererStateOverride != null) return delivererStateOverride!;
  final ref = currentUserReference;
  if (ref == null) return const Stream.empty();
  return ref.snapshots().map((s) =>
      (s.data() as Map<String, dynamic>?) ?? const <String, dynamic>{});
}

/// État du livreur, lu en direct (en service, quartiers).
class DelivererState {
  const DelivererState(
      {required this.available,
      required this.zones,
      String? state,
      this.vehicle = 'moto'})
      : state = state ?? (available ? 'on' : 'off');

  factory DelivererState.of(Map<String, dynamic> data) => DelivererState(
        available: data['delivery_available'] == true,
        state: const ['on', 'pause', 'off'].contains(data['delivery_state'])
            ? data['delivery_state'] as String
            : null,
        vehicle: const ['moto', 'velo', 'voiture'].contains(data['vehicle'])
            ? data['vehicle'] as String
            : 'moto',
        zones: ((data['delivery_zones'] as List?) ?? const [])
            .map((z) => '$z')
            .toList(),
      );

  final bool available;

  /// 'on' (en service), 'pause' (en pause), 'off' (hors service).
  final String state;

  /// Véhicule : 'moto', 'velo' ou 'voiture' (capacité de courses).
  final String vehicle;
  final List<String> zones;
}

/// Écoute l'état du livreur et le passe à [builder].
class DelivererStateBuilder extends StatelessWidget {
  const DelivererStateBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, DelivererState state) builder;

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>>(
        stream: _myState(),
        builder: (context, snap) => builder(
            context, DelivererState.of(snap.data ?? const <String, dynamic>{})),
      );
}

/// Panneau en haut de la liste des courses du livreur.
class KitungaDelivererPanel extends StatefulWidget {
  const KitungaDelivererPanel({super.key, required this.state});

  final DelivererState state;

  @override
  State<KitungaDelivererPanel> createState() => _KitungaDelivererPanelState();
}

class _KitungaDelivererPanelState extends State<KitungaDelivererPanel> {
  bool _busy = false;

  Future<void> _save(Map<String, dynamic> data, String done) async {
    setState(() => _busy = true);
    try {
      await _call('kitungaSetDelivererStatus', data);
      if (mounted) _snack(done);
    } on ServerPaymentException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Enregistrement impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickZones() async {
    final chosen = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ZonesSheet(initial: widget.state.zones),
    );
    if (chosen == null) return;
    await _save({'zones': chosen},
        chosen.isEmpty ? 'Vous couvrez toute la ville.' : 'Quartiers enregistrés.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final s = widget.state;
    final color = s.state == 'on'
        ? _green
        : s.state == 'pause'
            ? const Color(0xFFE08A00)
            : theme.secondaryText;
    const labels = {'on': 'En service', 'pause': 'En pause',
      'off': 'Hors service'};
    const hints = {
      'on': 'Vous recevez les nouvelles courses.',
      'pause': 'Pas de nouvelle course ; vous terminez vos courses en cours.',
      'off': 'Passez en service pour recevoir des courses.',
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                  s.state == 'on'
                      ? Icons.delivery_dining_rounded
                      : s.state == 'pause'
                          ? Icons.coffee_rounded
                          : Icons.bedtime_outlined,
                  color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(labels[s.state]!,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: theme.primaryText)),
                    Text(hints[s.state]!,
                        style: GoogleFonts.inter(
                            fontSize: 12.5, color: theme.secondaryText)),
                  ],
                ),
              ),
              Switch(
                key: const ValueKey('deliverer-available'),
                value: s.state == 'on',
                activeThumbColor: _green,
                onChanged: _busy
                    ? null
                    : (v) => _save({'state': v ? 'on' : 'off'},
                        v ? 'Vous êtes en service.' : 'Vous êtes hors service.'),
              ),
            ],
          ),
          // Pause : plus de nouvelles courses, sans quitter le service.
          if (s.state != 'off')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('deliverer-pause'),
                onPressed: _busy
                    ? null
                    : () => s.state == 'pause'
                        ? _save({'state': 'on'}, 'Vous êtes en service.')
                        : _save({'state': 'pause'}, 'Vous êtes en pause.'),
                icon: Icon(
                    s.state == 'pause'
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    size: 18),
                label: Text(
                    s.state == 'pause' ? 'Reprendre le service' : 'Faire une pause'),
              ),
            ),
          const SizedBox(height: 4),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _busy ? null : _pickZones,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.place_outlined,
                      size: 18, color: theme.secondaryText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.zones.isEmpty
                          ? 'Mes quartiers : toute la ville'
                          : 'Mes quartiers : ${s.zones.join(', ')}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: theme.primaryText),
                    ),
                  ),
                  Text('Modifier',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.primary)),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZonesSheet extends StatefulWidget {
  const _ZonesSheet({required this.initial});

  final List<String> initial;

  @override
  State<_ZonesSheet> createState() => _ZonesSheetState();
}

class _ZonesSheetState extends State<_ZonesSheet> {
  late final Set<String> _chosen = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('Mes quartiers de livraison',
                  style: GoogleFonts.interTight(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.primaryText)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                  'Vous serez prévenu des courses vers ces quartiers. '
                  'Aucun choix = toute la ville.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: theme.secondaryText)),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final z in kDeliveryZones)
                      FilterChip(
                        label: Text(z),
                        selected: _chosen.contains(z),
                        onSelected: (v) => setState(
                            () => v ? _chosen.add(z) : _chosen.remove(z)),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(_chosen.clear),
                    child: const Text('Toute la ville'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context,
                        kDeliveryZones.where(_chosen.contains).toList()),
                    child: Text('Enregistrer (${_chosen.length})'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Contacts d'une commande ──────────────────────────────────────────────

/// Statuts où les acteurs d'une commande peuvent se joindre.
const _contactStatuses = {
  OrderStatus.preparing,
  OrderStatus.ready,
  OrderStatus.delivering,
  OrderStatus.delivered,
};

/// « +242 06 123 45 67 » / « 061234567 » → « 242061234567 ».
String phoneDigits(String phone) {
  var d = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('00')) d = d.substring(2);
  if (!d.startsWith('242') && d.length == 9) d = '242$d';
  return d;
}

const _roleLabel = {
  'client': 'Client',
  'commerce': 'Commerce',
  'livreur': 'Livreur',
};

/// Boutons Appeler / WhatsApp vers les autres acteurs de la commande.
class KitungaOrderContacts extends StatefulWidget {
  const KitungaOrderContacts({super.key, required this.order});

  final OrdersRecord order;

  static bool showsFor(OrdersRecord order) =>
      _contactStatuses.contains(order.status);

  @override
  State<KitungaOrderContacts> createState() => _KitungaOrderContactsState();
}

class _KitungaOrderContactsState extends State<KitungaOrderContacts> {
  late Future<List<Map<String, dynamic>>> _contacts = _load();
  String _key = '';

  Future<List<Map<String, dynamic>>> _load() async {
    _key = '${widget.order.status}|${widget.order.delivererRef}';
    final res = await _call(
        'kitungaOrderContacts', {'orderId': widget.order.reference.id});
    return ((res['contacts'] as List?) ?? const [])
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
  }

  @override
  void didUpdateWidget(covariant KitungaOrderContacts old) {
    super.didUpdateWidget(old);
    // Un livreur vient de prendre la commande : on recharge.
    if ('${widget.order.status}|${widget.order.delivererRef}' != _key) {
      _contacts = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _contacts,
      builder: (context, snap) {
        final list = snap.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.alternate),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Contacts',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: theme.primaryText)),
              for (final c in list) _row(context, c),
            ],
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> c) {
    final theme = FlutterFlowTheme.of(context);
    final digits = phoneDigits('${c['phone'] ?? ''}');
    final name = '${c['name'] ?? ''}'.trim();
    final role = _roleLabel[c['role']] ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '$role  ',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: theme.secondaryText)),
                TextSpan(
                    text: name.isEmpty ? '+$digits' : name,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryText)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Appeler',
            icon: Icon(Icons.call_rounded, color: theme.primary),
            onPressed: () => launchURL('tel:+$digits'),
          ),
          IconButton(
            tooltip: 'WhatsApp',
            icon: const Icon(Icons.chat_rounded, color: _whatsappGreen),
            onPressed: () => launchURL('https://wa.me/$digits'),
          ),
        ],
      ),
    );
  }
}
