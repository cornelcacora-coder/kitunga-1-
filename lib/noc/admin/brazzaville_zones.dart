import 'package:latlong2/latlong.dart';

/// Position approximative (centre du quartier) des zones de livraison de
/// Kitunga, pour la carte de l'administration. Les noms sont ceux proposés
/// au client dans l'application (voir pricing.js / cart_last_widget.dart).
///
/// Les commandes n'enregistrent pas de coordonnées GPS : la carte place
/// donc chaque commande au centre de son quartier. Pour corriger une
/// position, modifier la valeur ci-dessous (latitude, longitude).
const kBrazzavilleCenter = LatLng(-4.2550, 15.2650);

const Map<String, LatLng> kBrazzavilleZones = {
  // Zone à 1 000 F (sud et centre)
  'Makélékélé': LatLng(-4.2905, 15.2345),
  'Centre sportif': LatLng(-4.2840, 15.2420),
  'Kinsoundi': LatLng(-4.3045, 15.2255),
  'Diata': LatLng(-4.2720, 15.2195),
  'Kingouari': LatLng(-4.2950, 15.2455),
  'Moukoundzi-Ngouaka': LatLng(-4.2880, 15.2205),
  "Château d'eau": LatLng(-4.2745, 15.2340),
  'Barrage': LatLng(-4.2975, 15.2215),
  'Bacongo': LatLng(-4.2805, 15.2560),
  'Mpissa': LatLng(-4.2660, 15.2495),
  'Poto-Poto': LatLng(-4.2560, 15.2720),
  'Centre-ville': LatLng(-4.2685, 15.2830),
  'Moungali': LatLng(-4.2485, 15.2620),
  'O.C.H': LatLng(-4.2425, 15.2560),
  'Plateau des 15 ans': LatLng(-4.2565, 15.2560),
  'Batignolles': LatLng(-4.2425, 15.2705),
  'Moukondo': LatLng(-4.2385, 15.2500),
  'Avenue de la Paix': LatLng(-4.2505, 15.2650),
  'Marché Moungali': LatLng(-4.2470, 15.2600),
  'Académie': LatLng(-4.2600, 15.2780),
  // Zone à 1 500 F (nord)
  'Ouenzé': LatLng(-4.2300, 15.2650),
  'Mapassi': LatLng(-4.2285, 15.2550),
  'Mpila': LatLng(-4.2400, 15.2950),
  'La Tsiémé': LatLng(-4.2250, 15.2795),
  'Talangaï': LatLng(-4.2080, 15.2800),
  'Mikalou': LatLng(-4.2050, 15.2650),
  'Ngamakosso': LatLng(-4.1950, 15.2900),
  'Ma-Mboualé': LatLng(-4.2150, 15.2705),
  'Kanga Mbandz': LatLng(-4.2005, 15.2750),
  'Mfilou': LatLng(-4.2550, 15.2050),
  'Sadelmi': LatLng(-4.2350, 15.2400),
  'La Base': LatLng(-4.2450, 15.2450),
  'Mazala': LatLng(-4.2200, 15.2600),
  'Cité des 17': LatLng(-4.2300, 15.2350),
  'Soprogie': LatLng(-4.2380, 15.2895),
  // Zone à 2 000 F (périphérie)
  'Madibou': LatLng(-4.3100, 15.2050),
  'Mansimou': LatLng(-4.3150, 15.2200),
  'Mafouta': LatLng(-4.2850, 15.1950),
  'Massissia': LatLng(-4.3300, 15.2000),
  'Djiri': LatLng(-4.1700, 15.2700),
  'Ndjiri': LatLng(-4.1700, 15.2700),
  'Massengo': LatLng(-4.1600, 15.2650),
  'Kombo': LatLng(-4.3060, 15.2150),
  'Kintélé': LatLng(-4.1250, 15.3200),
  'Makabandilou': LatLng(-4.1500, 15.2750),
  // Zone à 2 500 F (éloignée)
  'Mayanga': LatLng(-4.3400, 15.1900),
  'Moussosso': LatLng(-4.3350, 15.2100),
  'Mbouono': LatLng(-4.3000, 15.1850),
  'Kombé': LatLng(-4.3500, 15.2000),
  'Kibina': LatLng(-4.3250, 15.1950),
  'Nganga-Lingolo': LatLng(-4.3700, 15.1700),
};

/// Nom comparable : minuscules, sans accents ni ponctuation.
String zoneKey(String v) => v
    .toLowerCase()
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c')
    .replaceAll(RegExp('[^a-z0-9]'), '');

final Map<String, ({String name, LatLng point})> _byKey = {
  for (final e in kBrazzavilleZones.entries)
    zoneKey(e.key): (name: e.key, point: e.value),
};

/// Position d'une zone saisie (null si inconnue).
({String name, LatLng point})? zonePosition(String zone) =>
    _byKey[zoneKey(zone)];
