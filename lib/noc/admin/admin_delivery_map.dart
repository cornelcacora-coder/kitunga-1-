import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '/backend/order_status.dart';
import '/noc/sales/sales_common.dart' show fcfa;
import '/noc/ui/admin_kit.dart';
import 'admin_dashboard_data.dart';
import 'admin_order_detail.dart';
import 'brazzaville_zones.dart';

/// Quartier sur la carte : commandes en cours et leur situation.
typedef MapZone = ({
  String name,
  LatLng point,
  List<DashOrder> orders,
  int delivering,
  int late,
});

/// Regroupe les commandes en cours par quartier connu (pur, testé) ; les
/// commandes dont le quartier n'est pas reconnu sont renvoyées à part.
({List<MapZone> zones, List<DashOrder> unplaced}) mapZones(
    List<DashOrder> live, DateTime now) {
  final groups = <String, List<DashOrder>>{};
  final points = <String, LatLng>{};
  final unplaced = <DashOrder>[];
  for (final o in live) {
    final p = zonePosition(o.zone);
    if (p == null) {
      unplaced.add(o);
      continue;
    }
    groups.putIfAbsent(p.name, () => []).add(o);
    points[p.name] = p.point;
  }
  final zones = [
    for (final e in groups.entries)
      (
        name: e.key,
        point: points[e.key]!,
        orders: e.value,
        delivering:
            e.value.where((o) => o.status == OrderStatus.delivering).length,
        late: e.value
            .where((o) =>
                o.createdAt != null &&
                now.difference(o.createdAt!) > const Duration(hours: 2))
            .length,
      ),
  ]..sort((a, b) => b.orders.length - a.orders.length);
  return (zones: zones, unplaced: unplaced);
}

Color mapZoneColor(MapZone z) => z.late > 0
    ? AdminColors.red
    : z.delivering > 0
        ? AdminColors.blue
        : AdminColors.orange;

/// Carte des livraisons en cours (OpenStreetMap, sans clé).
class AdminDeliveryMap extends StatefulWidget {
  const AdminDeliveryMap({
    super.key,
    required this.orders,
    required this.now,
    this.height = 420.0,
    this.people = const {},
  });

  /// Commandes en cours.
  final List<DashOrder> orders;
  final DateTime now;
  final double height;
  final Map<String, ({String name, String photo, String phone})> people;

  /// Fond de carte (désactivé dans les tests : pas de réseau).
  static bool showTiles = true;

  @override
  State<AdminDeliveryMap> createState() => _AdminDeliveryMapState();
}

class _AdminDeliveryMapState extends State<AdminDeliveryMap> {
  final _map = MapController();
  static const _zoom = 12.4;

  void _zoomBy(double d) {
    final c = _map.camera;
    _map.move(c.center, (c.zoom + d).clamp(10.0, 17.0));
  }

  void _openZone(MapZone z) {
    showDialog(
      context: context,
      builder: (dialogContext) => AdminThemeScope(
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.place_rounded, color: mapZoneColor(z)),
              const SizedBox(width: 8.0),
              Expanded(child: Text(z.name)),
            ],
          ),
          content: SizedBox(
            width: 460.0,
            height: math.min(420.0, 90.0 + z.orders.length * 64.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(spacing: 6.0, runSpacing: 6.0, children: [
                  AdminBadge('${z.orders.length} en cours', tone: kToneOrange),
                  if (z.delivering > 0)
                    AdminBadge('${z.delivering} en livraison', tone: kToneBlue),
                  if (z.late > 0)
                    AdminBadge('${z.late} en retard', tone: kToneRed),
                ]),
                const SizedBox(height: 12.0),
                Expanded(
                  child: ListView(
                    children: [
                      for (final o in z.orders)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              o.reference.isEmpty ? 'Sans référence' : o.reference,
                              style: AdminText.strong(size: 13.5)),
                          subtitle: Text(
                              [
                                o.location,
                                if (o.createdAt != null)
                                  'depuis ${adminDuration(widget.now.difference(o.createdAt!))}',
                              ].where((s) => s.trim().isNotEmpty).join(' · '),
                              style: AdminText.label(size: 12.0)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(fcfa(o.total),
                                  style: AdminText.strong(size: 13.0)),
                              const SizedBox(width: 8.0),
                              AdminBadge(orderStatusShort(o.status),
                                  tone: orderStatusTone(o.status)),
                            ],
                          ),
                          onTap: () {
                            Navigator.pop(dialogContext);
                            showAdminOrderDetail(context, o,
                                known: widget.people);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Fermer')),
          ],
        ),
      ),
    );
  }

  Widget _bubble(MapZone z) {
    final n = z.orders.length;
    final size = 30.0 + math.min(n, 15) * 2.4;
    final color = mapZoneColor(z);
    return Tooltip(
      message: '${z.name} · $n en cours'
          '${z.delivering > 0 ? ' · ${z.delivering} en livraison' : ''}'
          '${z.late > 0 ? ' · ${z.late} en retard' : ''}',
      child: GestureDetector(
        onTap: () => _openZone(z),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Center(
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3.0),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 12.0,
                      spreadRadius: 2.0),
                ],
              ),
              child: Text('$n',
                  style: AdminText.strong(color: Colors.white, size: 13.0)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _control(IconData icon, String tooltip, VoidCallback onTap) => Tooltip(
        message: tooltip,
        child: Material(
          color: AdminColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
              side: BorderSide(color: AdminColors.border)),
          child: InkWell(
            borderRadius: BorderRadius.circular(10.0),
            onTap: onTap,
            child: SizedBox(
                width: 38.0,
                height: 38.0,
                child: Icon(icon, size: 20.0, color: AdminColors.ink)),
          ),
        ),
      );

  Widget _legendDot(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10.0,
              height: 10.0,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6.0),
          Text(label, style: AdminText.label(size: 12.0, color: AdminColors.text)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final r = mapZones(widget.orders, widget.now);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AdminRadius.md),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: kBrazzavilleCenter,
                initialZoom: _zoom,
                minZoom: 10.0,
                maxZoom: 17.0,
                backgroundColor: AdminColors.surfaceAlt,
                // Pas de zoom à la molette : elle doit faire défiler la page
                // (boutons + / −, glisser et pincer restent disponibles).
                interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all &
                        ~InteractiveFlag.rotate &
                        ~InteractiveFlag.scrollWheelZoom),
              ),
              children: [
                if (AdminDeliveryMap.showTiles)
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'site.kitunga.admin',
                    maxZoom: 19,
                    tileBuilder: AdminColors.dark ? darkModeTileBuilder : null,
                  ),
                MarkerLayer(
                  markers: [
                    for (final z in r.zones)
                      Marker(
                        point: z.point,
                        width: 70.0,
                        height: 70.0,
                        child: _bubble(z),
                      ),
                  ],
                ),
              ],
            ),
            // Crédit obligatoire du fond de carte (s'adapte à la largeur).
            Positioned(
              left: 8.0,
              bottom: 6.0,
              right: 70.0,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: AdminColors.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text('© contributeurs OpenStreetMap',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminText.label(size: 10.5)),
                ),
              ),
            ),
            // Légende et résumé.
            Positioned(
              top: 12.0,
              left: 12.0,
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AdminColors.surface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: kAdminShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${widget.orders.length} commande${widget.orders.length > 1 ? 's' : ''} en cours',
                        style: AdminText.strong(size: 13.0)),
                    const SizedBox(height: 8.0),
                    _legendDot(AdminColors.orange, 'En attente / préparation'),
                    const SizedBox(height: 4.0),
                    _legendDot(AdminColors.blue, 'En livraison'),
                    const SizedBox(height: 4.0),
                    _legendDot(AdminColors.red, 'Retard (+2 h)'),
                    if (r.unplaced.isNotEmpty) ...[
                      const SizedBox(height: 8.0),
                      Text(
                          '${r.unplaced.length} sans quartier reconnu',
                          style: AdminText.label(
                              size: 11.5, color: AdminColors.muted)),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12.0,
              bottom: 30.0,
              child: Column(
                children: [
                  _control(Icons.add_rounded, 'Zoomer', () => _zoomBy(1)),
                  const SizedBox(height: 6.0),
                  _control(Icons.remove_rounded, 'Dézoomer', () => _zoomBy(-1)),
                  const SizedBox(height: 6.0),
                  _control(Icons.center_focus_strong_rounded, 'Recentrer',
                      () => _map.move(kBrazzavilleCenter, _zoom)),
                ],
              ),
            ),
            if (widget.orders.isEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 10.0),
                      decoration: BoxDecoration(
                        color: AdminColors.surface.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(AdminRadius.pill),
                        boxShadow: kAdminShadow,
                      ),
                      child: Text('Aucune commande en cours',
                          style: AdminText.strong(size: 13.0)),
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
