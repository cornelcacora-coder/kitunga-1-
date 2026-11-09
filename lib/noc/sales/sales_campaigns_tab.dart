import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '/sales/referral_qr.dart';
import 'sales_admin_widget.dart';
import 'sales_common.dart';

/// Onglet Campagnes : barèmes, campagnes, statuts, affectations et QR codes.
class SalesCampaignsTab extends StatefulWidget {
  const SalesCampaignsTab({super.key});

  @override
  State<SalesCampaignsTab> createState() => _SalesCampaignsTabState();
}

class _SalesCampaignsTabState extends State<SalesCampaignsTab> {
  late Future<Map<String, dynamic>> _future = salesQuery('campaigns');

  void _reload() => setState(() {
        _future = salesQuery('campaigns');
      });

  Future<void> _newRule() async {
    final ok = await showDialog<bool>(
        context: context, builder: (_) => const _RuleForm());
    if (ok == true) _reload();
  }

  Future<void> _newCampaign(List<Map<String, dynamic>> rules) async {
    if (rules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Créez d\'abord un barème de commission.')));
      return;
    }
    final ok = await showDialog<bool>(
        context: context, builder: (_) => _CampaignForm(rules: rules));
    if (ok == true) _reload();
  }

  Future<void> _open(Map<String, dynamic> campaign,
      List<Map<String, dynamic>> rules) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _CampaignDetail(campaign: campaign, rules: rules),
    ));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return SalesPage(
      onRefresh: () async => _reload(),
      children: [
        SalesLoader(
          future: _future,
          onRetry: _reload,
          builder: (data) {
            final campaigns = listOf(data['campaigns']);
            final rules = listOf(data['rules']);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10.0,
                  runSpacing: 10.0,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _newRule,
                      icon: const Icon(Icons.rule_rounded),
                      label: const Text('Nouveau barème'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: kSalesRed),
                      onPressed: () => _newCampaign(rules),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nouvelle campagne'),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                if (campaigns.isEmpty)
                  const SalesEmpty(
                    icon: Icons.campaign_outlined,
                    title: 'Aucune campagne',
                    text: 'Créez un barème, puis une campagne, puis affectez-y vos commerciaux.',
                  ),
                for (final c in campaigns) ...[
                  SalesCard(
                    onTap: () => _open(c, rules),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8.0,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text('${c['name']}', style: salesTitle()),
                                  StatusChip(campaignStatus[c['status']]),
                                ],
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                  'Du ${dateFr(c['startsAt'] as String?)} au '
                                  '${dateFr(c['endsAt'] as String?)}',
                                  style: salesBody()),
                              Text(_ruleLabel(rules, c['ruleId'] as String?),
                                  style: salesBody()),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: kSalesMuted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10.0),
                ],
                if (rules.isNotEmpty) ...[
                  const SizedBox(height: 20.0),
                  Text('Barèmes (non modifiables)', style: salesTitle(15.0)),
                  const SizedBox(height: 8.0),
                  for (final r in rules)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Text('• ${_ruleLabel(rules, r['id'] as String?)}',
                          style: salesBody(color: kSalesInk)),
                    ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

String _ruleLabel(List<Map<String, dynamic>> rules, String? id) {
  final r = rules.where((x) => x['id'] == id).firstOrNull;
  if (r == null) return 'Barème inconnu';
  final eligible = (r['eligiblePlans'] as List? ?? [])
      .map((p) => planLabel[p] ?? '$p')
      .join(', ');
  return '${r['label']} : activation ${fcfa(r['activationAmount'])}, '
      'premier abonnement ${fcfa(r['firstSubscriptionAmount'])} ($eligible)';
}

// ── Barème ───────────────────────────────────────────────────────────────

class _RuleForm extends StatefulWidget {
  const _RuleForm();

  @override
  State<_RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends State<_RuleForm> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _activation = TextEditingController(text: '50');
  final _subscription = TextEditingController(text: '100');
  final Set<String> _plans = {...kOfferedPlans};
  bool _saving = false;

  @override
  void dispose() {
    _label.dispose();
    _activation.dispose();
    _subscription.dispose();
    super.dispose();
  }

  String? _amount(String? v) {
    final n = int.tryParse((v ?? '').trim());
    return n == null || n < 0 ? 'Montant entier en FCFA' : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_plans.isEmpty) return;
    setState(() => _saving = true);
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaCreateCommissionRule', {
              'label': _label.text.trim(),
              'activationAmount': int.parse(_activation.text.trim()),
              'firstSubscriptionAmount': int.parse(_subscription.text.trim()),
              'eligiblePlans': _plans.toList(),
            }),
        'Barème créé.');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau barème'),
      content: SizedBox(
        width: 440.0,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Un barème ne se modifie plus après sa création. Activation + '
                  'premier abonnement doit rester sous le prix de la formule '
                  'éligible la moins chère (protection contre les faux abonnements).',
                  style: salesBody(),
                ),
                const SizedBox(height: 14.0),
                TextFormField(
                    controller: _label,
                    decoration: salesInput('Nom du barème', hint: 'Lancement 2026'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Champ obligatoire' : null),
                const SizedBox(height: 12.0),
                TextFormField(
                    controller: _activation,
                    keyboardType: TextInputType.number,
                    decoration: salesInput('Activation vérifiée (FCFA)'),
                    validator: _amount),
                const SizedBox(height: 12.0),
                TextFormField(
                    controller: _subscription,
                    keyboardType: TextInputType.number,
                    decoration: salesInput('Premier abonnement payé (FCFA)'),
                    validator: _amount),
                const SizedBox(height: 12.0),
                Text('Formules qui ouvrent droit à la commission',
                    style: salesBody(color: kSalesInk)),
                for (final p in planLabel.entries)
                  if (kOfferedPlans.contains(p.key))
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: kSalesRed,
                    value: _plans.contains(p.key),
                    title: Text(p.value),
                    onChanged: (v) => setState(() =>
                        v == true ? _plans.add(p.key) : _plans.remove(p.key)),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kSalesRed),
          onPressed: _saving || _plans.isEmpty ? null : _save,
          child: Text(_saving ? 'Création…' : 'Créer'),
        ),
      ],
    );
  }
}

// ── Campagne (création et modification) ──────────────────────────────────

class _CampaignForm extends StatefulWidget {
  const _CampaignForm({required this.rules, this.campaign});

  final List<Map<String, dynamic>> rules;
  final Map<String, dynamic>? campaign;

  @override
  State<_CampaignForm> createState() => _CampaignFormState();
}

class _CampaignFormState extends State<_CampaignForm> {
  final _form = GlobalKey<FormState>();
  late final _c = widget.campaign;
  late final _name = TextEditingController(text: _c?['name'] as String?);
  late final _description =
      TextEditingController(text: _c?['description'] as String?);
  late final _objective = TextEditingController(text: _c?['objective'] as String?);
  late final _grace =
      TextEditingController(text: '${_c?['graceDays'] ?? 30}');
  late final _hold = TextEditingController(text: '${_c?['holdDays'] ?? 7}');
  late DateTime? _start = brazzavilleDay(_c?['startsAt'] as String?);
  // Date de fin affichée = dernier jour inclus.
  late DateTime? _end = brazzavilleDay(_c?['endsAt'] as String?)
      ?.subtract(_c == null ? Duration.zero : const Duration(days: 1));
  late String? _ruleId = (_c?['ruleId'] as String?) ??
      (widget.rules.isNotEmpty ? widget.rules.first['id'] as String : null);
  bool _saving = false;

  bool get _isNew => _c == null;
  bool get _running => ['active', 'paused'].contains(_c?['status']);

  @override
  void dispose() {
    for (final c in [_name, _description, _objective, _grace, _hold]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _start == null || _end == null) {
      return;
    }
    setState(() => _saving = true);
    final data = <String, dynamic>{
      if (!_isNew) 'campaignId': _c!['id'],
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'objective': _objective.text.trim(),
      'endsAt': brazzavilleDayEnd(_end!),
      if (!_running) ...{
        'startsAt': brazzavilleDayStart(_start!),
        'ruleId': _ruleId,
        'graceDays': int.tryParse(_grace.text.trim()) ?? 30,
        'holdDays': int.tryParse(_hold.text.trim()) ?? 7,
      },
    };
    final ok = await runSalesAction(
        context,
        () => salesCall(
            _isNew ? 'kitungaCreateCampaign' : 'kitungaUpdateCampaign', data),
        _isNew ? 'Campagne créée (brouillon).' : 'Campagne modifiée.');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime> set,
      {bool enabled = true}) {
    return InkWell(
      onTap: enabled
          ? () async {
              final d = await pickDay(context, value);
              if (d != null) setState(() => set(d));
            }
          : null,
      child: InputDecorator(
        decoration: salesInput(label),
        child: Text(
          value == null
              ? 'Choisir une date'
              : DateFormat('EEEE d MMMM yyyy', 'fr').format(value),
          style: salesBody(color: enabled ? kSalesInk : kSalesMuted, size: 14.0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? 'Nouvelle campagne' : 'Modifier la campagne'),
      content: SizedBox(
        width: 480.0,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_running)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                        'Campagne lancée : seuls les textes et la date de fin '
                        'peuvent encore changer.',
                        style: salesBody()),
                  ),
                TextFormField(
                    controller: _name,
                    decoration: salesInput('Nom de la campagne'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Champ obligatoire' : null),
                const SizedBox(height: 12.0),
                TextFormField(
                    controller: _objective,
                    decoration: salesInput('Objectif',
                        hint: '500 nouveaux abonnés à Poto-Poto')),
                const SizedBox(height: 12.0),
                TextFormField(
                    controller: _description,
                    maxLines: 3,
                    decoration: salesInput('Description')),
                const SizedBox(height: 12.0),
                _dateField('Premier jour', _start, (d) => _start = d,
                    enabled: !_running),
                const SizedBox(height: 12.0),
                _dateField('Dernier jour (inclus)', _end, (d) => _end = d),
                if (_start != null && _end != null && _end!.isBefore(_start!))
                  Text('Le dernier jour doit suivre le premier.',
                      style: salesBody(color: kSalesRed)),
                const SizedBox(height: 12.0),
                DropdownButtonFormField<String>(
                  initialValue: _ruleId,
                  isExpanded: true,
                  decoration: salesInput('Barème de commission'),
                  items: [
                    for (final r in widget.rules)
                      DropdownMenuItem(
                        value: r['id'] as String,
                        child: Text(_ruleLabel(widget.rules, r['id'] as String),
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: _running ? null : (v) => setState(() => _ruleId = v),
                ),
                const SizedBox(height: 12.0),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _grace,
                        enabled: !_running,
                        keyboardType: TextInputType.number,
                        decoration: salesInput('Délai après la fin (jours)',
                            helper: 'Abonnements encore payés après la fin.'),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: TextFormField(
                        controller: _hold,
                        enabled: !_running,
                        keyboardType: TextInputType.number,
                        decoration: salesInput('Délai de sécurité (jours)',
                            helper: 'Avant de pouvoir valider une commission.'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kSalesRed),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
        ),
      ],
    );
  }
}

// ── Détail d'une campagne ────────────────────────────────────────────────

class _CampaignDetail extends StatefulWidget {
  const _CampaignDetail({required this.campaign, required this.rules});

  final Map<String, dynamic> campaign;
  final List<Map<String, dynamic>> rules;

  @override
  State<_CampaignDetail> createState() => _CampaignDetailState();
}

class _CampaignDetailState extends State<_CampaignDetail> {
  late Map<String, dynamic> _campaign = widget.campaign;
  late Future<Map<String, dynamic>> _detail = _load();

  Future<Map<String, dynamic>> _load() async {
    final results = await Future.wait([
      salesQuery('campaign', {'campaignId': _campaign['id']}),
      salesQuery('agents'),
      salesQuery('campaigns'),
    ]);
    final fresh = listOf(results[2]['campaigns'])
        .where((c) => c['id'] == _campaign['id'])
        .firstOrNull;
    if (fresh != null) _campaign = fresh;
    return {
      'assignments': results[0]['assignments'],
      'agents': results[1]['agents'],
    };
  }

  void _reload() => setState(() {
        _detail = _load();
      });

  Future<void> _changeStatus(String to) async {
    String reason = '';
    if (to == 'paused' || to == 'completed') {
      final r = await askText(context, campaignActionLabel[to]!,
          hint: to == 'completed'
              ? 'Plus aucune acquisition ; liens et codes désactivés.'
              : 'Les liens ne rapportent plus pendant la pause.');
      if (r == null) return;
      reason = r;
    } else if (to == 'archived') {
      final r = await askText(context, 'Archiver la campagne',
          label: 'Note (facultative)', required: false);
      if (r == null) return;
      reason = r;
    }
    if (!mounted) return;
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaSetCampaignStatus',
            {'campaignId': _campaign['id'], 'status': to, 'reason': reason}),
        'Campagne : ${campaignStatus[to]!.label.toLowerCase()}.');
    if (ok) _reload();
  }

  Future<void> _edit() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) =>
            _CampaignForm(rules: widget.rules, campaign: _campaign));
    if (ok == true) _reload();
  }

  Future<void> _assign(List<Map<String, dynamic>> agents) async {
    final active = agents.where((a) => a['status'] == 'active').toList();
    if (active.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Aucun commercial actif à affecter.')));
      return;
    }
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => _AssignForm(campaign: _campaign, agents: active));
    if (ok == true) _reload();
  }

  Future<void> _endAssignment(Map<String, dynamic> a, String status) async {
    final reason = await askText(context,
        status == 'cancelled' ? 'Annuler l\'affectation' : 'Terminer l\'affectation',
        hint: 'Le code ${a['referralCode']} sera désactivé.');
    if (reason == null || !mounted) return;
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaEndAssignment',
            {'assignmentId': a['id'], 'status': status, 'reason': reason}),
        'Affectation mise à jour.');
    if (ok) _reload();
  }

  void _showQr(Map<String, dynamic> a) {
    final link = a['link'] as String;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('QR code ${a['agentCode']}'),
        // Largeur fixe : le QR code ne peut pas calculer sa largeur seul.
        content: SizedBox(
          width: 300.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KitungaReferralQr(code: a['referralCode'] as String, size: 240.0),
              const SizedBox(height: 8.0),
              SelectableText(link, style: salesBody(color: kSalesInk)),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copier le lien'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Lien copié.')));
            },
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _campaign['status'] as String;
    final next = campaignTransitions[status] ?? const [];
    return Scaffold(
      backgroundColor: kSalesSurface,
      appBar: AppBar(
        backgroundColor: kSalesRed,
        foregroundColor: Colors.white,
        title: Text('${_campaign['name']}'),
        actions: [
          if (['draft', 'scheduled', 'active', 'paused'].contains(status))
            IconButton(
                tooltip: 'Modifier',
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined)),
        ],
      ),
      body: SalesPage(
        onRefresh: () async => _reload(),
        children: [
          SalesCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  StatusChip(campaignStatus[status]),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                        'Du ${dateFr(_campaign['startsAt'] as String?)} au '
                        '${dateFr(_campaign['endsAt'] as String?)}',
                        style: salesBody(color: kSalesInk)),
                  ),
                ]),
                if ((_campaign['objective'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 8.0),
                  Text('Objectif : ${_campaign['objective']}',
                      style: salesBody(color: kSalesInk)),
                ],
                if ((_campaign['description'] as String?)?.isNotEmpty == true)
                  Text('${_campaign['description']}', style: salesBody()),
                const SizedBox(height: 6.0),
                Text(_ruleLabel(widget.rules, _campaign['ruleId'] as String?),
                    style: salesBody()),
                Text(
                    'Délai après la fin : ${_campaign['graceDays']} j · délai de '
                    'sécurité : ${_campaign['holdDays']} j',
                    style: salesBody()),
                if (_campaign['statusReason'] != null)
                  Text('Motif : ${_campaign['statusReason']}', style: salesBody()),
                if (next.isNotEmpty) ...[
                  const SizedBox(height: 12.0),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      for (final to in next)
                        to == 'active'
                            ? FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: kSalesRed),
                                onPressed: () => _changeStatus(to),
                                child: Text(campaignActionLabel[to]!))
                            : OutlinedButton(
                                onPressed: () => _changeStatus(to),
                                child: Text(campaignActionLabel[to]!)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20.0),
          SalesLoader(
            future: _detail,
            onRetry: _reload,
            builder: (data) {
              final assignments = listOf(data['assignments']);
              final agents = listOf(data['agents']);
              final canAssign =
                  ['draft', 'scheduled', 'active', 'paused'].contains(status);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text('Commerciaux affectés',
                              style: salesTitle(15.0))),
                      if (canAssign)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: kSalesRed),
                          onPressed: () => _assign(agents),
                          icon: const Icon(Icons.person_add_alt_rounded),
                          label: const Text('Affecter'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10.0),
                  if (assignments.isEmpty)
                    const SalesEmpty(
                        icon: Icons.groups_outlined,
                        title: 'Aucun commercial affecté'),
                  for (final a in assignments) ...[
                    SalesCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8.0,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text('${a['referralCode']}',
                                        style: salesTitle(15.0)),
                                    StatusChip(assignmentStatus[a['status']]),
                                  ],
                                ),
                                Text(
                                    'Du ${dateFr(a['startsAt'] as String?)} au '
                                    '${dateFr(a['endsAt'] as String?)}',
                                    style: salesBody()),
                                if (a['allowOverlap'] == true)
                                  Text('Chevauchement autorisé : ${a['overlapReason']}',
                                      style: salesBody()),
                              ],
                            ),
                          ),
                          IconButton(
                              tooltip: 'QR code et lien',
                              onPressed: () => _showQr(a),
                              icon: const Icon(Icons.qr_code_2_rounded)),
                          if (a['status'] == 'active')
                            PopupMenuButton<String>(
                              onSelected: (s) => _endAssignment(a, s),
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'ended', child: Text('Terminer')),
                                PopupMenuItem(
                                    value: 'cancelled', child: Text('Annuler')),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8.0),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AssignForm extends StatefulWidget {
  const _AssignForm({required this.campaign, required this.agents});

  final Map<String, dynamic> campaign;
  final List<Map<String, dynamic>> agents;

  @override
  State<_AssignForm> createState() => _AssignFormState();
}

class _AssignFormState extends State<_AssignForm> {
  late String _agentUid = widget.agents.first['uid'] as String;
  late DateTime? _start = brazzavilleDay(widget.campaign['startsAt'] as String?);
  late DateTime? _end = brazzavilleDay(widget.campaign['endsAt'] as String?)
      ?.subtract(const Duration(days: 1));
  bool _overlap = false;
  final _reason = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_start == null || _end == null) return;
    if (_overlap && _reason.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaAssignAgent', {
              'campaignId': widget.campaign['id'],
              'agentUid': _agentUid,
              'startsAt': brazzavilleDayStart(_start!),
              'endsAt': brazzavilleDayEnd(_end!),
              if (_overlap) 'allowOverlap': true,
              if (_overlap) 'overlapReason': _reason.text.trim(),
            }),
        'Commercial affecté : son code et son QR code sont prêts.');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  Widget _day(String label, DateTime? v, ValueChanged<DateTime> set) => InkWell(
        onTap: () async {
          final d = await pickDay(context, v);
          if (d != null) setState(() => set(d));
        },
        child: InputDecorator(
          decoration: salesInput(label),
          child: Text(v == null ? '—' : DateFormat('d MMMM yyyy', 'fr').format(v)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Affecter un commercial'),
      content: SizedBox(
        width: 440.0,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _agentUid,
                isExpanded: true,
                decoration: salesInput('Commercial'),
                items: [
                  for (final a in widget.agents)
                    DropdownMenuItem(
                        value: a['uid'] as String,
                        child: Text('${a['agentCode']} · ${a['displayName']}')),
                ],
                onChanged: (v) => setState(() => _agentUid = v!),
              ),
              const SizedBox(height: 12.0),
              _day('Premier jour', _start, (d) => _start = d),
              const SizedBox(height: 12.0),
              _day('Dernier jour (inclus)', _end, (d) => _end = d),
              const SizedBox(height: 4.0),
              Text('Dans les dates de la campagne.', style: salesBody(size: 12.0)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: kSalesRed,
                value: _overlap,
                title: const Text('Autoriser un chevauchement'),
                subtitle: const Text(
                    'Seulement si ce commercial travaille déjà sur ces dates.'),
                onChanged: (v) => setState(() => _overlap = v),
              ),
              if (_overlap)
                TextField(
                  controller: _reason,
                  maxLines: 2,
                  decoration: salesInput('Motif (obligatoire, journalisé)'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kSalesRed),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Affectation…' : 'Affecter'),
        ),
      ],
    );
  }
}
