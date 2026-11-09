import 'package:flutter/material.dart';

import '/backend/order_status.dart';
import '/noc/sales/sales_common.dart'
    show fcfa, salesCall, askText, runSalesAction, listOf;
import '/noc/ui/admin_kit.dart';
import '/noc/ui/admin_export.dart' show downloadReceiptPdf;
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

  bool _busy = false;

  /// Preuve de remise, problème signalé et reçu.
  Widget _proof(DashOrder o) {
    final delivered = [
      OrderStatus.delivered,
      OrderStatus.received,
      OrderStatus.notReceived,
    ].contains(o.status);
    if (o.issue.isEmpty && !delivered) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (o.issue.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: AdminColors.redSoft,
                borderRadius: BorderRadius.circular(AdminRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.report_rounded, color: AdminColors.red),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text('Problème signalé par le livreur : ${o.issue}',
                        style: AdminText.strong(
                            size: 13.0, color: AdminColors.red)),
                  ),
                ],
              ),
            ),
          if (delivered) ...[
            if (o.issue.isNotEmpty) const SizedBox(height: 10.0),
            Wrap(
              spacing: 10.0,
              runSpacing: 10.0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                o.codeVerified
                    ? const AdminBadge('Remise confirmée par code',
                        tone: kToneGreen)
                    : const AdminBadge('Remise sans code (ancienne version)',
                        tone: kToneOrange),
                if (o.photo.startsWith('http'))
                  InkWell(
                    borderRadius: BorderRadius.circular(AdminRadius.sm),
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(o.photo,
                        webHtmlElementStrategy: WebHtmlElementStrategy.fallback, fit: BoxFit.contain),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AdminRadius.sm),
                      child: Image.network(o.photo,
                        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                          width: 56.0,
                          height: 56.0,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(
                              width: 56.0,
                              height: 56.0,
                              child: Icon(Icons.image_not_supported_outlined))),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final r = await salesCall(
                          'kitungaOrderReceipt', {'orderId': o.id});
                      await downloadReceiptPdf(r);
                      messenger.showSnackBar(SnackBar(
                          content: Text('Reçu ${r['number']} téléchargé')));
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
                  icon: const Icon(Icons.receipt_long_rounded, size: 18.0),
                  label: const Text('Reçu PDF'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _run(Map<String, dynamic> data, String done) async {
    setState(() => _busy = true);
    final ok = await runSalesAction(
        context, () => salesCall('kitungaAdminOrderAction', data), done);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _cancel(DashOrder o) async {
    final reason = await askText(context, 'Annuler cette commande ?',
        hint: 'Le client et le commerce verront la commande annulée. Si elle '
            'était payée, elle passe dans Gestion › Remboursements.');
    if (reason == null || !mounted) return;
    await _run({'orderId': o.id, 'action': 'cancel', 'reason': reason},
        'Commande annulée');
  }

  Future<void> _assign(DashOrder o) async {
    final uid = await showDialog<String>(
      context: context,
      builder: (_) => AdminThemeScope(
          child: _DelivererPicker(current: o.delivererPath?.split('/').last)),
    );
    if (uid == null || !mounted) return;
    await _run({'orderId': o.id, 'action': 'assign', 'delivererUid': uid},
        'Livreur attribué');
  }

  Future<void> _deliver(DashOrder o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Marquer la commande livrée ?'),
        content: const Text(
            'À utiliser si le livreur a remis la commande sans la valider '
            'dans l\'application.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Marquer livrée')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run({'orderId': o.id, 'action': 'deliver'}, 'Commande livrée');
  }

  /// Actions possibles selon le statut (mêmes règles que le serveur).
  Widget _actions(DashOrder o) {
    final inProgress = OrderStatus.inProgress.contains(o.status);
    final canAssign = o.status == OrderStatus.ready ||
        o.status == OrderStatus.delivering;
    final canDeliver = o.status == OrderStatus.delivering;
    if (!inProgress) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 20.0),
        child: Text('Commande terminée : aucune action possible.',
            style: AdminText.label(size: 12.5)),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(24.0, 14.0, 24.0, 20.0),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AdminColors.border)),
      ),
      child: _busy
          ? const AdminLoading(height: 48.0)
          : Wrap(
              alignment: WrapAlignment.end,
              spacing: 10.0,
              runSpacing: 10.0,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AdminColors.red,
                      side: BorderSide(
                          color: AdminColors.red.withValues(alpha: 0.4))),
                  onPressed: () => _cancel(o),
                  icon: const Icon(Icons.cancel_outlined, size: 18.0),
                  label: const Text('Annuler la commande'),
                ),
                if (canAssign)
                  OutlinedButton.icon(
                    onPressed: () => _assign(o),
                    icon: const Icon(Icons.two_wheeler_rounded, size: 18.0),
                    label: Text(o.delivererPath == null
                        ? 'Attribuer un livreur'
                        : 'Changer de livreur'),
                  ),
                if (canDeliver)
                  FilledButton.icon(
                    onPressed: () => _deliver(o),
                    icon: const Icon(Icons.task_alt_rounded, size: 18.0),
                    label: const Text('Marquer livrée'),
                  ),
              ],
            ),
    );
  }

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
                    _proof(o),
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
            _actions(o),
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
                        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
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

/// Choix d'un livreur actif (fonction kitungaCatalogQuery).
class _DelivererPicker extends StatefulWidget {
  const _DelivererPicker({this.current});

  final String? current;

  @override
  State<_DelivererPicker> createState() => _DelivererPickerState();
}

class _DelivererPickerState extends State<_DelivererPicker> {
  late final Future<List<Map<String, dynamic>>> _list = salesCall(
          'kitungaCatalogQuery', {'view': 'partners', 'role': 'Deliver'})
      .then((r) => listOf(r['partners'])
          .where((d) => d['accountStatus'] != 'suspended')
          .toList());
  String? _picked;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choisir le livreur'),
      content: SizedBox(
        width: 420.0,
        height: 360.0,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _list,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const AdminLoading();
            }
            final list = snap.data ?? const [];
            if (snap.hasError || list.isEmpty) {
              return AdminEmpty(
                  icon: Icons.two_wheeler_rounded,
                  title: snap.hasError
                      ? 'Livreurs indisponibles'
                      : 'Aucun livreur actif');
            }
            return ListView(
              children: [
                for (final d in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Material(
                      color: _picked == d['uid']
                          ? AdminColors.redSoft
                          : AdminColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12.0),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0)),
                        onTap: d['uid'] == widget.current
                            ? null
                            : () => setState(() => _picked = d['uid'] as String),
                        leading: AdminAvatar(
                            name: (d['displayName'] as String?)?.isNotEmpty == true
                                ? d['displayName'] as String
                                : '${d['email'] ?? '?'}',
                            photo: d['photoUrl'] as String?,
                            size: 38.0),
                        title: Text(
                            (d['displayName'] as String?)?.isNotEmpty == true
                                ? d['displayName'] as String
                                : '${d['email'] ?? ''}',
                            style: AdminText.strong(size: 13.5)),
                        subtitle: Text(
                            d['uid'] == widget.current
                                ? 'Livreur actuel'
                                : '${d['phone'] ?? ''}',
                            style: AdminText.label(size: 12.0)),
                        trailing: _picked == d['uid']
                            ? const Icon(Icons.check_circle_rounded,
                                color: AdminColors.red)
                            : null,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: _picked == null ? null : () => Navigator.pop(context, _picked),
          child: const Text('Attribuer'),
        ),
      ],
    );
  }
}
