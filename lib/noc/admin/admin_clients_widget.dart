import 'dart:async';

import 'package:flutter/material.dart';

import '/noc/sales/sales_common.dart';
import 'admin_shell.dart';
import '/noc/ui/admin_export.dart';
import '/noc/ui/admin_table.dart';

/// Clients (adresse /clients) : voir la fiche, modifier (nom, téléphone),
/// offrir ou prolonger l'abonnement, supprimer (= désactiver le compte, qui
/// peut être réactivé). Les clients créent eux-mêmes leur compte dans
/// l'application : il n'y a pas d'ajout ici (mot de passe personnel).
class AdminClientsWidget extends StatefulWidget {
  const AdminClientsWidget({super.key});

  static String routeName = 'AdminClients';
  static String routePath = AdminPaths.clients;

  @override
  State<AdminClientsWidget> createState() => _AdminClientsWidgetState();
}

/// Abonnement en cours : date de fin dans le futur.
bool isSubscribed(Map<String, dynamic> c, [DateTime? now]) {
  final end = DateTime.tryParse(c['subscribeCloseAt'] ?? '');
  return end != null && end.isAfter(now ?? DateTime.now());
}

/// État d'abonnement : active, expiring (7 jours ou moins), expired, never.
String subscriptionStateOf(Map<String, dynamic> c, [DateTime? now]) {
  if (c['subscription'] is String) return c['subscription'] as String;
  final end = DateTime.tryParse(c['subscribeCloseAt'] ?? '');
  final t = now ?? DateTime.now();
  if (end == null) return 'never';
  if (!end.isAfter(t)) return 'expired';
  return end.difference(t) <= const Duration(days: 7) ? 'expiring' : 'active';
}

const kSubscriptionGroups = {
  'active': 'Abonnés',
  'expiring': 'Expire sous 7 jours',
  'expired': 'Expirés',
  'never': 'Jamais abonnés',
};

/// Messages proposés par groupe (modifiables avant l'envoi).
const kReminderMessages = {
  'active': ('Merci d\'être abonné à Kitunga',
      'Profitez de vos commandes livrées partout à Brazzaville.'),
  'expiring': ('Votre abonnement se termine bientôt',
      'Renouvelez-le dans Profil › Mon abonnement pour continuer à commander.'),
  'expired': ('Votre abonnement est terminé',
      'Vous ne pouvez plus commander. Renouvelez votre abonnement (300 F pour '
          '6 mois ou 1000 F pour un an) dans Profil › Mon abonnement.'),
  'never': ('Abonnez-vous à Kitunga',
      'Pour commander : 300 F pour 6 mois ou 1000 F pour un an, dans '
          'Profil › Mon abonnement.'),
};

class _AdminClientsWidgetState extends State<AdminClientsWidget> {
  String _q = '';
  Timer? _debounce;
  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() => salesCall('kitungaCatalogQuery',
      {'view': 'clients', if (_q.isNotEmpty) 'q': _q});

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  String _name(Map<String, dynamic> c) =>
      (c['displayName'] as String?)?.isNotEmpty == true
          ? c['displayName']
          : (c['email'] as String?)?.isNotEmpty == true
              ? c['email']
              : (c['phone'] as String?)?.isNotEmpty == true
                  ? c['phone']
                  : 'Client sans nom';

  void _view(Map<String, dynamic> c) {
    final suspended = c['accountStatus'] == 'suspended';
    showAdminDetail(
      context,
      title: _name(c),
      subtitle: 'Client Kitunga',
      avatar: AdminAvatar(name: _name(c), photo: c['photoUrl'], size: 68.0),
      badges: [
        suspended
            ? const AdminBadge('Suspendu', tone: kToneOrange)
            : const AdminBadge('Actif', tone: kToneGreen),
        isSubscribed(c)
            ? const AdminBadge('Abonné', tone: kToneBlue)
            : const AdminBadge('Non abonné', tone: kToneGrey),
      ],
      facts: [
        fact('Email', c['email'] ?? '', Icons.alternate_email_rounded),
        fact('Téléphone', c['phone'] ?? '', Icons.phone_rounded),
        fact(
            'Abonnement',
            isSubscribed(c)
                ? 'Jusqu\'au ${dateFr(c['subscribeCloseAt'])}'
                : c['subscribeCloseAt'] == null
                    ? 'Aucun'
                    : 'Expiré le ${dateFr(c['subscribeCloseAt'])}',
            Icons.workspace_premium_rounded),
        fact('Inscrit le', dateFr(c['createdAt']), Icons.event_rounded),
      ],
      actions: [
        (
          label: 'Offrir un abonnement',
          icon: Icons.card_giftcard_rounded,
          onTap: () => _grant(c),
          primary: false
        ),
        (label: 'Modifier', icon: Icons.edit_rounded, onTap: () => _edit(c), primary: true),
      ],
    );
  }

  Future<void> _edit(Map<String, dynamic> c) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ClientForm(client: c),
    );
    if (saved == true) _reload();
  }

  Future<void> _grant(Map<String, dynamic> c) async {
    final r = await showDialog<({int days, String reason})>(
      context: context,
      builder: (_) => _GrantDialog(name: _name(c)),
    );
    if (r == null || !mounted) return;
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaGrantSubscription',
            {'userUid': c['uid'], 'days': r.days, 'reason': r.reason}),
        'Abonnement prolongé de ${r.days} jours');
    if (ok) _reload();
  }

  Future<void> _setStatus(Map<String, dynamic> c, String status) async {
    String? reason;
    if (status == 'suspended') {
      reason = await askText(context, 'Supprimer « ${_name(c)} » ?',
          hint: 'Le compte est désactivé : connexion bloquée. Ses commandes '
              'sont conservées et le compte peut être réactivé.');
      if (reason == null) return;
    } else {
      final ok = await adminConfirm(context,
          title: 'Réactiver « ${_name(c)} » ?',
          message: 'Le client pourra de nouveau se connecter.',
          confirm: 'Réactiver');
      if (!ok) return;
    }
    if (!mounted) return;
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaSetAccountStatus', {
              'userUid': c['uid'],
              'status': status,
              if (reason != null) 'reason': reason,
            }),
        status == 'suspended' ? 'Compte désactivé' : 'Compte réactivé');
    if (ok) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700.0;
    return AdminShell(
      current: 'clients',
      title: 'Clients',
      subtitle: 'Comptes clients de l\'application',
      actions: [
        AdminExportButton(data: _export),
        OutlinedButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded, size: 18.0),
            label: const Text('Actualiser')),
      ],
      body: AdminScroll(
        children: [
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10.0,
                  runSpacing: 10.0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AdminSearchBox(
                      width:
                          wide ? 320.0 : MediaQuery.sizeOf(context).width - 72.0,
                      hint: 'Nom, email ou téléphone',
                      onChanged: (v) {
                        _debounce?.cancel();
                        _debounce =
                            Timer(const Duration(milliseconds: 400), () {
                          _q = v.trim();
                          _reload();
                        });
                      },
                    ),
                    AdminSelect<String>(
                      value: _subFilter,
                      icon: Icons.workspace_premium_outlined,
                      items: const {
                        'all': 'Abonnés ou non',
                        ...kSubscriptionGroups,
                      },
                      onChanged: (v) => setState(() => _subFilter = v),
                    ),
                    AdminSelect<String>(
                      value: _statusFilter,
                      icon: Icons.toggle_on_outlined,
                      items: const {
                        'all': 'Tous les statuts',
                        'active': 'Actifs',
                        'suspended': 'Suspendus',
                      },
                      onChanged: (v) => setState(() => _statusFilter = v),
                    ),
                    AdminSelect<int>(
                      value: _joinedDays,
                      icon: Icons.event_outlined,
                      items: const {
                        0: 'Inscrits à toute date',
                        7: 'Inscrits ces 7 jours',
                        30: 'Inscrits ces 30 jours',
                        90: 'Inscrits ces 90 jours',
                      },
                      onChanged: (v) => setState(() => _joinedDays = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                FutureBuilder<Map<String, dynamic>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const AdminLoading(height: 240.0);
                    }
                    if (snap.hasError) {
                      return AdminEmpty(
                        icon: Icons.cloud_off_rounded,
                        title: 'Chargement impossible',
                        message: '${snap.error}',
                        action: TextButton(
                            onPressed: _reload,
                            child: const Text('Réessayer')),
                      );
                    }
                    final now = DateTime.now();
                    final list = [
                      for (final c in listOf(snap.data!['clients']))
                        if ((_subFilter == 'all' ||
                                subscriptionStateOf(c, now) == _subFilter) &&
                            (_statusFilter == 'all' ||
                                (c['accountStatus'] ?? 'active') ==
                                    _statusFilter) &&
                            (_joinedDays == 0 ||
                                (DateTime.tryParse('${c['createdAt']}')
                                        ?.isAfter(now.subtract(
                                            Duration(days: _joinedDays))) ??
                                    false)))
                          c,
                    ];
                    _shown = list;
                    final total =
                        (snap.data!['total'] as num? ?? list.length).toInt();
                    final counts = snap.data!['counts'] is Map
                        ? Map<String, dynamic>.from(snap.data!['counts'] as Map)
                        : <String, dynamic>{};
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Groupes d'abonnement (cliquables) et rappel.
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (final g in kSubscriptionGroups.entries)
                              ChoiceChip(
                                label: Text('${g.value} · ${counts[g.key] ?? '—'}'),
                                selected: _subFilter == g.key,
                                onSelected: (on) => setState(
                                    () => _subFilter = on ? g.key : 'all'),
                              ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  backgroundColor: kSalesRed),
                              onPressed: list.isEmpty
                                  ? null
                                  : () => _remind(list),
                              icon: const Icon(
                                  Icons.notifications_active_outlined,
                                  size: 18.0),
                              label: Text('Envoyer un rappel '
                                  '(${list.length})'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14.0),
                        if (list.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Text(
                                '$total client${total > 1 ? 's' : ''}'
                                '${total > list.length ? ' (${list.length} plus récents affichés)' : ''}',
                                style: AdminText.label()),
                          ),
                        _table(list),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>>? _shown;
  String _subFilter = 'all';
  String _statusFilter = 'all';
  int _joinedDays = 0;

  AdminExportData? _export() {
    final list = _shown;
    if (list == null) return null;
    return AdminExportData(
      title: 'Clients',
      subtitle: [
        if (_q.isNotEmpty) 'recherche « $_q »',
        '${list.length} client${list.length > 1 ? 's' : ''}',
      ].join(' · '),
      fileName: 'clients',
      headers: ['Client', 'Email', 'Téléphone', 'Inscrit le', 'Abonnement',
        'Fin d\'abonnement', 'Statut'],
      flex: [4, 4, 2, 2, 2, 2, 2],
      rows: [
        for (final c in list)
          [
            _name(c),
            c['email'] ?? '',
            c['phone'] ?? '',
            dateFr(c['createdAt']),
            isSubscribed(c) ? 'Abonné' : 'Non abonné',
            c['subscribeCloseAt'] == null ? '' : dateFr(c['subscribeCloseAt']),
            c['accountStatus'] == 'suspended' ? 'Suspendu' : 'Actif',
          ],
      ],
    );
  }

  Widget _identity(Map<String, dynamic> c) => Row(
        children: [
          AdminAvatar(name: _name(c), photo: c['photoUrl'], size: 38.0),
          const SizedBox(width: 12.0),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_name(c),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminText.strong(size: 13.5)),
                if ((c['email'] ?? '').isNotEmpty)
                  Text(c['email'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminText.label(size: 12.0)),
              ],
            ),
          ),
        ],
      );

  Widget _subscription(Map<String, dynamic> c) =>
      switch (subscriptionStateOf(c)) {
        'active' => const AdminBadge('Abonné', tone: kToneBlue),
        'expiring' => const AdminBadge('Expire bientôt', tone: kToneOrange),
        'expired' => const AdminBadge('Expiré', tone: kToneRed),
        _ => const AdminBadge('Jamais abonné', tone: kToneGrey),
      };

  /// Rappel (centre de notifications + push) aux clients choisis.
  Future<void> _remind(List<Map<String, dynamic>> clients) async {
    final group = _subFilter != 'all'
        ? _subFilter
        : clients.length == 1
            ? subscriptionStateOf(clients.first)
            : 'expiring';
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => _ReminderDialog(clients: clients, group: group),
    );
    if (sent == true) _reload();
  }

  Widget _status(Map<String, dynamic> c) => c['accountStatus'] == 'suspended'
      ? const AdminBadge('Suspendu', tone: kToneOrange)
      : const AdminBadge('Actif', tone: kToneGreen);

  Widget _table(List<Map<String, dynamic>> list) {
    return AdminTable<Map<String, dynamic>>(
      rows: list,
      initialSort: 2,
      empty: const AdminEmpty(
          icon: Icons.people_outline_rounded,
          title: 'Aucun client',
          message: 'Aucun compte ne correspond à cette recherche.'),
      onTap: _view,
      actionsWidth: 200.0,
      actions: (c) {
        final suspended = c['accountStatus'] == 'suspended';
        return [
          AdminActionDot(
              icon: Icons.visibility_rounded,
              tooltip: 'Voir',
              onTap: () => _view(c)),
          AdminActionDot(
              icon: Icons.edit_rounded,
              tooltip: 'Modifier',
              tone: kToneOrange,
              onTap: () => _edit(c)),
          AdminActionDot(
              icon: Icons.notifications_active_outlined,
              tooltip: 'Envoyer un rappel',
              tone: kToneBlue,
              onTap: () => _remind([c])),
          AdminActionDot(
              icon: Icons.card_giftcard_rounded,
              tooltip: 'Offrir un abonnement',
              tone: kToneViolet,
              onTap: () => _grant(c)),
          suspended
              ? AdminActionDot(
                  icon: Icons.restore_rounded,
                  tooltip: 'Réactiver',
                  tone: kToneGreen,
                  onTap: () => _setStatus(c, 'active'))
              : AdminActionDot(
                  icon: Icons.delete_rounded,
                  tooltip: 'Supprimer',
                  tone: kToneRed,
                  onTap: () => _setStatus(c, 'suspended')),
        ];
      },
      columns: [
        AdminColumn(
            label: 'Client',
            flex: 5,
            cell: _identity,
            sortKey: (c) => _name(c).toLowerCase()),
        AdminColumn(
            label: 'Téléphone',
            flex: 2,
            cell: (c) => Text((c['phone'] ?? '').isEmpty ? '—' : c['phone'],
                style: AdminText.body(size: 13.0))),
        AdminColumn(
            label: 'Inscrit le',
            flex: 2,
            cell: (c) =>
                Text(dateFr(c['createdAt']), style: AdminText.body(size: 13.0)),
            sortKey: (c) => c['createdAt'] as String?),
        AdminColumn(
            label: 'Abonnement',
            flex: 2,
            cell: _subscription,
            sortKey: (c) => c['subscribeCloseAt'] as String?),
        AdminColumn(
            label: 'Statut',
            flex: 2,
            cell: _status,
            sortKey: (c) => c['accountStatus'] as String?),
      ],
      compact: (c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _identity(c),
          const SizedBox(height: 8.0),
          Wrap(spacing: 8.0, runSpacing: 6.0, children: [
            _status(c),
            _subscription(c),
          ]),
        ],
      ),
    );
  }
}

class _ClientForm extends StatefulWidget {
  const _ClientForm({required this.client});

  final Map<String, dynamic> client;

  @override
  State<_ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends State<_ClientForm> {
  late final _name =
      TextEditingController(text: widget.client['displayName'] ?? '');
  late final _phone = TextEditingController(text: widget.client['phone'] ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      return setState(() => _error = 'Indiquez le nom.');
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaSavePartner', {
              'uid': widget.client['uid'],
              'displayName': _name.text.trim(),
              'phone': _phone.text.trim(),
            }),
        'Fiche enregistrée');
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormDialog(
      icon: Icons.person_rounded,
      title: 'Modifier le client',
      saving: _saving,
      onSave: _save,
      children: [
        TextField(
          controller: _name,
          maxLength: 80,
          decoration: salesInput('Nom'),
        ),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: salesInput('Téléphone', hint: '06 123 45 67'),
        ),
        Text('L\'email de connexion n\'est pas modifiable ici.',
            style: salesBody(size: 12.0)),
        if (_error != null) Text(_error!, style: salesBody(color: kSalesRed)),
      ],
    );
  }
}

class _GrantDialog extends StatefulWidget {
  const _GrantDialog({required this.name});

  final String name;

  @override
  State<_GrantDialog> createState() => _GrantDialogState();
}

class _GrantDialogState extends State<_GrantDialog> {
  int _days = 30;
  final _reason = TextEditingController();
  bool _missing = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Abonnement offert à ${widget.name}'),
      content: SizedBox(
        width: 380.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8.0,
              children: [
                for (final d in const [30, 90, 365])
                  ChoiceChip(
                    label: Text(d == 365 ? '1 an' : '$d jours'),
                    selected: _days == d,
                    selectedColor: kSalesRed.withValues(alpha: 0.15),
                    onSelected: (_) => setState(() => _days = d),
                  ),
              ],
            ),
            const SizedBox(height: 14.0),
            TextField(
              controller: _reason,
              maxLength: 300,
              decoration: salesInput('Motif',
                      hint: 'Ex. geste commercial, paiement reçu à la main')
                  .copyWith(errorText: _missing ? 'Champ obligatoire' : null),
            ),
            Text('S\'ajoute à l\'abonnement en cours. Sans paiement ni commission.',
                style: salesBody(size: 12.0)),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kSalesRed),
          onPressed: () {
            final r = _reason.text.trim();
            if (r.isEmpty) return setState(() => _missing = true);
            Navigator.pop(context, (days: _days, reason: r));
          },
          child: const Text('Offrir'),
        ),
      ],
    );
  }
}


/// Envoi d'un rappel : message proposé selon le groupe, modifiable.
class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog({required this.clients, required this.group});

  final List<Map<String, dynamic>> clients;
  final String group;

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  late final _title = TextEditingController(
      text: (kReminderMessages[widget.group] ?? kReminderMessages['expiring']!)
          .$1);
  late final _body = TextEditingController(
      text: (kReminderMessages[widget.group] ?? kReminderMessages['expiring']!)
          .$2);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      return setState(() => _error = 'Écrivez le titre et le message.');
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaAdminSendReminder', {
              'uids': [for (final c in widget.clients) c['uid']],
              'title': _title.text.trim(),
              'body': _body.text.trim(),
            }),
        'Rappel envoyé à ${widget.clients.length} client'
            '${widget.clients.length > 1 ? 's' : ''}');
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.clients.length;
    return AdminFormDialog(
      icon: Icons.notifications_active_outlined,
      title: 'Envoyer un rappel',
      saveLabel: 'Envoyer',
      saving: _saving,
      onSave: _send,
      children: [
        Text(
            n == 1
                ? 'Au client ${widget.clients.first['displayName'] ?? ''} : '
                    'dans ses notifications Kitunga et sur son téléphone.'
                : 'Aux $n clients affichés : dans leurs notifications Kitunga '
                    'et sur leur téléphone.',
            style: salesBody()),
        TextField(
          controller: _title,
          maxLength: 80,
          decoration: salesInput('Titre'),
        ),
        TextField(
          controller: _body,
          maxLength: 400,
          maxLines: 3,
          decoration: salesInput('Message'),
        ),
        if (_error != null) Text(_error!, style: salesBody(color: kSalesRed)),
      ],
    );
  }
}
