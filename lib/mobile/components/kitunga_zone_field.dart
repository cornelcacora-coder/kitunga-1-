import 'package:flutter/material.dart';

import '/noc/admin/brazzaville_zones.dart' show kBrazzavilleZones;

/// Quartier du commerce (point de collecte des livreurs). Il sert au calcul
/// des frais de livraison selon la distance jusqu'au client.
class KitungaShopZoneField extends StatelessWidget {
  const KitungaShopZoneField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final zones = kBrazzavilleZones.keys.toList()..sort();
    final current = zones.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      key: const ValueKey('shop-zone'),
      initialValue: current,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Quartier du commerce',
        helperText: 'Point de collecte du livreur ; sert au calcul des frais '
            'de livraison.',
        helperMaxLines: 2,
        prefixIcon: Icon(Icons.storefront_rounded),
      ),
      items: [
        for (final z in zones) DropdownMenuItem(value: z, child: Text(z)),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
