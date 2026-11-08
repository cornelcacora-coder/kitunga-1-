import 'dart:async';

import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_util.dart';
import '/noc/sales/sales_common.dart';
import 'admin_categories_widget.dart' show loadAdminCategories;
import 'admin_products_widget.dart' show loadAdminPartners;
import 'admin_shell.dart';
import '/backend/kitunga_cuisines.dart';
import 'admin_menu_import.dart';
import '/noc/ui/admin_export.dart';
import '/noc/ui/admin_table.dart';

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
    final suspended = p['accountStatus'] == 'suspended';
    showAdminDetail(
      context,
      title: _name(p),
      subtitle: _sellers ? p['category'] as String? : 'Livreur partenaire',
      media: _sellers && cover.isNotEmpty
          ? AdminImage(cover, fit: BoxFit.cover)
          : null,
      avatar: ClipOval(
        child: AdminImage(p['photoUrl'] ?? '',
            width: 68.0,
            height: 68.0,
            icon: _sellers ? Icons.storefront_outlined : Icons.person_outline),
      ),
      badges: [
        suspended
            ? const AdminBadge('Suspendu', tone: kToneOrange)
            : const AdminBadge('Actif', tone: kToneGreen),
        if (p['verified'] == true)
          const AdminBadge('Certifié', tone: kToneBlue),
      ],
      facts: [
        fact('Email', p['email'] ?? '', Icons.alternate_email_rounded),
        fact('Téléphone', p['phone'] ?? '', Icons.phone_rounded),
        if (_sellers) ...[
          fact('Produits', '${p['products'] ?? 0}', Icons.shopping_bag_rounded),
          fact('Horaires', p['horraire'] ?? '', Icons.schedule_rounded),
        ],
        fact('Inscrit le', dateFr(p['createdAt']), Icons.event_rounded),
        if (suspended)
          fact('Motif de suspension', p['accountStatusReason'] ?? '',
              Icons.block_rounded),
      ],
      note: p['bio'] as String?,
      actions: [
        if (_sellers)
          (
            label: 'Voir ses produits',
            icon: Icons.shopping_bag_outlined,
            onTap: () => context.go(Uri(
                path: AdminPaths.products,
                queryParameters: {'commerce': p['uid']}).toString()),
            primary: false
          ),
        (label: 'Modifier', icon: Icons.edit_rounded, onTap: () => _edit(p), primary: true),
      ],
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
    final wide = MediaQuery.sizeOf(context).width >= 700.0;
    return AdminShell(
      current: _sellers ? 'sellers' : 'delivers',
      title: _sellers ? 'Commerçants & boutiques' : 'Livreurs',
      subtitle: _sellers
          ? 'Commerces présents dans l\'application'
          : 'Livreurs partenaires',
      actions: [
        OutlinedButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded, size: 18.0),
            label: const Text('Actualiser')),
        AdminExportButton(data: _export),
        adminAddButton(
            _sellers ? 'Nouveau commerce' : 'Nouveau livreur', _add),
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
                      width: wide
                          ? 320.0
                          : MediaQuery.sizeOf(context).width - 72.0,
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
                    if (_sellers)
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _categories,
                        builder: (context, snap) => AdminSelect<String?>(
                          value: _category,
                          icon: Icons.category_outlined,
                          items: {
                            null: 'Toutes les catégories',
                            for (final c
                                in snap.data ?? const <Map<String, dynamic>>[])
                              c['name'] as String: c['name'] as String,
                          },
                          onChanged: (v) {
                            _category = v;
                            _reload();
                          },
                        ),
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
                    AdminSelect<String>(
                      value: _verifiedFilter,
                      icon: Icons.verified_outlined,
                      items: const {
                        'all': 'Certifiés ou non',
                        'yes': 'Certifiés',
                        'no': 'Non certifiés',
                      },
                      onChanged: (v) => setState(() => _verifiedFilter = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                FutureBuilder<List<Map<String, dynamic>>>(
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
                    final list = [
                      for (final p in snap.data!)
                        if ((_statusFilter == 'all' ||
                                (p['accountStatus'] ?? 'active') ==
                                    _statusFilter) &&
                            (_verifiedFilter == 'all' ||
                                (_verifiedFilter == 'yes') ==
                                    (p['verified'] == true)))
                          p,
                    ];
                    _shown = list;
                    final n = list.length;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (n > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Text(
                                _sellers
                                    ? '$n commerce${n > 1 ? 's' : ''}'
                                    : '$n livreur${n > 1 ? 's' : ''}',
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
  String _statusFilter = 'all';
  String _verifiedFilter = 'all';

  AdminExportData? _export() {
    final list = _shown;
    if (list == null) return null;
    final n = list.length;
    return AdminExportData(
      title: _sellers ? 'Commerçants & boutiques' : 'Livreurs',
      subtitle: [
        if (_sellers && _category != null) 'catégorie $_category',
        if (_q.isNotEmpty) 'recherche « $_q »',
        _sellers ? '$n commerce${n > 1 ? 's' : ''}' : '$n livreur${n > 1 ? 's' : ''}',
      ].join(' · '),
      fileName: _sellers ? 'commercants' : 'livreurs',
      headers: [
        _sellers ? 'Commerce' : 'Livreur',
        'Email',
        'Téléphone',
        if (_sellers) 'Catégorie',
        if (_sellers) 'Produits',
        if (_sellers) 'Horaires',
        'Certifié',
        'Statut',
        'Inscrit le',
      ],
      flex: _sellers ? [4, 4, 2, 2, 1, 3, 1, 2, 2] : [4, 4, 3, 2, 2, 2],
      rows: [
        for (final p in list)
          [
            _name(p),
            p['email'] ?? '',
            p['phone'] ?? '',
            if (_sellers) p['category'] ?? '',
            if (_sellers) p['products'] as num?,
            if (_sellers) p['horraire'] ?? '',
            p['verified'] == true ? 'Oui' : 'Non',
            p['accountStatus'] == 'suspended' ? 'Suspendu' : 'Actif',
            dateFr(p['createdAt']),
          ],
      ],
    );
  }

  Widget _identity(Map<String, dynamic> p) {
    final suspended = p['accountStatus'] == 'suspended';
    return Row(
      children: [
        Opacity(
          opacity: suspended ? 0.45 : 1.0,
          child: ClipOval(
            child: AdminImage(p['photoUrl'] ?? '',
                width: 40.0,
                height: 40.0,
                icon: _sellers
                    ? Icons.storefront_outlined
                    : Icons.person_outline),
          ),
        ),
        const SizedBox(width: 12.0),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(_name(p),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AdminText.strong(size: 13.5)),
                  ),
                  if (p['verified'] == true) ...[
                    const SizedBox(width: 4.0),
                    const Tooltip(
                      message: 'Compte certifié',
                      child: Icon(Icons.verified_rounded,
                          size: 15.0, color: AdminColors.blue),
                    ),
                  ],
                ],
              ),
              if ((p['email'] ?? '').isNotEmpty)
                Text(p['email'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminText.label(size: 12.0)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _status(Map<String, dynamic> p) => p['accountStatus'] == 'suspended'
      ? const AdminBadge('Suspendu', tone: kToneOrange)
      : const AdminBadge('Actif', tone: kToneGreen);

  List<Widget> _actions(Map<String, dynamic> p) {
    final suspended = p['accountStatus'] == 'suspended';
    return [
      AdminActionDot(
          icon: Icons.visibility_rounded,
          tooltip: 'Voir',
          onTap: () => _view(p)),
      AdminActionDot(
          icon: Icons.edit_rounded,
          tooltip: 'Modifier',
          tone: kToneOrange,
          onTap: () => _edit(p)),
      if (_sellers)
        AdminActionDot(
            icon: Icons.shopping_bag_rounded,
            tooltip: 'Voir ses produits',
            tone: kToneViolet,
            onTap: () => context.go(Uri(
                path: AdminPaths.products,
                queryParameters: {'commerce': p['uid']}).toString())),
      if (_sellers && hasCuisines('${p['category'] ?? ''}'))
        AdminActionDot(
            icon: Icons.restaurant_menu_rounded,
            tooltip: 'Importer un menu',
            tone: kToneGreen,
            onTap: () async {
              await showMenuImport(context,
                  sellerUid: p['uid'] as String, sellerName: _name(p));
              _reload();
            }),
      suspended
          ? AdminActionDot(
              icon: Icons.restore_rounded,
              tooltip: 'Réactiver',
              tone: kToneGreen,
              onTap: () => _setStatus(p, 'active'))
          : AdminActionDot(
              icon: Icons.delete_rounded,
              tooltip: 'Supprimer',
              tone: kToneRed,
              onTap: () => _setStatus(p, 'suspended')),
    ];
  }

  Widget _table(List<Map<String, dynamic>> list) {
    return AdminTable<Map<String, dynamic>>(
      rows: list,
      initialSort: 0,
      initialAscending: true,
      empty: AdminEmpty(
          icon: _sellers
              ? Icons.storefront_outlined
              : Icons.delivery_dining_outlined,
          title: _sellers ? 'Aucun commerce' : 'Aucun livreur',
          message: 'Aucun compte ne correspond à cette recherche.'),
      onTap: _view,
      actionsWidth: _sellers ? 206.0 : 124.0,
      actions: _actions,
      columns: [
        AdminColumn(
            label: _sellers ? 'Commerce' : 'Livreur',
            flex: 5,
            cell: _identity,
            sortKey: (p) => _name(p).toLowerCase()),
        if (_sellers)
          AdminColumn(
              label: 'Catégorie',
              flex: 2,
              cell: (p) => Text((p['category'] ?? '').isEmpty ? '—' : p['category'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminText.body(size: 13.0)),
              sortKey: (p) => (p['category'] as String? ?? '').toLowerCase()),
        AdminColumn(
            label: 'Téléphone',
            flex: 2,
            cell: (p) => Text((p['phone'] ?? '').isEmpty ? '—' : p['phone'],
                style: AdminText.body(size: 13.0))),
        if (_sellers)
          AdminColumn(
              label: 'Produits',
              flex: 2,
              cell: (p) => Text(
                  '${p['products'] ?? 0} produit${(p['products'] ?? 0) > 1 ? 's' : ''}',
                  style: AdminText.body(size: 13.0)),
              sortKey: (p) => (p['products'] as num?)?.toInt()),
        AdminColumn(
            label: 'Inscrit le',
            flex: 2,
            cell: (p) =>
                Text(dateFr(p['createdAt']), style: AdminText.body(size: 13.0)),
            sortKey: (p) => p['createdAt'] as String?),
        AdminColumn(
            label: 'Statut',
            flex: 2,
            cell: _status,
            sortKey: (p) => p['accountStatus'] as String?),
      ],
      compact: (p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _identity(p),
          const SizedBox(height: 8.0),
          Wrap(
            spacing: 10.0,
            runSpacing: 6.0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _status(p),
              if (_sellers && (p['category'] ?? '').isNotEmpty)
                Text(p['category'], style: AdminText.label(size: 12.5)),
              if (_sellers)
                Text(
                    '${p['products'] ?? 0} produit${(p['products'] ?? 0) > 1 ? 's' : ''}',
                    style: AdminText.label(size: 12.5)),
            ],
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
  late final Set<String> _cuisines = {
    for (final c in (_p['cuisines'] as List? ?? const [])) '$c',
  };
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
                if (hasCuisines(_category ?? '')) 'cuisines': _cuisines.toList(),
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
      icon: _seller ? Icons.storefront_rounded : Icons.two_wheeler_rounded,
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
        if (_seller && hasCuisines(_category ?? ''))
          CuisinePicker(
            selected: _cuisines,
            onChanged: () => setState(() {}),
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
  final Set<String> _cuisines = {};
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
      if (_photo.isNotEmpty || _cover.isNotEmpty || _cuisines.isNotEmpty) {
        await salesCall('kitungaSavePartner', {
          'uid': created['uid'],
          if (_photo.isNotEmpty) 'photoUrl': _photo,
          if (_cover.isNotEmpty) 'businessCover': _cover,
          if (_cuisines.isNotEmpty) 'cuisines': _cuisines.toList(),
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
      icon: Icons.person_add_alt_1_rounded,
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
        if (_seller && hasCuisines(_category ?? ''))
          CuisinePicker(
            selected: _cuisines,
            onChanged: () => setState(() {}),
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

/// Choix des cuisines d'un restaurant (pastilles).
class CuisinePicker extends StatelessWidget {
  const CuisinePicker(
      {super.key, required this.selected, required this.onChanged});

  final Set<String> selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cuisines proposées (${selected.length}/8)',
            style: salesBody(color: kSalesInk)),
        const SizedBox(height: 8.0),
        Wrap(
          spacing: 6.0,
          runSpacing: 6.0,
          children: [
            for (final c in kCuisines)
              FilterChip(
                label: Text(c),
                selected: selected.contains(c),
                selectedColor: AdminColors.redSoft,
                checkmarkColor: AdminColors.red,
                onSelected: (v) {
                  if (v && selected.length >= 8) return;
                  v ? selected.add(c) : selected.remove(c);
                  onChanged();
                },
              ),
          ],
        ),
      ],
    );
  }
}
