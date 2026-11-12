import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/noc/admin/admin_order_trace.dart';
import '/noc/sales/sales_common.dart'
    show salesCall, listOf, dateFr, runSalesAction, askText;
import '/noc/ui/admin_kit.dart';

/// Espace de travail du support client (adresse /support), pour les agents
/// « Support » et les administrateurs : tickets, réponses, notes internes,
/// attribution, priorité, statut, escalade, recherche d'un utilisateur.
/// Le support ne rembourse pas et ne suspend pas de compte : il escalade.
class SupportWorkspaceWidget extends StatefulWidget {
  const SupportWorkspaceWidget({super.key});

  static String routeName = 'SupportWorkspace';
  static String routePath = '/support';

  @override
  State<SupportWorkspaceWidget> createState() => _SupportWorkspaceState();
}

const kSupportStatus = {
  'open': ('Ouvert', AdminColors.orange),
  'in_progress': ('En cours', AdminColors.blue),
  'waiting_user': ('Attente utilisateur', AdminColors.teal),
  'escalated': ('Escaladé', AdminColors.violet),
  'resolved': ('Résolu', AdminColors.grey),
};

const kSupportPriority = {
  'normal': ('Normale', AdminColors.grey),
  'high': ('Haute', AdminColors.orange),
  'urgent': ('Urgente', AdminColors.red),
};

const _filters = [
  ('active', 'À traiter'),
  ('urgent', 'Urgents'),
  ('mine', 'Mes tickets'),
  ('open', 'Ouverts'),
  ('in_progress', 'En cours'),
  ('waiting_user', 'Attente utilisateur'),
  ('escalated', 'Escaladés'),
  ('resolved', 'Résolus'),
];

const _roleLabels = {
  'User': 'Client',
  'Seller': 'Commerce',
  'Deliver': 'Livreur',
  'Admin': 'Admin',
  'Support': 'Support',
};

class _SupportWorkspaceState extends State<SupportWorkspaceWidget> {
  String _filter = 'active';
  final _search = TextEditingController();
  Future<Map<String, dynamic>>? _queue;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
        _queue = salesCall('kitungaSupportQueue',
            {'filter': _filter, 'search': _search.text.trim()});
      });

  Future<void> _lookup() async {
    final q = await askText(context, 'Rechercher un utilisateur',
        label: 'Nom, téléphone ou e-mail');
    if (q == null || q.trim().length < 2 || !mounted) return;
    showDialog(
        context: context, builder: (_) => _UserLookupDialog(query: q.trim()));
  }

  Future<void> _team() async {
    final email = await askText(context, 'Ajouter un agent du support',
        label: 'E-mail du compte (client) à transformer en compte Support');
    if (email == null || email.trim().isEmpty || !mounted) return;
    await runSalesAction(
        context,
        () => salesCall('kitungaAdminSetSupport', {'email': email.trim()}),
        'Compte Support activé : il se connecte sur /admin et arrive ici.');
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final isAdmin = currentUserDocument?.role == 'Admin';
    return Scaffold(
      backgroundColor: AdminColors.page,
      appBar: AppBar(
        backgroundColor: AdminColors.surface,
        foregroundColor: AdminColors.ink,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.support_agent_rounded, color: AdminColors.red),
            const SizedBox(width: 10),
            Text('Support Kitunga', style: AdminText.h2()),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _lookup,
            icon: const Icon(Icons.person_search_rounded),
            label: const Text('Utilisateur'),
          ),
          if (isAdmin)
            TextButton.icon(
              onPressed: _team,
              icon: const Icon(Icons.group_add_rounded),
              label: const Text('Équipe'),
            ),
          IconButton(
              tooltip: 'Actualiser',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _queue,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
                child: Text('Accès impossible ou connexion perdue.',
                    style: AdminText.body()));
          }
          final data = snap.data;
          final counts =
              Map<String, dynamic>.from((data?['counts'] as Map?) ?? {});
          final tickets = listOf(data?['tickets']);
          final list = _TicketList(
            tickets: tickets,
            loading: data == null,
            selected: _selected,
            onOpen: (id) {
              if (wide) {
                setState(() => _selected = id);
              } else {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => Scaffold(
                          backgroundColor: AdminColors.page,
                          appBar: AppBar(
                              backgroundColor: AdminColors.surface,
                              foregroundColor: AdminColors.ink),
                          body: _TicketDetail(
                              ticketId: id, onChanged: _reload),
                        )));
              }
            },
          );
          final header = Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _Kpi('À traiter',
                        '${(counts['open'] ?? 0) + (counts['in_progress'] ?? 0)}',
                        AdminColors.orange),
                    _Kpi('Urgents', '${counts['urgent'] ?? 0}',
                        AdminColors.red),
                    _Kpi('Escaladés', '${counts['escalated'] ?? 0}',
                        AdminColors.violet),
                    _Kpi('Mes tickets', '${counts['mine'] ?? 0}',
                        AdminColors.blue),
                    _Kpi('Résolus', '${counts['resolved'] ?? 0}',
                        AdminColors.green),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  onSubmitted: (_) => _reload(),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'N° de ticket, commande, nom, mot du message…',
                    filled: true,
                    fillColor: AdminColors.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AdminColors.border)),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (key, label) in _filters)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _filter == key,
                            onSelected: (_) {
                              _filter = key;
                              _reload();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
          if (!wide) {
            return Column(children: [header, Expanded(child: list)]);
          }
          return Row(
            children: [
              SizedBox(
                width: 460,
                child: Column(children: [header, Expanded(child: list)]),
              ),
              VerticalDivider(width: 1, color: AdminColors.border),
              Expanded(
                child: _selected == null
                    ? Center(
                        child: Text('Choisissez un ticket.',
                            style: AdminText.body(color: AdminColors.muted)))
                    : _TicketDetail(
                        key: ValueKey(_selected),
                        ticketId: _selected!,
                        onChanged: _reload),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 128,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AdminColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: GoogleFonts.interTight(
                    fontSize: 24, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: AdminText.label(size: 12)),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      );
}

class _TicketList extends StatelessWidget {
  const _TicketList({
    required this.tickets,
    required this.loading,
    required this.selected,
    required this.onOpen,
  });

  final List<Map<String, dynamic>> tickets;
  final bool loading;
  final String? selected;
  final void Function(String id) onOpen;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: AdminColors.red));
    }
    if (tickets.isEmpty) {
      return Center(
          child: Text('Aucun ticket dans ce filtre.',
              style: AdminText.body(color: AdminColors.muted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: tickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final t = tickets[i];
        final st = kSupportStatus[t['status']] ??
            ('${t['status']}', AdminColors.grey);
        final pr = kSupportPriority[t['priority']] ??
            ('${t['priority']}', AdminColors.grey);
        return Material(
          color: selected == t['id']
              ? AdminColors.red.withValues(alpha: 0.06)
              : AdminColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
                color: t['unread'] == true
                    ? AdminColors.red.withValues(alpha: 0.5)
                    : AdminColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onOpen('${t['id']}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('${t['number']}', style: AdminText.strong()),
                            _Pill(pr.$1, pr.$2),
                            _Pill(st.$1, st.$2),
                          ],
                        ),
                      ),
                      Text(dateFr(t['updatedAt'] as String?, withTime: true),
                          style: AdminText.label(size: 11.5)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${t['subject']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminText.strong(size: 14)),
                  Text(
                      [
                        '${_roleLabels[t['authorRole']] ?? ''} '
                            '${t['authorName'] ?? ''}',
                        if ('${t['orderRef'] ?? ''}'.isNotEmpty)
                          'Cmd ${t['orderRef']}',
                        if ('${t['assignedName'] ?? ''}'.isNotEmpty)
                          '→ ${t['assignedName']}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminText.label(size: 12.5)),
                  Text('${t['lastMessage'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminText.body(size: 13)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TicketDetail extends StatefulWidget {
  const _TicketDetail(
      {super.key, required this.ticketId, required this.onChanged});

  final String ticketId;
  final VoidCallback onChanged;

  @override
  State<_TicketDetail> createState() => _TicketDetailState();
}

class _TicketDetailState extends State<_TicketDetail> {
  late Future<Map<String, dynamic>> _thread = _load();
  final _reply = TextEditingController();
  bool _internal = false;
  bool _busy = false;

  Future<Map<String, dynamic>> _load() =>
      salesCall('kitungaTicketThread', {'ticketId': widget.ticketId});

  void _refresh() {
    setState(() {
      _thread = _load();
    });
    widget.onChanged();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _update(Map<String, dynamic> data, String done) async {
    final ok = await runSalesAction(
        context,
        () => salesCall(
            'kitungaTicketUpdate', {'ticketId': widget.ticketId, ...data}),
        done);
    if (ok) _refresh();
  }

  Future<void> _send() async {
    if (_reply.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaTicketReply', {
              'ticketId': widget.ticketId,
              'text': _reply.text.trim(),
              'internal': _internal,
            }),
        _internal ? 'Note interne ajoutée.' : 'Réponse envoyée.');
    if (ok) {
      _reply.clear();
      _refresh();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _thread,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
              child: Text('Ticket introuvable.', style: AdminText.body()));
        }
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AdminColors.red));
        }
        final t = Map<String, dynamic>.from(snap.data!['ticket'] as Map);
        final messages = listOf(snap.data!['messages']);
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Text('${t['number']} · ${t['subject']}',
                      style: AdminText.h2()),
                  const SizedBox(height: 4),
                  Text(
                      [
                        '${t['categoryLabel'] ?? ''}',
                        '${_roleLabels[t['authorRole']] ?? ''} '
                            '${t['authorName'] ?? ''}',
                        if ('${t['orderRef'] ?? ''}'.isNotEmpty)
                          'Commande ${t['orderRef']}',
                        'créé ${dateFr(t['createdAt'] as String?, withTime: true)}',
                      ].join(' · '),
                      style: AdminText.label()),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<String>(
                        value: '${t['status']}',
                        items: [
                          for (final e in kSupportStatus.entries)
                            DropdownMenuItem(
                                value: e.key, child: Text(e.value.$1)),
                        ],
                        onChanged: (v) => v == null || v == t['status']
                            ? null
                            : _update({'status': v}, 'Statut modifié.'),
                      ),
                      DropdownButton<String>(
                        value: '${t['priority']}',
                        items: [
                          for (final e in kSupportPriority.entries)
                            DropdownMenuItem(
                                value: e.key,
                                child: Text('Priorité ${e.value.$1}')),
                        ],
                        onChanged: (v) => v == null || v == t['priority']
                            ? null
                            : _update({'priority': v}, 'Priorité modifiée.'),
                      ),
                      if (t['assignedTo'] != currentUserUid)
                        OutlinedButton.icon(
                          onPressed: () =>
                              _update({'assign': 'me'}, 'Ticket pris en charge.'),
                          icon: const Icon(Icons.pan_tool_alt_rounded,
                              size: 18),
                          label: Text('${t['assignedName'] ?? ''}'.isEmpty
                              ? 'Prendre en charge'
                              : 'Reprendre (${t['assignedName']})'),
                        ),
                      if (t['status'] != 'escalated')
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AdminColors.violet),
                          onPressed: () async {
                            final note = await askText(context,
                                'Escalader à l\'admin',
                                label: 'Ce que l\'admin doit décider '
                                    '(remboursement, suspension…)');
                            if (note == null) return;
                            await _update({'escalate': true, 'note': note},
                                'Ticket escaladé : les admins sont prévenus.');
                          },
                          icon: const Icon(Icons.north_east_rounded, size: 18),
                          label: const Text('Escalader'),
                        ),
                      if (t['status'] != 'resolved')
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: AdminColors.green),
                          onPressed: () => _update(
                              {'status': 'resolved'}, 'Ticket résolu.'),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Résoudre'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final m in messages) _Message(m: m),
                  if (t['orderId'] != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AdminColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AdminColors.border),
                      ),
                      child: AdminOrderTrace(orderId: '${t['orderId']}'),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              color: AdminColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Switch(
                        value: _internal,
                        onChanged: (v) => setState(() => _internal = v),
                      ),
                      Text(
                          _internal
                              ? 'Note interne (invisible pour l\'utilisateur)'
                              : 'Réponse à l\'utilisateur',
                          style: AdminText.label()),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _reply,
                          minLines: 1,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: _internal
                                ? 'Note pour l\'équipe…'
                                : 'Votre réponse…',
                            isDense: true,
                            filled: true,
                            fillColor: _internal
                                ? const Color(0x14E38B00)
                                : AdminColors.surfaceAlt,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _busy ? null : _send,
                        child: const Text('Envoyer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.m});

  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final internal = m['internal'] == true;
    final staff = ['support', 'admin'].contains(m['fromRole']);
    final system = m['fromRole'] == 'system';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: internal
            ? const Color(0x14E38B00)
            : staff
                ? AdminColors.red.withValues(alpha: 0.05)
                : AdminColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: internal
                ? AdminColors.orange.withValues(alpha: 0.4)
                : AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                  internal
                      ? 'Note interne · ${m['fromName'] ?? ''}'
                      : system
                          ? 'Kitunga (automatique)'
                          : staff
                              ? 'Support · ${m['fromName'] ?? ''}'
                              : '${m['fromName'] ?? 'Utilisateur'}',
                  style: AdminText.strong(size: 13)),
              const Spacer(),
              Text(dateFr(m['at'] as String?, withTime: true),
                  style: AdminText.label(size: 11.5)),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText('${m['text'] ?? ''}', style: AdminText.body()),
          for (final p in (m['photos'] as List? ?? const []))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network('$p',
                    height: 180,
                    fit: BoxFit.cover,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined)),
              ),
            ),
        ],
      ),
    );
  }
}

class _UserLookupDialog extends StatelessWidget {
  const _UserLookupDialog({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Utilisateurs « $query »'),
      content: SizedBox(
        width: 520,
        child: FutureBuilder<Map<String, dynamic>>(
          future: salesCall('kitungaSupportUserLookup', {'query': query}),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text('Recherche impossible.', style: AdminText.body());
            }
            if (!snap.hasData) {
              return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()));
            }
            final users = listOf(snap.data!['users']);
            if (users.isEmpty) {
              return Text('Aucun utilisateur trouvé.',
                  style: AdminText.body());
            }
            return ListView(
              shrinkWrap: true,
              children: [
                for (final u in users)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${u['name']} · ${_roleLabels[u['role']] ?? u['role']}'
                            '${u['accountStatus'] == 'suspended' ? ' · SUSPENDU' : ''}',
                            style: AdminText.strong()),
                        Text('${u['phone']} · ${u['email']} · '
                            '${u['tickets']} ticket(s)',
                            style: AdminText.label()),
                        for (final o in listOf(u['orders']))
                          Text(
                              '  ${o['reference']} · ${o['status']} · '
                              '${o['total']} F · '
                              '${dateFr(o['createdAt'] as String?)}',
                              style: AdminText.body(size: 13)),
                      ],
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
            child: const Text('Fermer')),
      ],
    );
  }
}
