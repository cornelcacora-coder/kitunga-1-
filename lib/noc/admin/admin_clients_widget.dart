import 'dart:async';

import 'package:flutter/material.dart';

import '/noc/sales/sales_common.dart';
import 'admin_shell.dart';

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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            ClipOval(
              child: AdminImage(c['photoUrl'] ?? '',
                  width: 48.0, height: 48.0, icon: Icons.person_outline),
            ),
            const SizedBox(width: 12.0),
            Expanded(child: Text(_name(c), style: salesTitle(18.0))),
          ],
        ),
        content: SizedBox(
          width: 400.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(accountStatusStyle[c['accountStatus']]),
              ),
              AdminInfoRow('Email', c['email'] ?? ''),
              AdminInfoRow('Téléphone', c['phone'] ?? ''),
              AdminInfoRow(
                  'Abonnement',
                  isSubscribed(c)
                      ? 'Actif jusqu\'au ${dateFr(c['subscribeCloseAt'])}'
                      : c['subscribeCloseAt'] == null
                          ? 'Aucun'
                          : 'Expiré le ${dateFr(c['subscribeCloseAt'])}'),
              AdminInfoRow('Inscrit le', dateFr(c['createdAt'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _edit(c);
            },
            child: const Text('Modifier'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kSalesRed),
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
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
    return AdminShell(
      current: 'clients',
      title: 'Clients',
      subtitle: 'Comptes clients de l\'application',
      actions: [
        IconButton(
            tooltip: 'Actualiser',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded)),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 12.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AdminSearchField(
                hint: 'Nom, email ou téléphone',
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 400), () {
                    _q = v.trim();
                    _reload();
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                      child: CircularProgressIndicator(color: kSalesRed));
                }
                if (snap.hasError) {
                  return SalesEmpty(
                    icon: Icons.cloud_off_rounded,
                    title: 'Chargement impossible',
                    text: '${snap.error}',
                    action: TextButton(
                        onPressed: _reload, child: const Text('Réessayer')),
                  );
                }
                final list = listOf(snap.data!['clients']);
                final total = (snap.data!['total'] as num? ?? list.length).toInt();
                if (list.isEmpty) {
                  return const SalesEmpty(
                      icon: Icons.people_outline_rounded,
                      title: 'Aucun client',
                      text: 'Aucun compte ne correspond à cette recherche.');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 40.0),
                  itemCount: list.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 8.0),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Text(
                          '$total client${total > 1 ? 's' : ''}'
                          '${total > list.length ? ' (${list.length} plus récents affichés)' : ''}',
                          style: salesBody());
                    }
                    final c = list[i - 1];
                    final suspended = c['accountStatus'] == 'suspended';
                    return SalesCard(
                      onTap: () => _view(c),
                      child: Row(
                        children: [
                          ClipOval(
                            child: AdminImage(c['photoUrl'] ?? '',
                                width: 46.0,
                                height: 46.0,
                                icon: Icons.person_outline),
                          ),
                          const SizedBox(width: 14.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_name(c),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: salesTitle(15.0)),
                                const SizedBox(height: 2.0),
                                Text(
                                    [
                                      if ((c['phone'] ?? '').isNotEmpty)
                                        c['phone'],
                                      if ((c['email'] ?? '').isNotEmpty)
                                        c['email'],
                                      'inscrit le ${dateFr(c['createdAt'])}',
                                    ].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: salesBody(size: 12.5)),
                                const SizedBox(height: 6.0),
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 4.0,
                                  children: [
                                    StatusChip(
                                        accountStatusStyle[c['accountStatus']]),
                                    StatusChip(isSubscribed(c)
                                        ? (
                                            label: 'Abonné',
                                            color: const Color(0xFF2F6FDB)
                                          )
                                        : (label: 'Non abonné', color: kSalesMuted)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          AdminRowActions(actions: [
                            viewAction(() => _view(c)),
                            editAction(() => _edit(c)),
                            (
                              label: 'Offrir un abonnement',
                              icon: Icons.card_giftcard_rounded,
                              onTap: () => _grant(c),
                              danger: false,
                            ),
                            if (suspended)
                              (
                                label: 'Réactiver',
                                icon: Icons.restore_rounded,
                                onTap: () => _setStatus(c, 'active'),
                                danger: false,
                              )
                            else
                              deleteAction(() => _setStatus(c, 'suspended')),
                          ]),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
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
