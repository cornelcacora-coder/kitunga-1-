import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '/flutter_flow/flutter_flow_theme.dart';

/// Position exacte (client à la commande, commerce une fois) : frais,
/// itinéraire, carte et heure d'arrivée calculés de porte à porte.
/// Le serveur ne garde que des positions situées à Brazzaville.

/// Remplace le GPS dans les tests.
@visibleForTesting
Future<({double lat, double lng, double accuracy})> Function()?
    exactPointOverride;

/// Dans l'agglomération de Brazzaville (même zone que le serveur).
bool inBrazzaville(double lat, double lng) =>
    lat >= -4.6 && lat <= -3.9 && lng >= 14.9 && lng <= 15.6;

/// Position actuelle du téléphone, ou un message d'erreur clair.
Future<({Map<String, double>? point, String? error, double? accuracy})>
    readExactPoint() async {
  try {
    if (exactPointOverride != null) {
      final p = await exactPointOverride!();
      return inBrazzaville(p.lat, p.lng)
          ? (
              point: {'lat': p.lat, 'lng': p.lng},
              error: null,
              accuracy: p.accuracy
            )
          : (
              point: null,
              error: 'Cette position est hors de Brazzaville.',
              accuracy: null
            );
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return (
        point: null,
        error: 'Activez la localisation du téléphone, puis réessayez.',
        accuracy: null
      );
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return (
        point: null,
        error: 'Autorisez la localisation pour utiliser votre position.',
        accuracy: null
      );
    }
    final p = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.high))
        .timeout(const Duration(seconds: 20));
    if (!inBrazzaville(p.latitude, p.longitude)) {
      return (
        point: null,
        error: 'Cette position est hors de Brazzaville.',
        accuracy: null
      );
    }
    return (
      point: {'lat': p.latitude, 'lng': p.longitude},
      error: null,
      accuracy: p.accuracy
    );
  } catch (_) {
    return (
      point: null,
      error: 'Position introuvable. Réessayez à l\'extérieur.',
      accuracy: null
    );
  }
}

/// Bouton « Utiliser ma position exacte » avec son état.
class KitungaExactPointButton extends StatefulWidget {
  const KitungaExactPointButton({
    super.key,
    required this.point,
    required this.onChanged,
    this.label = 'Utiliser ma position exacte',
    this.hint = 'Le livreur arrive à votre porte et les frais sont calculés '
        'au plus juste.',
  });

  final Map<String, double>? point;
  final ValueChanged<Map<String, double>?> onChanged;
  final String label;
  final String hint;

  @override
  State<KitungaExactPointButton> createState() =>
      _KitungaExactPointButtonState();
}

class _KitungaExactPointButtonState extends State<KitungaExactPointButton> {
  bool _busy = false;
  String? _error;
  double? _accuracy;

  Future<void> _locate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await readExactPoint();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = r.error;
      _accuracy = r.accuracy;
    });
    if (r.point != null) widget.onChanged(r.point);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    const green = Color(0xFF17A35B);
    final set = widget.point != null;
    return Container(
      key: const ValueKey('exact-point'),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: (set ? green : theme.primary).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: (set ? green : theme.primary).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(set ? Icons.my_location_rounded : Icons.location_searching,
              color: set ? green : theme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    set
                        ? 'Position exacte enregistrée'
                        : widget.label,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: theme.primaryText)),
                Text(
                    _error ??
                        (set
                            ? (_accuracy == null
                                ? 'Frais et itinéraire de porte à porte.'
                                : 'Précision ± ${_accuracy!.round()} m.')
                            : widget.hint),
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _error != null
                            ? theme.error
                            : theme.secondaryText)),
              ],
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (set)
            TextButton(
              key: const ValueKey('exact-point-clear'),
              onPressed: () => widget.onChanged(null),
              child: const Text('Retirer'),
            )
          else
            TextButton(
              key: const ValueKey('exact-point-locate'),
              onPressed: _locate,
              child: const Text('Localiser'),
            ),
        ],
      ),
    );
  }
}
