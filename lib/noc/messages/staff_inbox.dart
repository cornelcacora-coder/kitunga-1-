import 'package:flutter/material.dart';

import '/mobile/components/messaging/kitunga_messages.dart'
    show openConversation, openStaffDirectChat;
import '/noc/admin/admin_layout.dart';
import '/noc/sales/sales_common.dart';
import '/noc/ui/admin_kit.dart';

/// Messages directs de l'équipe Kitunga (admin et support) avec les
/// clients, commerces et livreurs : boîte partagée, non-lus, nouveau
/// message à n'importe quel utilisateur.

const _roleLabels = {
  'User': 'Client',
  'Seller': 'Commerce',
  'Deliver': 'Livreur',
};

/// Choisit un utilisateur (recherche) puis ouvre le message direct.
Future<void> writeToUser(BuildContext context) async {
  final q = await askText(context, 'Nouveau message',
      label: 'Nom, téléphone ou e-mail du destinataire');
  if (q == null || q.trim().length < 2 || !context.mounted) return;
  final uid = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Destinataire « ${q.trim()} »'),
      content: SizedBox(
        width: 460,
        child: FutureBuilder<Map<String, dynamic>>(
          future: salesCall('kitungaSupportUserLookup', {'query': q.trim()}),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text('Recherche impossible.', style: salesBody());
            }
            if (!snap.hasData) {
              return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()));
            }
            final users = listOf(snap.data!['users'])
                .where((u) => _roleLabels.containsKey(u['role']))
                .toList();
            if (users.isEmpty) {
              return Text('Aucun client, commerce ou livreur trouvé.',
                  style: salesBody());
            }
            return ListView(
              shrinkWrap: true,
              children: [
                for (final u in users)
                  ListTile(
                    leading: const Icon(Icons.person_rounded),
                    title: Text('${u['name']}', style: salesTitle(14)),
                    subtitle: Text(
                        '${_roleLabels[u['role']]} · ${u['phone']}',
                        style: salesBody(size: 12.5)),
                    onTap: () => Navigator.pop(c, '${u['uid']}'),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
      ],
    ),
  );
  if (uid != null && context.mounted) await openStaffDirectChat(context, uid);
}

/// Liste des conversations directes (sans en-tête : intégrée à une page).
class StaffInboxView extends StatefulWidget {
  const StaffInboxView({super.key});

  @override
  State<StaffInboxView> createState() => StaffInboxViewState();
}

class StaffInboxViewState extends State<StaffInboxView> {
  late Future<Map<String, dynamic>> _data = _load();

  Future<Map<String, dynamic>> _load() =>
      salesCall('kitungaStaffInbox', const {});

  void reload() {
    setState(() {
      _data = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
              child: Text('Lecture impossible. Réessayez.',
                  style: salesBody()));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = listOf(snap.data!['conversations']);
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                  'Aucun message direct. Écrivez à un client, un commerce ou '
                  'un livreur avec « Nouveau message » ou le bouton « Écrire ».',
                  textAlign: TextAlign.center,
                  style: salesBody()),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            for (final c in list)
              SalesCard(
                child: InkWell(
                  onTap: () async {
                    await openConversation(
                        context,
                        '${c['id']}',
                        '${c['targetName']} · '
                            '${_roleLabels[c['targetRole']] ?? ''}');
                    reload();
                  },
                  child: Row(
                    children: [
                      Icon(
                          c['targetRole'] == 'Deliver'
                              ? Icons.delivery_dining_rounded
                              : c['targetRole'] == 'Seller'
                                  ? Icons.storefront_rounded
                                  : Icons.person_rounded,
                          color: AdminColors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${c['targetName']} · '
                                '${_roleLabels[c['targetRole']] ?? ''}',
                                style: salesTitle(14)),
                            Text('${c['lastMessage']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: salesBody(size: 12.5)),
                          ],
                        ),
                      ),
                      Text(dateFr(c['lastAt'] as String?, withTime: true),
                          style: salesBody(size: 11.5)),
                      if ((c['unread'] as num? ?? 0) > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: AdminColors.red,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text('${c['unread']}',
                              style: salesBody(size: 12)
                                  .copyWith(color: Colors.white)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Page admin « Messages » (adresse /messages).
class AdminMessagesWidget extends StatefulWidget {
  const AdminMessagesWidget({super.key});

  static String routeName = 'AdminMessages';
  static String routePath = AdminPaths.messages;

  @override
  State<AdminMessagesWidget> createState() => _AdminMessagesWidgetState();
}

class _AdminMessagesWidgetState extends State<AdminMessagesWidget> {
  final _inbox = GlobalKey<StaffInboxViewState>();

  @override
  Widget build(BuildContext context) => AdminShell(
        current: 'messages',
        title: 'Messages',
        subtitle: 'Messages directs avec les clients, commerces et livreurs',
        actions: [
          FilledButton.icon(
            onPressed: () async {
              await writeToUser(context);
              _inbox.currentState?.reload();
            },
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Nouveau message'),
          ),
          OutlinedButton.icon(
              onPressed: () => _inbox.currentState?.reload(),
              icon: const Icon(Icons.refresh_rounded, size: 18.0),
              label: const Text('Actualiser')),
        ],
        body: StaffInboxView(key: _inbox),
      );
}

/// Même boîte pour l'espace du support (sans le menu de l'admin).
class SupportMessagesPage extends StatelessWidget {
  const SupportMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final inbox = GlobalKey<StaffInboxViewState>();
    return Scaffold(
      backgroundColor: AdminColors.page,
      appBar: AppBar(
        backgroundColor: AdminColors.surface,
        foregroundColor: AdminColors.ink,
        elevation: 0,
        title: Text('Messages directs', style: AdminText.h2()),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await writeToUser(context);
              inbox.currentState?.reload();
            },
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Nouveau message'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: StaffInboxView(key: inbox),
      ),
    );
  }
}

/// Bouton « Écrire » (message direct) à placer sur une fiche.
class StaffWriteButton extends StatelessWidget {
  const StaffWriteButton({super.key, required this.uid, this.dense = false});

  final String uid;
  final bool dense;

  @override
  Widget build(BuildContext context) => dense
      ? IconButton(
          tooltip: 'Écrire',
          onPressed: () => openStaffDirectChat(context, uid),
          icon: const Icon(Icons.forum_rounded, color: AdminColors.red),
        )
      : TextButton.icon(
          onPressed: () => openStaffDirectChat(context, uid),
          icon: const Icon(Icons.forum_rounded, size: 18),
          label: const Text('Écrire'),
        );
}
