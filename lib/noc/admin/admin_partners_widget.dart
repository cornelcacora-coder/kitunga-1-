import 'dart:async';

import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_util.dart';
import '/noc/sales/sales_common.dart';
import 'admin_categories_widget.dart' show loadAdminCategories;
import 'admin_products_widget.dart' show loadAdminPartners;
import 'admin_shell.dart';

/// Commerçants & boutiques (adresse /commercants) et livreurs (/livreurs) :
/// voir la fiche, ajouter un compte, modifier (nom, téléphone, catégorie,
/// horaires, logo, couverture, certification), supprimer.
///
/// « Supprimer » désactive le compte : connexion bloquée et commerce retiré
/// de l'application, mais l'historique (commandes, paiements) est conservé
/// et le compte peut être réactivé.
class AdminPartnersWidget extends StatefulWidget {
  const AdminPartnersWidget({super.key, required this.role, this.category});

  static String sellersRouteName = 'AdminSellers';
  static String deliversRouteName = 'AdminDelivers';

  /// 'Seller' (commerçants) ou 'Deliver' (livreurs).
  final String role;

  /// Filtre de départ (paramètre « categorie »).
  final String? category;

  @override
  State<AdminPartnersWidget> createState() => _AdminPartnersWidgetState();
}

class _AdminPartnersWidgetState extends State<AdminPartnersWidget> {
  bool get _sellers => widget.role == 'Seller';
  String _q = '';
  late String? _category = widget.category;
  Timer? _debounce;
  late Future<List<Map<String, dynamic>>> _future = _load();
  late final Future<List<Map<String, dynamic>>> _categories = _sellers
      ? loadAdminCategories()
      : Future.value(const <Map<String, dynamic>>[]);

  Future<List<Map<String, dynamic>>> _load() => loadAdminPartners(widget.role,
      q: _q, category: _sellers ? _category : null);

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  void didUpdateWidget(AdminPartnersWidget old) {
    super.didUpdateWidget(old);
    if (old.role != widget.role || old.category != widget.category) {
      _category = widget.category;
      _reload();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<List<String>> _categoryNames() async {
    final list = await _categories.catchError((_) => <Map<String, dynamic>>[]);
    return [for (final c in list) c['name'] as String];
  }

  Future<void> _edit(Map<String, dynamic> p) async {
    final categories = await _categoryNames();
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PartnerForm(partner: p, categories: categories),
    );
    if (saved == true) _reload();
  }

  Future<void> _add() async {
    final categories = await _categoryNames();
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _NewPartnerForm(role: widget.role, categories: categories),
    );
    if (saved == true) _reload();
  }

  void _view(Map<String, dynamic> p) {
    final cover = (p['businessCover'] ?? '') as String;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: EdgeInsets.zero,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_sellers && cover.isNotEmpty)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28.0)),
                child: AdminImage(cover, height: 130.0),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 18.0, 24.0, 0.0),
              child: Row(
                children: [
                  ClipOval(
                    child: AdminImage(p['photoUrl'] ?? '',
                        width: 52.0,
                        height: 52.0,
                        icon: _sellers
                            ? Icons.storefront_outlined
                            : Icons.person_outline),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(_name(p),
                        style: salesTitle(18.0),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420.0,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(accountStatusStyle[p['accountStatus']]),
                ),
                if (p['accountStatus'] == 'suspended')
                  AdminInfoRow('Motif', p['accountStatusReason'] ?? ''),
                if (_sellers) AdminInfoRow('Catégorie', p['category'] ?? ''),
                AdminInfoRow('Email', p['email'] ?? ''),
                AdminInfoRow('Téléphone', p['phone'] ?? ''),
                if (_sellers) AdminInfoRow('Horaires', p['horraire'] ?? ''),
                if (_sellers)
                  AdminInfoRow('Produits', '${p['products'] ?? 0}'),
                AdminInfoRow('Certifié', p['verified'] == true ? 'Oui' : 'Non'),
                AdminInfoRow('Présentation', p['bio'] ?? ''),
                AdminInfoRow('Inscrit le', dateFr(p['createdAt'])),
              ],
            ),
          ),
        ),
        actions: [
          if (_sellers)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.go(Uri(
                    path: AdminPaths.products,
                    queryParameters: {'commerce': p['uid']}).toString());
              },
              child: const Text('Voir ses produits'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _edit(p);
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

  Future<void> _setStatus(Map<String, dynamic> p, String status) async {
    String? reason;
    if (status == 'suspended') {
      reason = await askText(context, 'Supprimer « ${_name(p)} » ?',
          hint: _sellers
              ? 'Le compte est désactivé : connexion bloquée et commerce '
                  'retiré de l\'application. L\'historique est conservé et le '
                  'compte peut être réactivé.'
              : 'Le compte est désactivé : connexion bloquée. L\'historique '
                  'est conservé et le compte peut être réactivé.');
      if (reason == null) return;
    } else {
      final ok = await adminConfirm(context,
          title: 'Réactiver « ${_name(p)} » ?',
          message: 'Le compte pourra de nouveau se connecter'
              '${_sellers ? ' et le commerce réapparaîtra dans l\'application' : ''}.',
          confirm: 'Réactiver');
      if (!ok) return;
    }
    if (!mounted) return;
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaSetAccountStatus', {
              'userUid': p['uid'],
              'status': status,
              if (reason != null) 'reason': reason,
            }),
        status == 'suspended' ? 'Compte désactivé' : 'Compte réactivé');
    if (ok) _reload();
  }

  String _name(Map<String, dynamic> p) =>
      (p['displayName'] as String?)?.isNotEmpty == true
          ? p['displayName']
          : (p['email'] as String?)?.isNotEmpty == true
              ? p['email']
              : 'Sans nom';

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      current: _sellers ? 'sellers' : 'delivers',
      title: _sellers ? 'Commerçants & boutiques' : 'Livreurs',
      subtitle: _sellers
          ? 'Commerces présents dans l\'application'
          : 'Livreurs partenaires',
      actions: [
        IconButton(
            tooltip: 'Actualiser',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded)),
        adminAddButton(
            _sellers ? 'Nouveau commerce' : 'Nouveau livreur', _add),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 12.0),
            child: Wrap(
              spacing: 10.0,
              runSpacing: 10.0,
              children: [
                AdminSearchField(
                  hint: 'Nom, email ou téléphone',
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400), () {
                      _q = v.trim();
                      _reload();
                    });
                  },
                ),
                if (_sellers)
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _categories,
                    builder: (context, snap) {
                      final names = [
                        for (final c
                            in snap.data ?? const <Map<String, dynamic>>[])
                          c['name'] as String,
                      ];
                      return SizedBox(
                        width: 220.0,
                        child: DropdownButtonFormField<String?>(
                          key: ValueKey('cat-${names.length}-$_category'),
                          initialValue:
                              names.contains(_category) ? _category : null,
                          isExpanded: true,
                          decoration: salesInput('Catégorie').copyWith(
                              isDense: true, fillColor: Colors.white),
                          items: [
                            const DropdownMenuItem<String?>(
                                value: null, child: Text('Toutes')),
                            for (final n in names)
                              DropdownMenuItem<String?>(
                                  value: n, child: Text(n)),
                          ],
                          onChanged: (v) {
                            _category = v;
                            _reload();
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
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
                final list = snap.data!;
                if (list.isEmpty) {
                  return SalesEmpty(
                      icon: _sellers
                          ? Icons.storefront_outlined
                          : Icons.delivery_dining_outlined,
                      title: _sellers ? 'Aucun commerce' : 'Aucun livreur',
                      text: 'Aucun compte ne correspond à cette recherche.');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 40.0),
                  itemCount: list.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 8.0),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      final n = list.length;
                      return Text(
                          _sellers
                              ? '$n commerce${n > 1 ? 's' : ''}'
                              : '$n livreur${n > 1 ? 's' : ''}',
                          style: salesBody());
                    }
                    final p = list[i - 1];
                    final suspended = p['accountStatus'] == 'suspended';
                    return SalesCard(
                      onTap: () => _view(p),
                      child: Row(
                        children: [
                          ClipOval(
                            child: Opacity(
                              opacity: suspended ? 0.45 : 1.0,
                              child: AdminImage(p['photoUrl'] ?? '',
                                  width: 52.0,
                                  height: 52.0,
                                  icon: _sellers
                                      ? Icons.storefront_outlined
                                      : Icons.person_outline),
                            ),
                          ),
                          const SizedBox(width: 14.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(_name(p),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: salesTitle(15.0)),
                                    ),
                                    if (p['verified'] == true) ...[
                                      const SizedBox(width: 6.0),
                                      const Icon(Icons.verified_rounded,
                                          size: 16.0, color: Color(0xFF2F6FDB)),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                    [
                                      if (_sellers &&
                                          (p['category'] ?? '').isNotEmpty)
                                        p['category'],
                                      if ((p['phone'] ?? '').isNotEmpty)
                                        p['phone'],
                                      if ((p['email'] ?? '').isNotEmpty)
                                        p['email'],
                                    ].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: salesBody(size: 12.5)),
                                const SizedBox(height: 6.0),
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 4.0,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    StatusChip(
                                        accountStatusStyle[p['accountStatus']]),
                                    if (_sellers)
                                      Text(
                                          '${p['products'] ?? 0} produit'
                                          '${(p['products'] ?? 0) > 1 ? 's' : ''}',
                                          style: salesBody(size: 12.0)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          AdminRowActions(actions: [
                            viewAction(() => _view(p)),
                            editAction(() => _edit(p)),
                            if (_sellers)
                              (
                                label: 'Voir ses produits',
                                icon: Icons.shopping_bag_outlined,
                                onTap: () => context.go(Uri(
                                    path: AdminPaths.products,
                                    queryParameters: {
                                      'commerce': p['uid']
                                    }).toString()),
                                danger: false,
                              ),
                            if (suspended)
                              (
                                label: 'Réactiver',
                                icon: Icons.restore_rounded,
                                onTap: () => _setStatus(p, 'active'),
                                danger: false,
                              )
                            else
                              deleteAction(() => _setStatus(p, 'suspended')),
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

/// Modification d'une fiche existante.
class _PartnerForm extends StatefulWidget {
  const _PartnerForm({required this.partner, required this.categories});

  final Map<String, dynamic> partner;
  final List<String> categories;

  @override
  State<_PartnerForm> createState() => _PartnerFormState();
}

class _PartnerFormState extends State<_PartnerForm> {
  late final Map<String, dynamic> _p = widget.partner;
  late final bool _seller = _p['role'] == 'Seller';
  late final _name = TextEditingController(text: _p['displayName'] ?? '');
  late final _phone = TextEditingController(text: _p['phone'] ?? '');
  late final _bio = TextEditingController(text: _p['bio'] ?? '');
  late final _hours = TextEditingController(text: _p['horraire'] ?? '');
  late String? _category = widget.categories.contains(_p['category'])
      ? _p['category'] as String
      : null;
  late String _photo = _p['photoUrl'] ?? '';
  late String _cover = _p['businessCover'] ?? '';
  late bool _verified = _p['verified'] == true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _bio, _hours]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      return setState(() => _error = 'Indiquez le nom.');
    }
    if (_seller && _category == null) {
      return setState(() => _error = 'Choisissez la catégorie.');
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaSavePartner', {
              'uid': _p['uid'],
              'displayName': _name.text.trim(),
              'phone': _phone.text.trim(),
              'bio': _bio.text.trim(),
              'photoUrl': _photo,
              'verified': _verified,
              if (_seller) ...{
                'category': _category,
                'horraire': _hours.text.trim(),
                'businessCover': _cover,
              },
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
      title: _seller ? 'Modifier le commerce' : 'Modifier le livreur',
      saving: _saving,
      onSave: _save,
      children: [
        AdminFieldRow(children: [
          AdminImageField(
            label: _seller ? 'Logo' : 'Photo',
            value: _photo,
            height: 120.0,
            allowRemove: true,
            onChanged: (v) => setState(() => _photo = v),
          ),
          if (_seller)
            AdminImageField(
              label: 'Couverture',
              value: _cover,
              height: 120.0,
              allowRemove: true,
              onChanged: (v) => setState(() => _cover = v),
            ),
        ]),
        TextField(
          controller: _name,
          maxLength: 80,
          decoration: salesInput(_seller ? 'Nom du commerce' : 'Nom'),
        ),
        AdminFieldRow(children: [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: salesInput('Téléphone', hint: '06 123 45 67'),
          ),
          if (_seller)
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: salesInput('Catégorie'),
              items: [
                for (final c in widget.categories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
        ]),
        if (_seller)
          TextField(
            controller: _hours,
            maxLength: 120,
            decoration: salesInput('Horaires', hint: 'Ex. Lun-Sam 8h-20h'),
          ),
        TextField(
          controller: _bio,
          maxLines: 3,
          maxLength: 500,
          decoration: salesInput('Présentation'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: kSalesRed,
          value: _verified,
          onChanged: (v) => setState(() => _verified = v),
          title: const Text('Compte certifié'),
          subtitle: const Text('Badge de confiance affiché aux clients.'),
        ),
        if (_error != null) Text(_error!, style: salesBody(color: kSalesRed)),
      ],
    );
  }
}

/// Création d'un compte commerçant ou livreur (fonction kitungaCreatePartner,
/// la même que le formulaire d'inscription des partenaires).
class _NewPartnerForm extends StatefulWidget {
  const _NewPartnerForm({required this.role, required this.categories});

  final String role;
  final List<String> categories;

  @override
  State<_NewPartnerForm> createState() => _NewPartnerFormState();
}

const kPartnerPlans = ['Mensuel - 250F', 'Trimestriel - 500 F', 'Annuel - 1000 F'];

class _NewPartnerFormState extends State<_NewPartnerForm> {
  late final bool _seller = widget.role == 'Seller';
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _hours = TextEditingController();
  final _bio = TextEditingController();
  String? _category;
  String _plan = kPartnerPlans.first;
  String _photo = '';
  String _cover = '';
  bool _verified = false;
  bool _showPassword = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _password, _name, _phone, _hours, _bio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    String? error;
    if (_name.text.trim().isEmpty) error = 'Indiquez le nom.';
    if (!_email.text.contains('@')) error ??= 'Adresse email invalide.';
    if (_password.text.length < 6) {
      error ??= 'Mot de passe : 6 caractères au moins.';
    }
    if (_seller && _category == null) error ??= 'Choisissez la catégorie.';
    if (error != null) return setState(() => _error = error);
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await salesCall('kitungaCreatePartner', {
        'email': _email.text.trim(),
        'password': _password.text,
        'role': widget.role,
        'displayName': _name.text.trim(),
        'phoneNumber': _phone.text.trim(),
        // Livreur : catégorie par défaut du serveur, comme à l'inscription.
        'category': _seller ? _category : '',
        'verified': _verified,
        'bio': _bio.text.trim(),
        'horraire': _hours.text.trim(),
        'subscribeType': _seller ? _plan : '',
      });
      // Logo et couverture : ajoutés à la fiche juste après la création.
      if (_photo.isNotEmpty || _cover.isNotEmpty) {
        await salesCall('kitungaSavePartner', {
          'uid': created['uid'],
          if (_photo.isNotEmpty) 'photoUrl': _photo,
          if (_cover.isNotEmpty) 'businessCover': _cover,
        });
      }
      messenger.showSnackBar(SnackBar(
          content: Text(_seller ? 'Commerce créé' : 'Livreur créé'),
          backgroundColor: const Color(0xFF136B3D)));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormDialog(
      title: _seller ? 'Nouveau commerce' : 'Nouveau livreur',
      saveLabel: 'Créer le compte',
      saving: _saving,
      onSave: _save,
      children: [
        Text(
            'Le partenaire se connectera à l\'application mobile avec cet email '
            'et ce mot de passe. Communiquez-les-lui de façon sûre.',
            style: salesBody()),
        TextField(
          controller: _name,
          maxLength: 80,
          decoration: salesInput(_seller ? 'Nom du commerce' : 'Nom complet'),
        ),
        AdminFieldRow(children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: salesInput('Email de connexion'),
          ),
          TextField(
            controller: _password,
            obscureText: !_showPassword,
            decoration: salesInput('Mot de passe').copyWith(
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Masquer' : 'Afficher',
                icon: Icon(_showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),
        ]),
        AdminFieldRow(children: [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: salesInput('Téléphone', hint: '06 123 45 67'),
          ),
          if (_seller)
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: salesInput('Catégorie'),
              items: [
                for (final c in widget.categories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
        ]),
        if (_seller) ...[
          DropdownButtonFormField<String>(
            initialValue: _plan,
            isExpanded: true,
            decoration: salesInput('Formule d\'abonnement'),
            items: [
              for (final p in kPartnerPlans)
                DropdownMenuItem(value: p, child: Text(p)),
            ],
            onChanged: (v) => setState(() => _plan = v ?? _plan),
          ),
          TextField(
            controller: _hours,
            maxLength: 120,
            decoration: salesInput('Horaires', hint: 'Ex. Lun-Sam 8h-20h'),
          ),
        ],
        AdminFieldRow(children: [
          AdminImageField(
            label: _seller ? 'Logo' : 'Photo',
            value: _photo,
            height: 110.0,
            allowRemove: true,
            onChanged: (v) => setState(() => _photo = v),
          ),
          if (_seller)
            AdminImageField(
              label: 'Couverture',
              value: _cover,
              height: 110.0,
              allowRemove: true,
              onChanged: (v) => setState(() => _cover = v),
            ),
        ]),
        TextField(
          controller: _bio,
          maxLines: 3,
          maxLength: 500,
          decoration: salesInput('Présentation'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: kSalesRed,
          value: _verified,
          onChanged: (v) => setState(() => _verified = v),
          title: const Text('Compte certifié'),
        ),
        if (_error != null) Text(_error!, style: salesBody(color: kSalesRed)),
      ],
    );
  }
}
