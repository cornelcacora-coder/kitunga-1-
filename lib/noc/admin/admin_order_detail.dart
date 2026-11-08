import 'package:flutter/material.dart';

import '/noc/sales/sales_common.dart' show fcfa;
import '/noc/ui/admin_kit.dart';
import 'admin_dashboard_data.dart';

/// Fiche d'une commande : client, commerce, livreur, adresse, articles.
Future<void> showAdminOrderDetail(BuildContext context, DashOrder order,
    {Map<String, ({String name, String photo, String phone})> known =
        const {}}) {
  return showDialog(
    context: context,
    builder: (_) => AdminThemeScope(
      child: _OrderDetail(order: order, known: known),
    ),
  );
}

String _dateTime(DateTime? d) {
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  const months = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', //
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}, ${two(d.hour)}:${two(d.minute)}';
}

class _OrderDetail extends StatefulWidget {
  const _OrderDetail({required this.order, required this.known});

  final DashOrder order;
  final Map<String, ({String name, String photo, String phone})> known;

  @override
  State<_OrderDetail> createState() => _OrderDetailState();
}

class _OrderDetailState extends State<_OrderDetail> {
  late final _src = AdminDashboardSource.instance;
  late final Future<List<Map<String, dynamic>>> _items =
      _src.orderItems(widget.order.reference);
  late final Future<Map<String, ({String name, String photo, String phone})>>
      _people = _src.names([
    widget.order.userPath,
    widget.order.sellerPath,
    widget.order.delivererPath,
  ].whereType<String>());

  Widget _person(String role, IconData icon, String? path,
      Map<String, ({String name, String photo, String phone})> people) {
    final p = path == null ? null : (people[path] ?? widget.known[path]);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          p == null
              ? AdminIconBadge(icon,
                  color: AdminColors.faint,
                  background: AdminColors.greySoft,
                  size: 40.0)
              : AdminAvatar(name: p.name, photo: p.photo, size: 40.0),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role, style: AdminText.label(size: 12.0)),
                Text(
                    p?.name ??
                        (path == null ? 'Pas encore attribué' : 'Introuvable'),
                    style: AdminText.strong()),
              ],
            ),
          ),
          if ((p?.phone ?? '').isNotEmpty)
            Text(p!.phone, style: AdminText.label()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final wide = MediaQuery.sizeOf(context).width > 640;
    return Dialog(
      insetPadding: const EdgeInsets.all(16.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 20.0, 12.0, 4.0),
              child: Row(
                children: [
                  const AdminIconBadge(Icons.receipt_long_rounded,
                      round: false, size: 44.0),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            o.reference.isEmpty
                                ? 'Commande'
                                : 'Commande ${o.reference}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AdminText.h2()),
                        Text(_dateTime(o.createdAt),
                            style: AdminText.label(size: 12.5)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 10.0,
                      runSpacing: 10.0,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AdminBadge(orderStatusShort(o.status),
                            tone: orderStatusTone(o.status)),
                        Text(fcfa(o.total),
                            style: AdminText.h1(color: AdminColors.ink)),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    Container(
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        color: AdminColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AdminRadius.md),
                      ),
                      child: FutureBuilder(
                        future: _people,
                        builder: (context, snap) {
                          final people = snap.data ?? widget.known;
                          final rows = [
                            _person('Client', Icons.person_rounded, o.userPath,
                                people),
                            _person('Commerce', Icons.storefront_rounded,
                                o.sellerPath, people),
                            _person('Livreur', Icons.two_wheeler_rounded,
                                o.delivererPath, people),
                          ];
                          return Column(children: rows);
                        },
                      ),
                    ),
                    const SizedBox(height: 14.0),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.place_rounded,
                            size: 18.0, color: AdminColors.red),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                              [o.zone, o.location]
                                      .where((s) => s.trim().isNotEmpty)
                                      .join(' · ')
                                      .isEmpty
                                  ? 'Adresse non précisée'
                                  : [o.zone, o.location]
                                      .where((s) => s.trim().isNotEmpty)
                                      .join(' · '),
                              style: AdminText.body()),
                        ),
                      ],
                    ),
                    if (o.deliveredAt != null) ...[
                      const SizedBox(height: 8.0),
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              size: 18.0, color: AdminColors.green),
                          const SizedBox(width: 8.0),
                          Text('Livrée le ${_dateTime(o.deliveredAt)}',
                              style: AdminText.body()),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20.0),
                    Text('ARTICLES', style: AdminText.caps()),
                    const SizedBox(height: 8.0),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _items,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const AdminLoading(height: 80.0);
                        }
                        final items = snap.data ?? const [];
                        if (snap.hasError || items.isEmpty) {
                          return Text(
                              snap.hasError
                                  ? 'Articles indisponibles.'
                                  : 'Aucun article enregistré.',
                              style: AdminText.label());
                        }
                        return Column(
                          children: [
                            for (final it in items)
                              _ItemRow(item: it, wide: wide),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.wide});

  final Map<String, dynamic> item;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    final price = (item['price_at_purchase'] as num?)?.toDouble() ?? 0.0;
    final img = (item['image'] as String?) ?? '';
    final options = (item['options'] as String?) ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AdminRadius.sm),
            child: img.startsWith('http')
                ? Image.network(img,
                    width: 46.0,
                    height: 46.0,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder())
                : _placeholder(),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((item['item_name'] as String?) ?? 'Article',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminText.strong()),
                Text(
                    '$qty × ${fcfa(price)}'
                    '${options.isNotEmpty ? ' · $options' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AdminText.label(size: 12.5)),
              ],
            ),
          ),
          Text(fcfa(price * qty), style: AdminText.strong()),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 46.0,
        height: 46.0,
        color: AdminColors.greySoft,
        child: Icon(Icons.image_outlined,
            size: 20.0, color: AdminColors.faint),
      );
}
