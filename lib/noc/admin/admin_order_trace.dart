import 'package:flutter/material.dart';

import '/noc/sales/sales_common.dart' show salesCall, listOf, dateFr;
import '/noc/ui/admin_kit.dart';
import '/mobile/components/messaging/kitunga_messages.dart'
    show openConversation;

/// Détail d'une commande (admin) : à quels livreurs la course a été
/// proposée, pourquoi, leur réponse ; puis l'historique des statuts
/// (qui, quand).
class AdminOrderTrace extends StatefulWidget {
  const AdminOrderTrace({super.key, required this.orderId});

  final String orderId;

  @override
  State<AdminOrderTrace> createState() => _AdminOrderTraceState();
}

const _missionLabels = {
  'offered': ('Proposée', Color(0xFFE08A00)),
  'accepted': ('Acceptée', Color(0xFF1E9E5A)),
  'declined': ('Refusée', Color(0xFFE51A1A)),
  'expired': ('Sans réponse', Color(0xFF8A94A6)),
  'cancelled': ('Annulée', Color(0xFF8A94A6)),
};

const _statusLabels = {
  'En attente': 'Reçue',
  'En préparation': 'En préparation',
  'Pret': 'Prête',
  'encours': 'En livraison',
  'Livrer': 'Livrée',
  'Reçu': 'Réception confirmée',
  'Non Reçu': 'Non reçue (litige)',
  'Refusée': 'Refusée',
  'Annulée': 'Annulée',
};

const _roleLabels = {
  'Seller': 'commerce',
  'Deliver': 'livreur',
  'User': 'client',
  'Admin': 'admin',
  'System': 'système',
};

class _AdminOrderTraceState extends State<AdminOrderTrace> {
  late final Future<
      (
        List<Map<String, dynamic>>,
        List<Map<String, dynamic>>,
        List<Map<String, dynamic>>
      )> _data = _load();

  Future<
      (
        List<Map<String, dynamic>>,
        List<Map<String, dynamic>>,
        List<Map<String, dynamic>>
      )> _load() async {
    final r = await Future.wait([
      salesCall('kitungaOrderMissions', {'orderId': widget.orderId})
          .catchError((_) => <String, dynamic>{}),
      salesCall('kitungaOrderHistory', {'orderId': widget.orderId})
          .catchError((_) => <String, dynamic>{}),
      salesCall('kitungaOrderConversations', {'orderId': widget.orderId})
          .catchError((_) => <String, dynamic>{}),
    ]);
    return (
      listOf(r[0]['missions']),
      listOf(r[1]['history'])
          .where((h) => h['field'] == 'status')
          .toList(),
      listOf(r[2]['conversations']),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        (
          List<Map<String, dynamic>>,
          List<Map<String, dynamic>>,
          List<Map<String, dynamic>>
        )>(
      future: _data,
      builder: (context, snap) {
        final missions = snap.data?.$1 ?? const [];
        final history = snap.data?.$2 ?? const [];
        final chats = snap.data?.$3 ?? const [];
        if (missions.isEmpty && history.isEmpty && chats.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (missions.isNotEmpty) ...[
              const SizedBox(height: 20.0),
              Text('ATTRIBUTION DU LIVREUR', style: AdminText.caps()),
              const SizedBox(height: 8.0),
              for (final m in missions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 3.0),
                        decoration: BoxDecoration(
                          color: (_missionLabels[m['status']]?.$2 ??
                                  AdminColors.muted)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: Text(
                            _missionLabels[m['status']]?.$1 ?? '${m['status']}',
                            style: AdminText.label(
                                color: _missionLabels[m['status']]?.$2,
                                size: 12.0)),
                      ),
                      const SizedBox(width: 10.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${m['attempt']}. ${m['deliverer'] ?? ''}',
                                style: AdminText.strong()),
                            Text('${m['reason'] ?? ''}',
                                style: AdminText.label(size: 12.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            // Conversations entre les acteurs (litige, vérification).
            if (chats.isNotEmpty) ...[
              const SizedBox(height: 14.0),
              Text('CONVERSATIONS', style: AdminText.caps()),
              const SizedBox(height: 4.0),
              for (final c in chats)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.forum_rounded,
                      color: AdminColors.red),
                  title: Text('${c['between']}', style: AdminText.strong()),
                  subtitle: Text('${c['lastMessage']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminText.label(size: 12.5)),
                  trailing: Text(
                      dateFr(c['lastAt'] as String?, withTime: true),
                      style: AdminText.label(size: 11.5)),
                  onTap: () => openConversation(
                      context, '${c['id']}', '${c['between']}'),
                ),
            ],
            if (history.isNotEmpty) ...[
              const SizedBox(height: 14.0),
              Text('HISTORIQUE', style: AdminText.caps()),
              const SizedBox(height: 8.0),
              for (final h in history)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    children: [
                      const Icon(Icons.circle,
                          size: 8.0, color: AdminColors.red),
                      const SizedBox(width: 10.0),
                      Expanded(
                        child: Text(
                            '${_statusLabels[h['to']] ?? h['to']} · par '
                            '${_roleLabels[h['byRole']] ?? h['byRole']}'
                            '${'${h['reason'] ?? ''}'.isEmpty ? '' : ' — ${h['reason']}'}',
                            style: AdminText.body(size: 13.5)),
                      ),
                      Text(dateFr(h['at'] as String?, withTime: true),
                          style: AdminText.label(size: 12.0)),
                    ],
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
