import 'package:flutter/material.dart';

import 'sales_admin_widget.dart';
import 'sales_common.dart';

/// Onglet Commerciaux : liste, création, modification et statut.
class SalesAgentsTab extends StatefulWidget {
  const SalesAgentsTab({super.key});

  @override
  State<SalesAgentsTab> createState() => _SalesAgentsTabState();
}

class _SalesAgentsTabState extends State<SalesAgentsTab> {
  late Future<Map<String, dynamic>> _future = salesQuery('agents');

  void _reload() => setState(() {
        _future = salesQuery('agents');
      });

  Future<void> _create() async {
    final ok = await showDialog<bool>(
        context: context, builder: (_) => const _AgentForm());
    if (ok == true) _reload();
  }

  Future<void> _edit(Map<String, dynamic> agent) async {
    final ok = await showDialog<bool>(
        context: context, builder: (_) => _AgentForm(agent: agent));
    if (ok == true) _reload();
  }

  Future<void> _setStatus(Map<String, dynamic> agent, String status) async {
    final labels = {
      'active': 'Réactiver',
      'suspended': 'Suspendre',
      'archived': 'Archiver (définitif)',
    };
    String reason = '';
    if (status != 'active') {
      final r = await askText(context, '${labels[status]} ${agent['displayName']}',
          hint: status == 'archived'
              ? 'Le commercial ne pourra plus se connecter. Son historique est conservé.'
              : 'Ses liens ne rapporteront plus de commission.');
      if (r == null) return;
      reason = r;
    }
    if (!mounted) return;
    final done = await runSalesAction(
        context,
        () => salesCall('kitungaSetSalesAgentStatus',
            {'agentUid': agent['uid'], 'status': status, 'reason': reason}),
        'Statut mis à jour.');
    if (done) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return SalesPage(
      onRefresh: () async => _reload(),
      children: [
        Row(
          children: [
            Expanded(
                child: Text('Comptes professionnels des commerciaux',
                    style: salesBody())),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: kSalesRed),
              onPressed: _create,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Nouveau commercial'),
            ),
          ],
        ),
        const SizedBox(height: 16.0),
        SalesLoader(
          future: _future,
          onRetry: _reload,
          builder: (data) {
            final agents = listOf(data['agents']);
            if (agents.isEmpty) {
              return const SalesEmpty(
                icon: Icons.badge_outlined,
                title: 'Aucun commercial',
                text: 'Créez le premier compte commercial pour lancer une campagne.',
              );
            }
            return Column(
              children: [
                for (final a in agents) ...[
                  _AgentCard(
                    agent: a,
                    onEdit: () => _edit(a),
                    onStatus: (s) => _setStatus(a, s),
                  ),
                  const SizedBox(height: 10.0),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard(
      {required this.agent, required this.onEdit, required this.onStatus});

  final Map<String, dynamic> agent;
  final VoidCallback onEdit;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final status = agent['status'] as String?;
    final assignment = agent['currentAssignment'] as Map?;
    return SalesCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: kSalesRed.withValues(alpha: 0.12),
            child: Text(
                ((agent['displayName'] as String?) ?? '?').isNotEmpty
                    ? (agent['displayName'] as String)[0].toUpperCase()
                    : '?',
                style: salesTitle(16.0).copyWith(color: kSalesRed)),
          ),
          const SizedBox(width: 14.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${agent['displayName']}', style: salesTitle()),
                    Text('${agent['agentCode']}',
                        style: salesBody(color: kSalesRed, size: 13.0)),
                    StatusChip(agentStatus[status]),
                  ],
                ),
                const SizedBox(height: 4.0),
                Text('${agent['email']} · +${agent['phone']}', style: salesBody()),
                Text(payoutMethodLabel(agent['payoutMethod'] as Map?),
                    style: salesBody()),
                Text(
                  assignment == null
                      ? 'Aucune affectation en cours'
                      : 'Code ${assignment['code']} jusqu\'au ${dateFr(assignment['endsAt'] as String?)}',
                  style: salesBody(color: assignment == null ? kSalesMuted : kSalesInk),
                ),
                if (agent['statusReason'] != null)
                  Text('Motif : ${agent['statusReason']}', style: salesBody()),
              ],
            ),
          ),
          if (status != 'archived')
            PopupMenuButton<String>(
              tooltip: 'Actions',
              onSelected: (v) => v == 'edit' ? onEdit() : onStatus(v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                if (status == 'active')
                  const PopupMenuItem(value: 'suspended', child: Text('Suspendre')),
                if (status == 'suspended')
                  const PopupMenuItem(value: 'active', child: Text('Réactiver')),
                const PopupMenuItem(
                    value: 'archived', child: Text('Archiver (définitif)')),
              ],
            ),
        ],
      ),
    );
  }
}

/// Création (agent == null) ou modification d'un commercial.
class _AgentForm extends StatefulWidget {
  const _AgentForm({this.agent});

  final Map<String, dynamic>? agent;

  @override
  State<_AgentForm> createState() => _AgentFormState();
}

class _AgentFormState extends State<_AgentForm> {
  final _form = GlobalKey<FormState>();
  late final _name =
      TextEditingController(text: widget.agent?['displayName'] as String?);
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final _phone =
      TextEditingController(text: widget.agent?['phone'] as String?);
  late final Map? _method = widget.agent?['payoutMethod'] as Map?;
  late String _payType = (_method?['type'] as String?) ?? 'none';
  late String _operator = (_method?['operator'] as String?) ?? 'MTN';
  late final _payPhone =
      TextEditingController(text: _method?['phone'] as String?);
  late final _bank = TextEditingController(text: _method?['bank_name'] as String?);
  late final _holder =
      TextEditingController(text: _method?['account_holder'] as String?);
  late final _account =
      TextEditingController(text: _method?['account_number'] as String?);
  bool _saving = false;

  bool get _isNew => widget.agent == null;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _phone, _payPhone, _bank, _holder,
      _account]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic>? get _payoutMethod => switch (_payType) {
        'mobile_money' => {
            'type': 'mobile_money',
            'operator': _operator,
            'phone': _payPhone.text.trim(),
          },
        'bank' => {
            'type': 'bank',
            'bankName': _bank.text.trim(),
            'accountHolder': _holder.text.trim(),
            'accountNumber': _account.text.trim(),
          },
        _ => null,
      };

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = _isNew
        ? {
            'displayName': _name.text.trim(),
            'email': _email.text.trim(),
            'password': _password.text,
            'phone': _phone.text.trim(),
            'payoutMethod': _payoutMethod,
          }
        : {
            'agentUid': widget.agent!['uid'],
            'displayName': _name.text.trim(),
            'phone': _phone.text.trim(),
            'payoutMethod': _payoutMethod,
          };
    final ok = await runSalesAction(
        context,
        () => salesCall(
            _isNew ? 'kitungaCreateSalesAgent' : 'kitungaUpdateSalesAgent', data),
        _isNew ? 'Commercial créé.' : 'Commercial modifié.');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? 'Nouveau commercial' : 'Modifier le commercial'),
      content: SizedBox(
        width: 460.0,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                    controller: _name,
                    decoration: salesInput('Nom complet'),
                    validator: _required),
                const SizedBox(height: 12.0),
                if (_isNew) ...[
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: salesInput('Adresse e-mail de connexion'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12.0),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: salesInput('Mot de passe provisoire',
                        helper: '8 caractères minimum. À transmettre au '
                            'commercial, qui pourra le changer.'),
                    validator: (v) => (v ?? '').length < 8
                        ? '8 caractères minimum'
                        : null,
                  ),
                  const SizedBox(height: 12.0),
                ],
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: salesInput('Téléphone', hint: '06 XXX XX XX',
                      helper: 'Sert aussi à refuser l\'auto-parrainage.'),
                  validator: _required,
                ),
                const SizedBox(height: 16.0),
                DropdownButtonFormField<String>(
                  initialValue: _payType,
                  decoration: salesInput('Moyen de paiement des commissions'),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('Plus tard')),
                    DropdownMenuItem(
                        value: 'mobile_money', child: Text('Mobile Money')),
                    DropdownMenuItem(value: 'bank', child: Text('Virement bancaire')),
                  ],
                  onChanged: (v) => setState(() => _payType = v ?? 'none'),
                ),
                if (_payType == 'mobile_money') ...[
                  const SizedBox(height: 12.0),
                  DropdownButtonFormField<String>(
                    initialValue: _operator,
                    decoration: salesInput('Opérateur'),
                    items: const [
                      DropdownMenuItem(value: 'MTN', child: Text('MTN')),
                      DropdownMenuItem(value: 'Airtel', child: Text('Airtel')),
                    ],
                    onChanged: (v) => setState(() => _operator = v ?? 'MTN'),
                  ),
                  const SizedBox(height: 12.0),
                  TextFormField(
                      controller: _payPhone,
                      keyboardType: TextInputType.phone,
                      decoration: salesInput('Numéro Mobile Money'),
                      validator: _required),
                ],
                if (_payType == 'bank') ...[
                  const SizedBox(height: 12.0),
                  TextFormField(
                      controller: _bank,
                      decoration: salesInput('Banque'),
                      validator: _required),
                  const SizedBox(height: 12.0),
                  TextFormField(
                      controller: _holder,
                      decoration: salesInput('Titulaire du compte'),
                      validator: _required),
                  const SizedBox(height: 12.0),
                  TextFormField(
                      controller: _account,
                      decoration: salesInput('Numéro de compte (RIB)'),
                      validator: _required),
                ],
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
