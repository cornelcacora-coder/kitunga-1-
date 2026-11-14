import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart' as ll;

/// Carte de l'application mobile (client et livreur).
///
/// - Android avec une clé Google Maps dans l'application
///   (android/local.properties : MAPS_API_KEY=…) : carte Google Maps.
/// - Sinon (clé absente, iOS, tests) : carte OpenStreetMap, comme avant.
///   Rien ne casse si la clé manque : la carte reste affichée.
///
/// Comportement commun :
/// - [follow] : la carte se recadre sur [fitPoints] à chaque mise à jour,
///   jusqu'à ce que l'utilisateur la déplace ou zoome ; un bouton
///   « Recentrer » revient alors au cadrage automatique ;
/// - [controller] : déplacer la carte depuis la page (ex. « Ma position »).

/// Un repère sur la carte.
class KitungaMapMarker {
  const KitungaMapMarker({
    required this.id,
    required this.point,
    required this.icon,
    required this.color,
    this.round = false,
    this.onTap,
  });

  final String id;
  final ll.LatLng point;
  final IconData icon;
  final Color color;

  /// Rond plein (livreur) ; sinon icône seule (épingle, commerce…).
  final bool round;
  final VoidCallback? onTap;
}

/// Un tracé (route réelle ou repère pointillé).
class KitungaMapLine {
  const KitungaMapLine(
      {required this.points,
      required this.color,
      this.width = 5,
      this.dashed = false});

  final List<ll.LatLng> points;
  final Color color;
  final double width;
  final bool dashed;
}

/// Commande de la carte depuis la page.
class KitungaMapController {
  _KitungaMapViewState? _state;

  /// Centre la carte sur [point] (et quitte le suivi automatique).
  void moveTo(ll.LatLng point, {double zoom = 15}) =>
      _state?._moveTo(point, zoom);
}

/// Faux dans les tests et hors Android : carte OpenStreetMap.
@visibleForTesting
Future<bool> Function()? kitungaGoogleMapsOverride;

/// Faux dans les tests : pas de fond de carte (pas de réseau).
@visibleForTesting
bool kitungaMapShowTiles = true;

const _channel = MethodChannel('site.kitunga.app/config');
Future<bool>? _googleMaps;

/// Vrai si l'application Android contient une clé Google Maps.
Future<bool> kitungaGoogleMapsAvailable() {
  if (kitungaGoogleMapsOverride != null) return kitungaGoogleMapsOverride!();
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return Future.value(false);
  }
  return _googleMaps ??= _channel
      .invokeMethod<bool>('hasMapsKey')
      .then((v) => v == true)
      .catchError((_) => false);
}

class KitungaMapView extends StatefulWidget {
  const KitungaMapView({
    super.key,
    this.markers = const [],
    this.lines = const [],
    this.fitPoints = const [],
    this.follow = false,
    this.initialCenter,
    this.initialZoom = 12.5,
    this.controller,
    this.recenterBottom = 10,
  });

  final List<KitungaMapMarker> markers;
  final List<KitungaMapLine> lines;

  /// Points à garder visibles (cadrage automatique).
  final List<ll.LatLng> fitPoints;

  /// Recadrer sur [fitPoints] à chaque mise à jour (suivi en direct).
  final bool follow;
  final ll.LatLng? initialCenter;
  final double initialZoom;
  final KitungaMapController? controller;

  /// Position verticale du bouton « Recentrer ».
  final double recenterBottom;

  @override
  State<KitungaMapView> createState() => _KitungaMapViewState();
}

class _KitungaMapViewState extends State<KitungaMapView> {
  bool? _google;

  /// L'utilisateur a déplacé ou zoomé la carte : on ne la recadre plus.
  bool _userMoved = false;

  // OpenStreetMap
  final _fm = fm.MapController();
  bool _fmReady = false;

  // Google Maps
  gm.GoogleMapController? _gm;
  bool _programmatic = false;
  final Map<String, gm.BitmapDescriptor> _icons = {};

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    kitungaGoogleMapsAvailable().then((v) {
      if (mounted) setState(() => _google = v);
    });
  }

  @override
  void didUpdateWidget(covariant KitungaMapView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (old.controller?._state == this) old.controller?._state = null;
      widget.controller?._state = this;
    }
    if (widget.follow &&
        !_userMoved &&
        !listEquals(old.fitPoints, widget.fitPoints)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_userMoved) _fit();
      });
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller?._state = null;
    _fm.dispose();
    _gm?.dispose();
    super.dispose();
  }

  ll.LatLng get _center =>
      widget.fitPoints.isNotEmpty
          ? widget.fitPoints.first
          : widget.initialCenter ?? const ll.LatLng(-4.2634, 15.2429);

  void _fit() {
    final pts = widget.fitPoints;
    if (pts.isEmpty) return;
    if (_google == true) {
      final c = _gm;
      if (c == null) return;
      _programmatic = true;
      if (pts.length == 1) {
        c.animateCamera(gm.CameraUpdate.newLatLng(_g(pts.first)));
      } else {
        c.animateCamera(gm.CameraUpdate.newLatLngBounds(_bounds(pts), 48));
      }
    } else if (_fmReady) {
      if (pts.length == 1) {
        _fm.move(pts.first, _fm.camera.zoom);
      } else {
        _fm.fitCamera(fm.CameraFit.coordinates(
            coordinates: pts,
            padding: const EdgeInsets.all(48),
            maxZoom: 16));
      }
    }
  }

  void _moveTo(ll.LatLng p, double zoom) {
    setState(() => _userMoved = widget.follow);
    if (_google == true) {
      _programmatic = true;
      _gm?.animateCamera(gm.CameraUpdate.newLatLngZoom(_g(p), zoom));
    } else if (_fmReady) {
      _fm.move(p, zoom);
    }
  }

  void _recenter() {
    setState(() => _userMoved = false);
    _fit();
  }

  static gm.LatLng _g(ll.LatLng p) => gm.LatLng(p.latitude, p.longitude);

  static gm.LatLngBounds _bounds(List<ll.LatLng> pts) {
    var s = pts.first.latitude, n = s;
    var w = pts.first.longitude, e = w;
    for (final p in pts) {
      if (p.latitude < s) s = p.latitude;
      if (p.latitude > n) n = p.latitude;
      if (p.longitude < w) w = p.longitude;
      if (p.longitude > e) e = p.longitude;
    }
    // Deux points très proches : on évite un zoom extrême.
    const m = 0.002;
    return gm.LatLngBounds(
        southwest: gm.LatLng(s - m, w - m), northeast: gm.LatLng(n + m, e + m));
  }

  /// Icône de repère dessinée en image (Google Maps).
  Future<void> _loadIcons(double dpr) async {
    final missing = widget.markers
        .map((m) => (m, _iconKey(m)))
        .where((e) => !_icons.containsKey(e.$2))
        .toList();
    if (missing.isEmpty) return;
    for (final (m, key) in missing) {
      _icons[key] = await _drawIcon(m, dpr);
    }
    if (mounted) setState(() {});
  }

  static String _iconKey(KitungaMapMarker m) =>
      '${m.icon.codePoint}_${m.color.toARGB32()}_${m.round}';

  static Future<gm.BitmapDescriptor> _drawIcon(
      KitungaMapMarker m, double dpr) async {
    final size = m.round ? 46.0 : 44.0;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.scale(dpr);
    final c = Offset(size / 2, size / 2);
    double glyph;
    Color glyphColor;
    if (m.round) {
      canvas.drawCircle(c + const Offset(0, 1.5), size / 2 - 2,
          Paint()..color = const Color(0x33000000));
      canvas.drawCircle(c, size / 2 - 2, Paint()..color = Colors.white);
      canvas.drawCircle(c, size / 2 - 5, Paint()..color = m.color);
      glyph = 24;
      glyphColor = Colors.white;
    } else {
      canvas.drawCircle(c, size / 2 - 6, Paint()..color = Colors.white);
      glyph = 40;
      glyphColor = m.color;
    }
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
          text: String.fromCharCode(m.icon.codePoint),
          style: TextStyle(
              fontSize: glyph,
              fontFamily: m.icon.fontFamily,
              package: m.icon.fontPackage,
              color: glyphColor))
      ..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    final img = await rec
        .endRecording()
        .toImage((size * dpr).round(), (size * dpr).round());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    return gm.BitmapDescriptor.bytes(png!.buffer.asUint8List(),
        width: size, height: size);
  }

  Widget _googleMap(BuildContext context) {
    _loadIcons(MediaQuery.devicePixelRatioOf(context));
    final pts = widget.fitPoints;
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(
          target: _g(_center),
          zoom: pts.isNotEmpty ? 14.5 : widget.initialZoom),
      onMapCreated: (c) {
        _gm = c;
        if (widget.fitPoints.length >= 2) {
          // Cadrage initial une fois la carte dessinée.
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && !_userMoved) _fit();
          });
        }
      },
      onCameraMoveStarted: () {
        if (!_programmatic && !_userMoved) {
          setState(() => _userMoved = true);
        }
      },
      onCameraIdle: () => _programmatic = false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      markers: {
        for (final m in widget.markers)
          gm.Marker(
            markerId: gm.MarkerId(m.id),
            position: _g(m.point),
            anchor: m.round ? const Offset(.5, .5) : const Offset(.5, .9),
            icon: _icons[_iconKey(m)] ?? gm.BitmapDescriptor.defaultMarker,
            zIndexInt: m.round ? 2 : 1,
            consumeTapEvents: m.onTap != null,
            onTap: m.onTap,
          ),
      },
      polylines: {
        for (var i = 0; i < widget.lines.length; i++)
          if (widget.lines[i].points.length >= 2)
            gm.Polyline(
              polylineId: gm.PolylineId('l$i'),
              points: [for (final p in widget.lines[i].points) _g(p)],
              color: widget.lines[i].color,
              width: widget.lines[i].width.round(),
              patterns: widget.lines[i].dashed
                  ? [gm.PatternItem.dash(16), gm.PatternItem.gap(12)]
                  : const [],
            ),
      },
    );
  }

  Widget _osmMap() {
    final pts = widget.fitPoints;
    return fm.FlutterMap(
      mapController: _fm,
      options: fm.MapOptions(
        initialCenter: _center,
        initialZoom: pts.isNotEmpty ? 14.5 : widget.initialZoom,
        initialCameraFit: pts.length >= 2
            ? fm.CameraFit.coordinates(
                coordinates: pts,
                padding: const EdgeInsets.all(48),
                maxZoom: 16)
            : null,
        interactionOptions: const fm.InteractionOptions(
            flags: fm.InteractiveFlag.all & ~fm.InteractiveFlag.rotate),
        onMapReady: () => _fmReady = true,
        onPositionChanged: (_, hasGesture) {
          if (hasGesture && !_userMoved) setState(() => _userMoved = true);
        },
      ),
      children: [
        if (kitungaMapShowTiles)
          fm.TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'site.kitunga.app',
            maxZoom: 19,
          ),
        for (final l in widget.lines)
          if (l.points.length >= 2)
            fm.PolylineLayer(polylines: [
              fm.Polyline(
                  points: l.points,
                  strokeWidth: l.dashed ? 3 : l.width,
                  color: l.color,
                  pattern: l.dashed
                      ? fm.StrokePattern.dashed(segments: const [8, 6])
                      : const fm.StrokePattern.solid()),
            ]),
        fm.MarkerLayer(markers: [
          for (final m in widget.markers)
            fm.Marker(
              point: m.point,
              width: m.round ? 46 : 44,
              height: m.round ? 46 : 44,
              child: GestureDetector(
                onTap: m.onTap,
                child: m.round
                    ? Container(
                        decoration: BoxDecoration(
                          color: m.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Color(0x33000000), blurRadius: 6)
                          ],
                        ),
                        child: Icon(m.icon, color: Colors.white, size: 24),
                      )
                    : Icon(m.icon, color: m.color, size: 40),
              ),
            ),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget map = switch (_google) {
      null => const ColoredBox(color: Color(0xFFEDEFF2)),
      true => _googleMap(context),
      false => _osmMap(),
    };
    return Stack(children: [
      Positioned.fill(child: map),
      if (widget.follow && _userMoved && widget.fitPoints.isNotEmpty)
        Positioned(
          right: 10,
          bottom: widget.recenterBottom,
          child: Material(
            color: Colors.white,
            elevation: 3,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _recenter,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.my_location_rounded,
                      size: 16, color: Color(0xFFE51A1A)),
                  const SizedBox(width: 6),
                  Text('Recentrer',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A1A))),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}
