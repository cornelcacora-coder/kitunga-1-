import 'dart:math' as math;

import 'package:flutter/material.dart';

import '/backend/server_payment.dart' show ServerPaymentException;
import '/noc/sales/sales_common.dart';
import 'admin_layout.dart';
import 'brazzaville_zones.dart' show kBrazzavilleZones;

/// Tarif de livraison (adresse /tarif-livraison) : frais selon la distance
/// entre le quartier du commerce et celui du client. Le serveur fait le
/// calcul (delivery_pricing.js) ; cette page règle le tarif et le simule.
class AdminDeliveryPricingWidget extends StatefulWidget {
  const AdminDeliveryPricingWidget({super.key});

  static String routeName = 'AdminDeliveryPricing';
  static String routePath = AdminPaths.deliveryPricing;

  @override
  State<AdminDeliveryPricingWidget> createState() =>
      _AdminDeliveryPricingWidgetState();
}

/// Champs réglables : clé serveur, libellé, aide.
const _fields = [
  ('base', 'Prise en charge (F)', 'Montant fixe de chaque course.'),
  ('per_km', 'Prix par km (F)', 'Ajouté pour chaque kilomètre.'),
  ('road_factor', 'Coefficient route',
      'Distance réelle ≈ vol d\'oiseau × coefficient (détours des rues).'),
  ('minimum', 'Minimum (F)', 'Aucune course en dessous.'),
  ('maximum', 'Maximum (F)', 'Plafond ; 0 = sans plafond.'),
  ('rounding', 'Arrondi (F)', 'Arrondi au-dessus, par ex. 100 F.'),
];

/// Même calcul que le serveur (pour la simulation seulement).
({int fee, double km})? simulateDeliveryFee(
    Map<String, num> s, String shop, String client) {
  final p = kBrazzavilleZones[shop];
  final q = kBrazzavilleZones[client];
  if (p == null || q == null) return null;
  double rad(double d) => d * math.pi / 180;
  final h = math.pow(math.sin(rad(q.latitude - p.latitude) / 2), 2) +
      math.cos(rad(p.latitude)) *
          math.cos(rad(q.latitude)) *
          math.pow(math.sin(rad(q.longitude - p.longitude) / 2), 2);
  final km = 2 * 6371 * math.asin(math.sqrt(h)) * (s['road_factor'] ?? 1.3);
  final step = math.max(1, (s['rounding'] ?? 100).toInt());
  var fee = (((s['base'] ?? 0) + (s['per_km'] ?? 0) * km) / step).ceil() * step;
  fee = math.max((s['minimum'] ?? 0).toInt(), fee);
  final max = (s['maximum'] ?? 0).toInt();
  if (max > 0) fee = math.min(max, fee);
  return (fee: fee, km: (km * 10).round() / 10);
}

class _AdminDeliveryPricingWidgetState
    extends State<AdminDeliveryPricingWidget> {
  final _ctrl = {for (final f in _fields) f.$1: TextEditingController()};
  String _mode = 'distance';
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _shop = 'Poto-Poto';
  String _client = 'Talangaï';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Map<String, dynamic> s) {
    _mode = s['mode'] == 'zones' ? 'zones' : 'distance';
    for (final f in _fields) {
      final v = s[f.$1];
      _ctrl[f.$1]!.text = v is num
          ? (v == v.roundToDouble() ? '${v.toInt()}' : '$v')
          : '';
    }
  }

  Future<void> _load() async {
    try {
      final r = await salesCall('kitungaAdminDeliveryPricing', const {});
      if (!mounted) return;
      setState(() {
        _fill(Map<String, dynamic>.from(r['settings'] as Map));
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e is ServerPaymentException
              ? e.message
              : 'Lecture du tarif impossible. Réessayez.';
        });
      }
    }
  }

  Map<String, num> get _values => {
        for (final f in _fields)
          f.$1: num.tryParse(_ctrl[f.$1]!.text.replaceAll(',', '.')) ?? 0,
      };

  Future<void> _save() async {
    setState(() => _saving = true);
    await runSalesAction(
        context,
        () => salesCall('kitungaAdminDeliveryPricing', {
              'save': {'mode': _mode, ..._values},
            }),
        'Tarif enregistré : il s\'applique aux prochaines commandes.');
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final zones = kBrazzavilleZones.keys.toList()..sort();
    final sim = simulateDeliveryFee(_values, _shop, _client);
    return AdminShell(
      current: 'deliveryPricing',
      title: 'Tarif de livraison',
      subtitle: 'Frais selon la distance entre le commerce et le client',
      actions: [
        FilledButton.icon(
          onPressed: _loading || _saving ? null : _save,
          icon: const Icon(Icons.save_rounded, size: 18.0),
          label: const Text('Enregistrer'),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: salesBody()))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: [
                    SalesCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Mode de calcul', style: salesTitle()),
                          const SizedBox(height: 8),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                  value: 'distance',
                                  label: Text('Selon la distance')),
                              ButtonSegment(
                                  value: 'zones',
                                  label: Text('Ancien tarif par quartier')),
                            ],
                            selected: {_mode},
                            onSelectionChanged: (v) =>
                                setState(() => _mode = v.first),
                          ),
                          const SizedBox(height: 8),
                          Text(
                              'Les commerces sans quartier renseigné gardent '
                              'l\'ancien tarif (1000 à 2500 F selon le quartier '
                              'du client). Le prix payé par le client ne change '
                              'plus une fois la commande passée.',
                              style: salesBody()),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final f in _fields)
                                SizedBox(
                                  width: 220,
                                  child: TextField(
                                    key: ValueKey('pricing-${f.$1}'),
                                    controller: _ctrl[f.$1],
                                    enabled: _mode == 'distance',
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    onChanged: (_) => setState(() {}),
                                    decoration:
                                        salesInput(f.$2, helper: f.$3),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SalesCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Simulateur', style: salesTitle()),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: 240,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _shop,
                                  isExpanded: true,
                                  decoration: salesInput('Quartier du commerce'),
                                  items: [
                                    for (final z in zones)
                                      DropdownMenuItem(value: z, child: Text(z)),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _shop = v ?? _shop),
                                ),
                              ),
                              SizedBox(
                                width: 240,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _client,
                                  isExpanded: true,
                                  decoration: salesInput('Quartier du client'),
                                  items: [
                                    for (final z in zones)
                                      DropdownMenuItem(value: z, child: Text(z)),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _client = v ?? _client),
                                ),
                              ),
                              if (_mode == 'distance' && sim != null)
                                Text(
                                    '≈ ${sim.km.toStringAsFixed(1)} km  →  '
                                    '${sim.fee} F',
                                    key: const ValueKey('pricing-result'),
                                    style: salesTitle(18)),
                              if (_mode == 'zones')
                                Text('Ancien tarif : selon le quartier du '
                                    'client.', style: salesBody()),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
