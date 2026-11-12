import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/order_status.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart' show OrderViewSellerDeliverWidget;
import '/mobile/components/delivery/kitunga_deliverer_panel.dart';
import '/mobile/components/delivery/kitunga_delivery.dart'
    show kitungaTakeDelivery;
import '/mobile/components/delivery/kitunga_live_tracking.dart';
import '/noc/admin/brazzaville_zones.dart'
    show kBrazzavilleCenter, kBrazzavilleZones;
import 'kitunga_deliverer_home.dart';

/// Onglets « Mes courses » et « Carte » de l'espace livreur.

const _red = Color(0xFFE51A1A);
const _green = Color(0xFF17A35B);

Stream<List<OrdersRecord>> _myOrders() => delivererMyOrdersStream();

Stream<List<OrdersRecord>> _openOrders() => delivererOpenOrdersStream();

bool _isIncident(OrdersRecord o) =>
    o.status == OrderStatus.notReceived ||
    o.snapshotData['delivery_issue'] != null;

void _openOrder(BuildContext context, OrdersRecord o) {
  if (o.status == OrderStatus.delivering) {
    openDelivererMission(context, o);
    return;
  }
  context.pushNamed(
    OrderViewSellerDeliverWidget.routeName,
    queryParameters: {
      'orderRefer': serializeParam(o.orderUniqueReference, ParamType.String),
      'deliveryZone': serializeParam(o.deliveryZone, ParamType.String),
      'statu': serializeParam(o.status, ParamType.String),
      'amount': serializeParam('${o.totalAmount}', ParamType.String),
    }.withoutNulls,
  );
}

// ── Mes courses ──────────────────────────────────────────────────────────

class KitungaDelivererCourses extends StatefulWidget {
  const KitungaDelivererCourses({super.key});

  @override
  State<KitungaDelivererCourses> createState() =>
      _KitungaDelivererCoursesState();
}

class _KitungaDelivererCoursesState extends State<KitungaDelivererCourses> {
  late final Stream<List<OrdersRecord>> _stream = _myOrders();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.primaryBackground,
        appBar: AppBar(
          backgroundColor: theme.secondaryBackground,
          foregroundColor: theme.primaryText,
          automaticallyImplyLeading: false,
          elevation: 0,
          title: Text('Mes courses',
              style: GoogleFonts.interTight(fontWeight: FontWeight.w800)),
          bottom: TabBar(
            labelColor: _red,
            indicatorColor: _red,
            unselectedLabelColor: theme.secondaryText,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'En cours'),
              Tab(text: 'Terminées'),
              Tab(text: 'Incidents'),
            ],
          ),
        ),
        body: StreamBuilder<List<OrdersRecord>>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return const _Message(
                  icon: Icons.wifi_off_rounded,
                  text: 'Connexion perdue. Vos courses s\'afficheront dès '
                      'le retour du réseau.');
            }
            if (!snap.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: _red));
            }
            final all = [...snap.data!]..sort((a, b) =>
                (b.createdAt ?? DateTime(0))
                    .compareTo(a.createdAt ?? DateTime(0)));
            final running =
                all.where((o) => o.status == OrderStatus.delivering).toList();
            final done = all
                .where((o) => OrderStatus.finished.contains(o.status))
                .toList();
            final incidents = all.where(_isIncident).toList();
            final total = done
                .where((o) => OrderStatus.successful.contains(o.status))
                .fold<double>(0, (s, o) => s + o.deliveryFees);
            return TabBarView(
              children: [
                _CourseList(
                    orders: running,
                    empty: 'Aucune course en cours. Acceptez une course '
                        'depuis l\'accueil.'),
                _CourseList(
                    orders: done,
                    header: done.isEmpty
                        ? null
                        : '${done.where((o) => OrderStatus.successful.contains(o.status)).length} '
                            'livrées · ${NumberFormat.decimalPattern('fr').format(total)} F '
                            'de frais de livraison',
                    empty: 'Pas encore de course terminée.'),
                _CourseList(
                    orders: incidents,
                    empty: 'Aucun incident. Tant mieux !'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CourseList extends StatelessWidget {
  const _CourseList({required this.orders, required this.empty, this.header});

  final List<OrdersRecord> orders;
  final String empty;
  final String? header;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    if (orders.isEmpty) {
      return _Message(icon: Icons.inbox_rounded, text: empty);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 4),
            child: Text(header!,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: theme.primaryText)),
          ),
        for (final o in orders)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: theme.secondaryBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.alternate),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                onTap: () => _openOrder(context, o),
                leading: CircleAvatar(
                  backgroundColor: courseStatusOf(o).color.withValues(alpha: 0.12),
                  child: Icon(
                      _isIncident(o)
                          ? Icons.report_gmailerrorred_rounded
                          : o.status == OrderStatus.delivering
                              ? Icons.delivery_dining_rounded
                              : Icons.task_alt_rounded,
                      color: courseStatusOf(o).color),
                ),
                title: Text(
                    o.deliveryZone.isEmpty ? 'Brazzaville' : o.deliveryZone,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: theme.primaryText)),
                subtitle: Text(
                    [
                      'N° ${o.orderUniqueReference}',
                      if (o.createdAt != null) dateTimeFormatFr(o.createdAt!),
                      if (o.snapshotData['delivery_issue'] is Map)
                        '${(o.snapshotData['delivery_issue'] as Map)['label'] ?? 'Problème signalé'}',
                    ].join(' · '),
                    style: GoogleFonts.inter(
                        fontSize: 12, color: theme.secondaryText)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(courseStatusOf(o).label,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: courseStatusOf(o).color)),
                    Text(
                        '${NumberFormat.decimalPattern('fr').format(o.deliveryFees)} F',
                        style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: theme.primaryText)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: _red.withValues(alpha: 0.08),
              child: Icon(icon, color: _red, size: 30),
            ),
            const SizedBox(height: 14),
            Text(text,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 14, color: theme.secondaryText)),
          ],
        ),
      ),
    );
  }
}

// ── Carte ────────────────────────────────────────────────────────────────

/// Carte du livreur : sa position, ses courses en cours (destination) et
/// les courses prêtes de ses quartiers (point de collecte).
class KitungaDelivererMap extends StatefulWidget {
  const KitungaDelivererMap({super.key});

  @override
  State<KitungaDelivererMap> createState() => _KitungaDelivererMapState();
}

class _KitungaDelivererMapState extends State<KitungaDelivererMap> {
  late final Stream<List<OrdersRecord>> _mine = _myOrders();
  late final Stream<List<OrdersRecord>> _open = _openOrders();
  ll.LatLng? _me;
  String? _gps;

  @override
  void initState() {
    super.initState();
    if (!delivererSimulated) _locate();
  }

  Future<void> _locate() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _gps = 'Autorisez la localisation pour voir votre '
              'position.');
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _me = ll.LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      if (mounted) setState(() => _gps = 'Localisation indisponible.');
    }
  }

  void _showCourse(OrdersRecord o, bool mine) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: KitungaCourseCard(
            order: o,
            mine: mine,
            onDetails: () => _openOrder(c, o),
            onAction: () async {
              Navigator.pop(c);
              if (mine) {
                await openDelivererMission(context, o);
              } else {
                final taken = await kitungaTakeDelivery(context, o);
                if (taken && mounted) {
                  await openDelivererMission(context, o);
                }
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return DelivererStateBuilder(
      builder: (context, state) => StreamBuilder<List<OrdersRecord>>(
        stream: _mine,
        builder: (context, mineSnap) => StreamBuilder<List<OrdersRecord>>(
          stream: _open,
          builder: (context, openSnap) {
            final now = DateTime.now();
            final active = (mineSnap.data ?? const <OrdersRecord>[])
                .where((o) => o.status == OrderStatus.delivering)
                .toList();
            final ready = state.state != 'on'
                ? const <OrdersRecord>[]
                : (openSnap.data ?? const <OrdersRecord>[])
                    .where((o) =>
                        o.status == OrderStatus.ready &&
                        o.delivererRef.isEmpty &&
                        !offeredToOther(o, currentUserUid, now) &&
                        delivererCovers(state.zones, o.deliveryZone))
                    .toList();
            ll.LatLng? pointOf(OrdersRecord o, {bool pickup = false}) {
              final shop = '${o.snapshotData['shop_zone'] ?? ''}';
              return pickup && kBrazzavilleZones[shop] != null
                  ? kBrazzavilleZones[shop]
                  : kBrazzavilleZones[o.deliveryZone];
            }

            final markers = <Marker>[
              for (final o in ready)
                if (pointOf(o, pickup: true) != null)
                  Marker(
                    point: pointOf(o, pickup: true)!,
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () => _showCourse(o, false),
                      child: const _Pin(
                          icon: Icons.storefront_rounded, color: _green),
                    ),
                  ),
              for (final o in active)
                if (pointOf(o) != null)
                  Marker(
                    point: pointOf(o)!,
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () => _showCourse(o, true),
                      child: const _Pin(
                          icon: Icons.location_on_rounded, color: _red),
                    ),
                  ),
              if (_me != null)
                Marker(
                  point: _me!,
                  width: 44,
                  height: 44,
                  child: const _Pin(
                      icon: Icons.delivery_dining_rounded,
                      color: Color(0xFF1E242B)),
                ),
            ];
            return Stack(
              children: [
                Positioned.fill(
                  child: delivererSimulated
                      ? Container(color: theme.alternate)
                      : FlutterMap(
                          options: MapOptions(
                            initialCenter: _me ?? kBrazzavilleCenter,
                            initialZoom: 12.5,
                            interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.all &
                                    ~InteractiveFlag.rotate),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'site.kitunga.app',
                              maxZoom: 19,
                            ),
                            MarkerLayer(markers: markers),
                          ],
                        ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: MediaQuery.paddingOf(context).top + 12,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.secondaryBackground,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Color(0x22000000), blurRadius: 12)
                      ],
                    ),
                    child: Row(
                      children: [
                        const _Pin(
                            icon: Icons.storefront_rounded,
                            color: _green,
                            size: 30),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              state.state != 'on'
                                  ? 'Passez en service pour voir les courses '
                                      'prêtes.'
                                  : '${ready.length} course(s) prête(s) · '
                                      '${active.length} en cours',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: theme.primaryText)),
                        ),
                        IconButton(
                          tooltip: 'Ma position',
                          onPressed: _locate,
                          icon: const Icon(Icons.my_location_rounded,
                              color: _red),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_gps != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_gps!,
                          style: GoogleFonts.inter(fontSize: 13)),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.icon, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 6)
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.55),
      );
}
