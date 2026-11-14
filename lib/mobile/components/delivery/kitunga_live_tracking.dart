import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/order_status.dart';
import '/backend/server_payment.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart' show launchURL;
import '/mobile/components/delivery/kitunga_deliverer_panel.dart'
    show KitungaOrderContacts;
import '/mobile/components/delivery/kitunga_delivery.dart'
    show kitungaCompleteDelivery, kitungaReportDeliveryIssue;
import '/mobile/deliverer/kitunga_deliverer_pro.dart'
    show proCall, sendSafetyAlert;
import '/noc/admin/brazzaville_zones.dart'
    show kBrazzavilleCenter, kBrazzavilleZones;

/// Suivi en direct d'une livraison :
/// - client (et commerce) : carte avec le livreur qui avance, étapes,
///   livreur à joindre ;
/// - livreur : page « Course en cours » (carte, étapes, gros bouton
///   d'action, itinéraire) qui partage sa position pendant la course.

/// Remplace le serveur dans les tests.
@visibleForTesting
Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data)?
    trackingBackendOverride;

/// Désactive la carte (tuiles réseau) et le GPS dans les tests.
@visibleForTesting
bool trackingTestMode = false;

Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) =>
    trackingBackendOverride != null
        ? trackingBackendOverride!(name, data)
        : kitungaCallFunction(name, data);

const _red = Color(0xFFE51A1A);
const _green = Color(0xFF17A35B);

/// Statuts où le suivi a un sens.
const _trackedStatuses = {
  OrderStatus.preparing,
  OrderStatus.ready,
  OrderStatus.delivering,
};

DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v) : null;

ll.LatLng? _zonePoint(String zone) => kBrazzavilleZones[zone];

/// Position exacte reçue du serveur ({lat, lng}), ou null.
ll.LatLng? exactPointOf(dynamic v) => v is Map && v['lat'] is num &&
        v['lng'] is num
    ? ll.LatLng((v['lat'] as num).toDouble(), (v['lng'] as num).toDouble())
    : null;

/// Minutes estimées entre deux points : route ≈ vol d'oiseau × 1,3, à
/// 22 km/h de moyenne en ville, + 2 min (stationnement, remise).
int etaMinutes(ll.LatLng a, ll.LatLng b) {
  final km = const ll.Distance().as(ll.LengthUnit.Meter, a, b) / 1000 * 1.3;
  return (km / 22 * 60).ceil() + 2;
}

String _clockIn(int minutes) {
  final t = DateTime.now().add(Duration(minutes: minutes));
  return '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

String _ago(DateTime? at) {
  if (at == null) return '';
  final s = DateTime.now().difference(at.toLocal()).inSeconds;
  if (s < 60) return 'à l\'instant';
  if (s < 3600) return 'il y a ${s ~/ 60} min';
  return 'il y a ${s ~/ 3600} h';
}

/// Une étape du suivi.
class TrackingStep {
  const TrackingStep(this.title, this.subtitle, this.done, this.current);
  final String title;
  final String subtitle;
  final bool done;
  final bool current;
}

/// Étapes à partir du suivi renvoyé par le serveur.
List<TrackingStep> trackingSteps(Map<String, dynamic> t,
    {bool forDeliverer = false}) {
  final status = '${t['status'] ?? ''}';
  final shop = (t['shop'] as Map?)?['name'] ?? 'le commerce';
  final zone = '${t['zone'] ?? ''}';
  final taken = status == OrderStatus.delivering ||
      OrderStatus.successful.contains(status);
  final picked = t['pickedUpAt'] != null ||
      OrderStatus.successful.contains(status);
  final arrived = t['arrivedAt'] != null ||
      OrderStatus.successful.contains(status);
  final delivered = OrderStatus.successful.contains(status);
  final ready = taken || status == OrderStatus.ready;
  final raw = <(String, String, bool)>[
    ('Commande acceptée', '$shop prépare la commande', true),
    ('Commande prête', 'En attente d\'un livreur', ready),
    (
      forDeliverer ? 'Aller au commerce' : 'Le livreur va au commerce',
      forDeliverer ? 'Récupérez la commande : $shop' : '$shop',
      taken
    ),
    (
      forDeliverer ? 'Livrer le client' : 'Le livreur arrive',
      zone.isEmpty ? 'En route' : 'En route vers $zone',
      picked
    ),
    (
      forDeliverer ? 'Arrivé chez le client' : 'Le livreur est arrivé',
      forDeliverer ? 'Prévenez le client' : 'Il vous attend',
      arrived
    ),
    ('Livrée', 'Commande remise', delivered),
  ];
  final firstOpen = raw.indexWhere((s) => !s.$3);
  return [
    for (var i = 0; i < raw.length; i++)
      TrackingStep(raw[i].$1, raw[i].$2, raw[i].$3,
          // Étape en cours : la première pas encore faite.
          i == firstOpen),
  ];
}

// ── Carte ────────────────────────────────────────────────────────────────

class _TrackingMap extends StatelessWidget {
  const _TrackingMap({this.rider, this.destination, this.height = 210});

  final ll.LatLng? rider;
  final ll.LatLng? destination;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final points = [if (rider != null) rider!, if (destination != null)
      destination!];
    Widget map;
    if (trackingTestMode) {
      map = Container(color: theme.alternate);
    } else {
      final fit = points.length == 2
          ? CameraFit.coordinates(
              coordinates: points,
              padding: const EdgeInsets.all(48),
              maxZoom: 16)
          : null;
      map = FlutterMap(
        key: ValueKey('${rider?.latitude},${rider?.longitude}'),
        options: MapOptions(
          initialCenter:
              points.isNotEmpty ? points.first : kBrazzavilleCenter,
          initialZoom: points.isNotEmpty ? 14.5 : 12,
          initialCameraFit: fit,
          interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'site.kitunga.app',
            maxZoom: 19,
          ),
          if (rider != null && destination != null)
            PolylineLayer(polylines: [
              Polyline(
                  points: [rider!, destination!],
                  strokeWidth: 3,
                  color: _red.withValues(alpha: 0.55),
                  pattern: StrokePattern.dashed(segments: const [8, 6])),
            ]),
          MarkerLayer(markers: [
            if (destination != null)
              Marker(
                point: destination!,
                width: 44,
                height: 44,
                child: const Icon(Icons.location_on_rounded,
                    color: _red, size: 40),
              ),
            if (rider != null)
              Marker(
                point: rider!,
                width: 46,
                height: 46,
                child: Container(
                  decoration: BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Color(0x33000000), blurRadius: 6)
                    ],
                  ),
                  child: const Icon(Icons.delivery_dining_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
          ]),
        ],
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(height: height, child: map),
    );
  }
}

// ── Étapes ───────────────────────────────────────────────────────────────

class _Timeline extends StatelessWidget {
  const _Timeline({required this.steps});

  final List<TrackingStep> steps;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: steps[i].done
                              ? _green
                              : steps[i].current
                                  ? _red
                                  : theme.alternate,
                        ),
                        child: Icon(
                            steps[i].done
                                ? Icons.check_rounded
                                : Icons.circle,
                            size: steps[i].done ? 15 : 7,
                            color: Colors.white),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2.5,
                            color: steps[i].done ? _green : theme.alternate,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i].title,
                            style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: steps[i].done || steps[i].current
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: steps[i].done || steps[i].current
                                    ? theme.primaryText
                                    : theme.secondaryText)),
                        Text(steps[i].subtitle,
                            style: GoogleFonts.inter(
                                fontSize: 12.5, color: theme.secondaryText)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Client : suivi en direct ─────────────────────────────────────────────

/// Carte « Suivi de la livraison » pour le client (et le commerce).
/// Se met à jour toutes les 10 secondes tant que la commande avance.
class KitungaLiveTrackingCard extends StatefulWidget {
  const KitungaLiveTrackingCard({super.key, required this.order});

  final OrdersRecord order;

  static bool showsFor(OrdersRecord order) =>
      _trackedStatuses.contains(order.status);

  @override
  State<KitungaLiveTrackingCard> createState() =>
      _KitungaLiveTrackingCardState();
}

class _KitungaLiveTrackingCardState extends State<KitungaLiveTrackingCard> {
  Map<String, dynamic>? _t;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void didUpdateWidget(covariant KitungaLiveTrackingCard old) {
    super.didUpdateWidget(old);
    if (old.order.status != widget.order.status) _load();
  }

  Future<void> _load() async {
    try {
      final t = await _call(
          'kitungaDeliveryTracking', {'orderId': widget.order.reference.id});
      if (mounted) setState(() => _t = t);
    } catch (_) {
      // Réseau coupé : on garde le dernier suivi.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final t = _t;
    if (t == null) return const SizedBox.shrink();
    final pos = t['position'] as Map?;
    final rider = pos == null
        ? null
        : ll.LatLng((pos['lat'] as num).toDouble(),
            (pos['lng'] as num).toDouble());
    // Porte du client si sa position exacte est connue, sinon son quartier.
    final dest = exactPointOf(t['deliveryPoint']) ??
        _zonePoint('${t['zone'] ?? ''}');
    final d = t['deliverer'] as Map?;
    final onTheWay = t['status'] == OrderStatus.delivering;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Suivi de la livraison',
                    style: GoogleFonts.interTight(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryText)),
              ),
              if (onTheWay)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.circle, size: 8, color: _green),
                      const SizedBox(width: 5),
                      Text('En direct',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _green)),
                    ],
                  ),
                ),
            ],
          ),
          if (onTheWay) ...[
            const SizedBox(height: 12),
            _TrackingMap(rider: rider, destination: dest),
            const SizedBox(height: 6),
            Text(
              rider == null
                  ? 'La position du livreur s\'affichera dès qu\'il partagera '
                      'sa localisation.'
                  : 'Position du livreur mise à jour '
                      '${_ago(_date(pos!['at']))}.',
              style:
                  GoogleFonts.inter(fontSize: 12, color: theme.secondaryText),
            ),
            // Heure d'arrivée estimée (commande récupérée, position connue).
            if (rider != null && dest != null && t['pickedUpAt'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    'Arrivée estimée vers '
                    '${_clockIn(etaMinutes(rider, dest))} '
                    '(≈ ${etaMinutes(rider, dest)} min)',
                    key: const ValueKey('client-eta'),
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        color: theme.primaryText)),
              ),
            if (t['delay'] is Map)
              Text(
                  'Retard annoncé : ${(t['delay'] as Map)['minutes']} min'
                  '${'${(t['delay'] as Map)['reason'] ?? ''}'.isEmpty ? '' : ' (${(t['delay'] as Map)['reason']})'}',
                  style: GoogleFonts.inter(
                      fontSize: 12.5, color: _red, fontWeight: FontWeight.w600)),
          ],
          if (d != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.alternate,
                  backgroundImage: '${d['photo'] ?? ''}'.isNotEmpty &&
                          !trackingTestMode
                      ? NetworkImage('${d['photo']}')
                      : null,
                  child: '${d['photo'] ?? ''}'.isEmpty || trackingTestMode
                      ? Icon(Icons.person_rounded, color: theme.secondaryText)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${d['name'] ?? ''}',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: theme.primaryText)),
                      Text('Votre livreur',
                          style: GoogleFonts.inter(
                              fontSize: 12.5, color: theme.secondaryText)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _Timeline(steps: trackingSteps(t)),
        ],
      ),
    );
  }
}

// ── Livreur : course en cours ────────────────────────────────────────────

/// Ouvre la page « Course en cours ».
Future<void> openDelivererMission(BuildContext context, OrdersRecord order) =>
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DelivererMissionPage(orderRef: order.reference)));

/// Page du livreur pendant une course : carte, étapes, action principale.
class DelivererMissionPage extends StatefulWidget {
  const DelivererMissionPage({super.key, required this.orderRef, this.stream});

  final DocumentReference orderRef;

  /// Remplace la lecture de la commande dans les tests.
  final Stream<OrdersRecord>? stream;

  @override
  State<DelivererMissionPage> createState() => _DelivererMissionPageState();
}

class _DelivererMissionPageState extends State<DelivererMissionPage> {
  Map<String, dynamic>? _t;
  ll.LatLng? _me;
  StreamSubscription<Position>? _gps;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _busy = false;
  String? _gpsProblem;

  @override
  void initState() {
    super.initState();
    _load();
    _startGps();
  }

  @override
  void dispose() {
    _gps?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await _call(
          'kitungaDeliveryTracking', {'orderId': widget.orderRef.id});
      if (mounted) setState(() => _t = t);
    } catch (_) {}
  }

  /// Partage la position (au plus toutes les 15 s) pendant la course.
  Future<void> _startGps() async {
    if (trackingTestMode) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return setState(() => _gpsProblem = 'Activez la localisation du '
            'téléphone pour que le client vous suive.');
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        return setState(() => _gpsProblem = 'Autorisez la localisation pour '
            'que le client vous suive.');
      }
      _gps = Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high, distanceFilter: 15))
          .listen(_onPosition);
    } catch (_) {
      if (mounted) {
        setState(() => _gpsProblem = 'Localisation indisponible.');
      }
    }
  }

  Future<void> _onPosition(Position p) async {
    if (!mounted) return;
    setState(() {
      _me = ll.LatLng(p.latitude, p.longitude);
      _gpsProblem = null;
    });
    if (DateTime.now().difference(_lastSent).inSeconds < 15) return;
    _lastSent = DateTime.now();
    try {
      await _call('kitungaDeliveryPosition', {
        'orderId': widget.orderRef.id,
        'lat': p.latitude,
        'lng': p.longitude,
        'accuracy': p.accuracy,
      });
    } catch (_) {
      // Course terminée ou réseau coupé : on réessaiera au prochain point.
    }
  }

  Future<void> _pickedUp() => _step('picked_up');

  /// Arrivée au commerce (le vendeur est prévenu).
  Future<void> _atShop() async {
    setState(() => _busy = true);
    try {
      await proCall('kitungaArrivedAtShop', {'orderId': widget.orderRef.id});
      _snack('Le commerce est prévenu de votre arrivée.');
      await _load();
    } on ServerPaymentException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Impossible pour le moment. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Retard annoncé au client et au commerce.
  Future<void> _delay() async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Retard estimé',
                  style: GoogleFonts.interTight(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Le client et le commerce seront prévenus.'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in const [10, 20, 30, 45, 60])
                    ActionChip(
                      key: ValueKey('delay-$m'),
                      label: Text('$m min'),
                      onPressed: () => Navigator.pop(c, m),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (minutes == null) return;
    try {
      await proCall('kitungaReportDelay',
          {'orderId': widget.orderRef.id, 'minutes': minutes});
      _snack('Retard annoncé au client et au commerce.');
      await _load();
    } on ServerPaymentException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Impossible pour le moment. Réessayez.');
    }
  }

  /// Étape de la course : 'picked_up' (récupérée) ou 'arrived' (arrivé).
  Future<void> _step(String step) async {
    setState(() => _busy = true);
    try {
      await _call('kitungaDeliveryStep',
          {'orderId': widget.orderRef.id, 'step': step});
      await _load();
    } on ServerPaymentException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Impossible pour le moment. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  /// Destination du livreur : le commerce avant la récupération, le client
  /// ensuite ; position exacte si connue, sinon centre du quartier.
  ll.LatLng? _target(OrdersRecord o, bool picked) => picked
      ? exactPointOf(_t?['deliveryPoint']) ?? _zonePoint(o.deliveryZone)
      : exactPointOf(_t?['shopPoint']) ??
          _zonePoint('${_t?['shopZone'] ?? ''}') ??
          _zonePoint(o.deliveryZone);

  void _route(OrdersRecord o, bool picked) {
    final dest = _target(o, picked);
    final url = dest != null
        ? 'https://www.google.com/maps/dir/?api=1&destination='
            '${dest.latitude},${dest.longitude}&travelmode=driving'
        : 'https://www.google.com/maps/search/?api=1&query='
            '${Uri.encodeComponent('${o.deliveryLocation} ${o.deliveryZone} Brazzaville')}';
    launchURL(url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0,
        title: Text('Course en cours',
            style: GoogleFonts.interTight(fontWeight: FontWeight.w800)),
        actions: [
          // Urgence : prévient l'équipe avec la position.
          IconButton(
            key: const ValueKey('mission-sos'),
            tooltip: 'Urgence',
            onPressed: () =>
                sendSafetyAlert(context, orderId: widget.orderRef.id),
            icon: const Icon(Icons.sos_rounded, color: _red),
          ),
        ],
      ),
      body: StreamBuilder<OrdersRecord>(
        stream: widget.stream ?? OrdersRecord.getDocument(widget.orderRef),
        builder: (context, snap) {
          final o = snap.data;
          if (o == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final t = {...?_t, 'status': o.status};
          final mine = o.delivererRef == currentUserUid ||
              o.deliverReference?.id == currentUserUid ||
              widget.stream != null;
          final onTheWay = o.status == OrderStatus.delivering && mine;
          final picked = _t?['pickedUpAt'] != null;
          final shop = (_t?['shop'] as Map?)?['name'] ?? 'le commerce';
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              // Avant la récupération : vers le commerce ; ensuite : le client.
              _TrackingMap(
                  rider: _me, destination: _target(o, picked), height: 240),
              if (_gpsProblem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    const Icon(Icons.gps_off_rounded,
                        size: 18, color: _red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_gpsProblem!,
                          style: GoogleFonts.inter(
                              fontSize: 12.5, color: _red)),
                    ),
                  ]),
                ),
              const SizedBox(height: 14),
              // Destination et gain de la course.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        picked
                            ? 'Étape 2 · Livrer le client'
                            : 'Étape 1 · Récupérer la commande',
                        style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _red)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Expanded(
                        child: Text(
                            picked
                                ? (o.deliveryZone.isEmpty
                                    ? 'Chez le client'
                                    : o.deliveryZone)
                                : '$shop',
                            style: GoogleFonts.interTight(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: theme.primaryText)),
                      ),
                      Text('${o.deliveryFees.round()} F',
                          style: GoogleFonts.interTight(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _green)),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                        [
                          'Commande ${o.orderUniqueReference}',
                          if (o.deliveryLocation.isNotEmpty)
                            o.deliveryLocation,
                        ].join(' · '),
                        style: GoogleFonts.inter(
                            fontSize: 13, color: theme.secondaryText)),
                    // Temps estimé depuis ma position (commerce, puis client).
                    Builder(builder: (context) {
                      final target = _target(o, picked);
                      if (_me == null || target == null) {
                        return const SizedBox.shrink();
                      }
                      final m = etaMinutes(_me!, target);
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                            '≈ $m min · arrivée vers ${_clockIn(m)}',
                            key: const ValueKey('mission-eta'),
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _green)),
                      );
                    }),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const ValueKey('mission-route'),
                      onPressed: () => _route(o, picked),
                      icon: const Icon(Icons.navigation_rounded),
                      label: Text(picked
                          ? 'Itinéraire vers le client'
                          : 'Itinéraire vers le commerce'),
                    ),
                  ],
                ),
              ),
              KitungaOrderContacts(order: o),
              const SizedBox(height: 14),
              if (_t != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  decoration: BoxDecoration(
                    color: theme.secondaryBackground,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: _Timeline(
                      steps: trackingSteps(t, forDeliverer: true)),
                ),
              const SizedBox(height: 16),
              // Arrivée au commerce : le vendeur est prévenu.
              if (onTheWay && !picked && _t?['atShopAt'] == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton.icon(
                    key: const ValueKey('mission-at-shop'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16))),
                    onPressed: _busy ? null : _atShop,
                    icon: const Icon(Icons.storefront_rounded),
                    label: const Text('Je suis arrivé au commerce'),
                  ),
                ),
              if (onTheWay && !picked)
                FilledButton.icon(
                  key: const ValueKey('mission-picked-up'),
                  style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: _red,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  onPressed: _busy ? null : _pickedUp,
                  icon: const Icon(Icons.shopping_bag_rounded),
                  label: Text('J\'ai récupéré la commande',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              if (onTheWay && picked && _t?['arrivedAt'] == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton.icon(
                    key: const ValueKey('mission-arrived'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16))),
                    onPressed: _busy ? null : () => _step('arrived'),
                    icon: const Icon(Icons.where_to_vote_rounded),
                    label: const Text('Je suis arrivé chez le client'),
                  ),
                ),
              if (onTheWay && picked)
                FilledButton.icon(
                  key: const ValueKey('mission-deliver'),
                  style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: _green,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  onPressed: () async {
                    final done = await kitungaCompleteDelivery(context, o);
                    if (done && context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.verified_rounded),
                  label: Text('Remettre au client (code + photo)',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              if (onTheWay)
                TextButton.icon(
                  key: const ValueKey('mission-delay'),
                  onPressed: _delay,
                  icon: const Icon(Icons.schedule_rounded),
                  label: const Text('Je suis en retard'),
                ),
              if (onTheWay)
                TextButton.icon(
                  onPressed: () => kitungaReportDeliveryIssue(context, o),
                  icon: const Icon(Icons.report_gmailerrorred_rounded,
                      color: _red),
                  label: const Text('Signaler un problème',
                      style: TextStyle(color: _red)),
                ),
              if (!onTheWay)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      o.status == OrderStatus.delivered ||
                              o.status == OrderStatus.received
                          ? 'Course terminée. Merci !'
                          : 'Cette course n\'est plus en cours.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: theme.secondaryText)),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Bandeau « Course en cours » en haut de l'accueil du livreur.
class KitungaActiveDeliveryBanner extends StatelessWidget {
  const KitungaActiveDeliveryBanner({super.key, required this.orders});

  /// Courses en cours du livreur.
  final List<OrdersRecord> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return const SizedBox.shrink();
    final o = orders.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Material(
        color: _red,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: const ValueKey('active-delivery'),
          borderRadius: BorderRadius.circular(18),
          onTap: () => openDelivererMission(context, o),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.delivery_dining_rounded,
                      color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          orders.length > 1
                              ? '${orders.length} courses en cours'
                              : 'Course en cours',
                          style: GoogleFonts.interTight(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      Text(
                          'Vers ${o.deliveryZone.isEmpty ? 'le client' : o.deliveryZone}'
                          ' · ${o.deliveryFees.round()} F',
                          style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte d'une course dans la liste du livreur : commerce → quartier, gain,
/// heure, et l'action principale (Accepter / Continuer la course).
class KitungaCourseCard extends StatelessWidget {
  const KitungaCourseCard({
    super.key,
    required this.order,
    required this.mine,
    required this.onAction,
    this.onDetails,
  });

  final OrdersRecord order;

  /// Course attribuée au livreur connecté.
  final bool mine;
  final Future<void> Function() onAction;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final o = order;
    final ready = o.status == OrderStatus.ready;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: mine ? _red.withValues(alpha: 0.45) : theme.alternate),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3))
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onDetails,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: (ready ? _green : _red).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(ready ? 'Prête à récupérer' : 'En livraison',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: ready ? _green : _red)),
                  ),
                  const Spacer(),
                  if (o.createdAt != null)
                    Text(dateTimeFormatFr(o.createdAt!),
                        style: GoogleFonts.inter(
                            fontSize: 12, color: theme.secondaryText)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.storefront_rounded,
                          size: 20, color: _red),
                      Container(
                          width: 2, height: 18, color: theme.alternate),
                      const Icon(Icons.location_on_rounded,
                          size: 20, color: _green),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ShopName(order: o),
                        const SizedBox(height: 18),
                        Text(
                            o.deliveryZone.isEmpty
                                ? 'Brazzaville'
                                : o.deliveryZone,
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: theme.primaryText)),
                        if (o.deliveryLocation.isNotEmpty)
                          Text(o.deliveryLocation,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: theme.secondaryText)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${o.deliveryFees.round()} F',
                          style: GoogleFonts.interTight(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _green)),
                      Text('livraison',
                          style: GoogleFonts.inter(
                              fontSize: 11.5, color: theme.secondaryText)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: mine ? _red : _green,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: onAction,
                icon: Icon(mine
                    ? Icons.navigation_rounded
                    : Icons.check_circle_rounded),
                label: Text(mine ? 'Continuer la course' : 'Accepter la course',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String dateTimeFormatFr(DateTime d) {
  final now = DateTime.now();
  final t = '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    return 'Aujourd\'hui $t';
  }
  return '${d.day}/${d.month} $t';
}

/// Nom du commerce (lu une fois depuis la commande).
class _ShopName extends StatelessWidget {
  const _ShopName({required this.order});

  final OrdersRecord order;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final style = GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w700, color: theme.primaryText);
    final ref = order.sellerRef;
    if (ref == null || trackingTestMode) {
      return Text('Commerce', style: style);
    }
    return FutureBuilder<UserRecord>(
      future: UserRecord.getDocumentOnce(ref),
      builder: (context, snap) => Text(
          snap.data?.displayName.isNotEmpty == true
              ? snap.data!.displayName
              : 'Commerce',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style),
    );
  }
}
