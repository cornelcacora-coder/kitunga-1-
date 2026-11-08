import 'dart:async';

import 'package:flutter/material.dart';

import '/noc/sales/sales_common.dart';
import 'admin_categories_widget.dart' show loadAdminCategories;
import 'admin_shell.dart';
import '/noc/ui/admin_table.dart';

/// Produits (adresse /produits) : tous les produits, avec leur emplacement
/// (catégorie › commerce › rayon). Voir, ajouter, modifier, supprimer.
/// [sellerUid] (paramètre « commerce ») limite la liste à un commerce.
class AdminProductsWidget extends StatefulWidget {
  const AdminProductsWidget({super.key, this.sellerUid, this.missingImage = false});

  static String routeName = 'AdminProducts';
  static String routePath = AdminPaths.products;

  final String? sellerUid;

  /// Filtre « sans image » actif au départ (paramètre « sansImage »).
  final bool missingImage;

  @override
  State<AdminProductsWidget> createState() => _AdminProductsWidgetState();
}

Future<List<Map<String, dynamic>>> loadAdminPartners(String role,
        {String? q, String? category}) async =>
    listOf((await salesCall('kitungaCatalogQuery', {
      'view': 'partners',
      'role': role,
      if (q != null && q.isNotEmpty) 'q': q,
      if (category != null) 'category': category,
    }))['partners']);

/// Emplacement d'un produit dans l'application.
String productLocation(Map<String, dynamic> p) {
  final seller = p['seller'] as Map?;
  return [
    if ((seller?['category'] ?? '').toString().isNotEmpty) seller!['category'],
    seller?['name'] ?? 'Commerce supprimé',
    if ((p['section'] ?? '').toString().isNotEmpty) p['section'],
  ].join(' › ');
}

class _AdminProductsWidgetState extends State<AdminProductsWidget> {
  String _q = '';
  String? _category;
  late String? _sellerUid = widget.sellerUid;
  late bool _missingImage = widget.missingImage;
  Timer? _debounce;
  late Future<Map<String, dynamic>> _future = _load();
  late final Future<List<Map<String, dynamic>>> _sellers =
      loadAdminPartners('Seller');
  late final Future<List<Map<String, dynamic>>> _categories =
      loadAdminCategories();

  Future<Map<String, dynamic>> _load() => salesCall('kitungaCatalogQuery', {
        'view': 'products',
        if (_q.isNotEmpty) 'q': _q,
        if (_category != null) 'category': _category,
        if (_sellerUid != null) 'sellerUid': _sellerUid,
        if (_missingImage) 'missingImage': true,
      });

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

  Future<void> _edit([Map<String, dynamic>? product]) async {
    final sellers = await _sellers.catchError((_) => <Map<String, dynamic>>[]);
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProductForm(
          product: product, sellers: sellers, sellerUid: _sellerUid),
    );
    if (saved == true) _reload();
  }

  void _view(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(p['name'] ?? ''),
        content: SizedBox(
          width: 420.0,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14.0),
                  child: AdminImage(p['prodImg'] ?? '', height: 200.0),
                ),
                const SizedBox(height: 12.0),
                AdminInfoRow('Emplacement', productLocation(p)),
                AdminInfoRow('Statut',
                    p['published'] == false ? 'Brouillon (masqué)' : 'Publié'),
                AdminInfoRow('Prix', fcfa(p['price'])),
                AdminInfoRow('Stock', '${p['quantity'] ?? '—'}'),
                AdminInfoRow('Unité', p['unit'] ?? ''),
                AdminInfoRow('Mise en avant', p['tag'] ?? ''),
                AdminInfoRow('Livraison express',
                    p['express'] == true ? 'Oui' : 'Non'),
                if (p['requiresPrescription'] == true)
                  const AdminInfoRow('Ordonnance', 'Obligatoire'),
                AdminInfoRow('Description', p['description'] ?? ''),
                AdminInfoRow('Ajouté le', dateFr(p['createdAt'])),
              ],
            ),
          ),
        ),
        actions: [
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

  Future<void> _delete(Map<String, dynamic> p) async {
    final reason = await askText(context, 'Supprimer « ${p['name']} » ?',
        hint: 'Ex. doublon, produit interdit, plus vendu… Il sera retiré de '
            'l\'application et des paniers ; les commandes passées restent.');
    if (reason == null || !mounted) return;
    final ok = await runSalesAction(
        context,
        () => salesCall(
            'kitungaDeleteProduct', {'id': p['id'], 'reason': reason}),
        'Produit supprimé');
    if (ok) _reload();
  }

  Widget _filters(List<Map<String, dynamic>> categories,
      List<Map<String, dynamic>> sellers) {
    final wide = MediaQuery.sizeOf(context).width >= 700.0;
    return Wrap(
      spacing: 10.0,
      runSpacing: 10.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AdminSearchBox(
          width: wide ? 320.0 : MediaQuery.sizeOf(context).width - 72.0,
          hint: 'Produit, commerce ou rayon',
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), () {
              _q = v.trim();
              _reload();
            });
          },
        ),
        AdminSelect<String?>(
          value: _category,
          icon: Icons.category_outlined,
          items: {
            null: 'Toutes les catégories',
            for (final c in categories) c['name'] as String: c['name'] as String,
          },
          onChanged: (v) {
            _category = v;
            _reload();
          },
        ),
        AdminSelect<String?>(
          value: _sellerUid,
          icon: Icons.storefront_outlined,
          items: {
            null: 'Tous les commerces',
            for (final s in sellers)
              s['uid'] as String: (s['displayName'] as String?)?.isNotEmpty == true
                  ? s['displayName'] as String
                  : s['email'] as String? ?? s['uid'] as String,
          },
          onChanged: (v) {
            _sellerUid = v;
            _reload();
          },
        ),
        FilterChip(
          label: const Text('Sans image'),
          selected: _missingImage,
          selectedColor: AdminColors.redSoft,
          checkmarkColor: AdminColors.red,
          onSelected: (v) => setState(() {
            _missingImage = v;
            _future = _load();
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      current: _missingImage ? 'missing' : 'products',
      title: 'Produits',
      subtitle: 'Tous les produits des commerces, avec leur emplacement',
      actions: [
        OutlinedButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded, size: 18.0),
            label: const Text('Actualiser')),
        adminAddButton('Nouveau produit', () => _edit()),
      ],
      body: AdminScroll(
        children: [
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FutureBuilder<List<List<Map<String, dynamic>>>>(
                  future: Future.wait([
                    _categories.catchError((_) => <Map<String, dynamic>>[]),
                    _sellers.catchError((_) => <Map<String, dynamic>>[]),
                  ]),
                  builder: (context, snap) => _filters(
                      snap.data?[0] ?? const [], snap.data?[1] ?? const []),
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
                    final list = listOf(snap.data!['products']);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (list.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Text(
                                '${list.length} produit${list.length > 1 ? 's' : ''}'
                                '${list.length >= 300 ? ' (affinez la recherche pour voir les autres)' : ''}',
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

  Widget _badges(Map<String, dynamic> p) => Wrap(
        spacing: 6.0,
        runSpacing: 4.0,
        children: [
          p['published'] != false
              ? const AdminBadge('Publié', tone: kToneGreen)
              : const AdminBadge('Brouillon', tone: kToneGrey),
          if (p['express'] == true)
            const AdminBadge('⚡ Express', tone: kToneOrange),
          if ((p['tag'] ?? '').isNotEmpty)
            AdminBadge(p['tag'] as String, tone: kToneBlue),
        ],
      );

  Widget _thumbName(Map<String, dynamic> p) => Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AdminRadius.sm),
            child: AdminImage(p['prodImg'] ?? '', width: 44.0, height: 44.0),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Text(p['name'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AdminText.strong(size: 13.5)),
          ),
        ],
      );

  Widget _stock(Map<String, dynamic> p) {
    final qty = p['quantity'];
    return Text(qty == null ? '—' : 'Stock : $qty',
        style: AdminText.body(
            size: 13.0, color: qty == 0 ? AdminColors.red : AdminColors.text));
  }

  Widget _table(List<Map<String, dynamic>> list) {
    return AdminTable<Map<String, dynamic>>(
      rows: list,
      empty: const AdminEmpty(
          icon: Icons.shopping_bag_outlined,
          title: 'Aucun produit',
          message: 'Aucun produit ne correspond à ces filtres.'),
      onTap: _view,
      actionsWidth: 124.0,
      actions: (p) => [
        AdminActionDot(
            icon: Icons.visibility_rounded,
            tooltip: 'Voir',
            onTap: () => _view(p)),
        AdminActionDot(
            icon: Icons.edit_rounded,
            tooltip: 'Modifier',
            tone: kToneOrange,
            onTap: () => _edit(p)),
        AdminActionDot(
            icon: Icons.delete_rounded,
            tooltip: 'Supprimer',
            tone: kToneRed,
            onTap: () => _delete(p)),
      ],
      columns: [
        AdminColumn(
            label: 'Produit',
            flex: 4,
            cell: _thumbName,
            sortKey: (p) => (p['name'] as String? ?? '').toLowerCase()),
        AdminColumn(
            label: 'Emplacement',
            flex: 4,
            cell: (p) => Text(productLocation(p),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AdminText.body(size: 13.0)),
            sortKey: (p) => productLocation(p).toLowerCase()),
        AdminColumn(
            label: 'Prix',
            flex: 2,
            cell: (p) => Text(fcfa(p['price']), style: AdminText.strong(size: 13.0)),
            sortKey: (p) => (p['price'] as num?)?.toDouble()),
        AdminColumn(
            label: 'Stock',
            flex: 2,
            cell: _stock,
            sortKey: (p) => (p['quantity'] as num?)?.toInt()),
        AdminColumn(label: 'Statut', flex: 3, cell: _badges),
      ],
      compact: (p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _thumbName(p),
          const SizedBox(height: 6.0),
          Text(productLocation(p),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AdminText.label(size: 12.5)),
          const SizedBox(height: 6.0),
          Wrap(
            spacing: 10.0,
            runSpacing: 6.0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(fcfa(p['price']), style: AdminText.strong(size: 13.5)),
              _stock(p),
              _badges(p),
            ],
          ),
        ],
      ),
    );
  }
}


class _ProductForm extends StatefulWidget {
  const _ProductForm(
      {this.product, required this.sellers, required this.sellerUid});

  final Map<String, dynamic>? product;
  final List<Map<String, dynamic>> sellers;
  final String? sellerUid;

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

/// Mises en avant de l'application vendeur (champ specifications).
const kProductTags = ['', 'Nouveauté', 'Tendance'];

class _ProductFormState extends State<_ProductForm> {
  late final Map<String, dynamic> _p = widget.product ?? const {};
  late final bool _isNew = _p['id'] == null;
  late String? _seller =
      (_p['seller'] as Map?)?['uid'] as String? ?? widget.sellerUid;
  late final _name = TextEditingController(text: _p['name'] ?? '');
  late final _description =
      TextEditingController(text: _p['description'] ?? '');
  late final _price = TextEditingController(
      text: _p['price'] == null ? '' : '${(_p['price'] as num).round()}');
  late final _section = TextEditingController(text: _p['section'] ?? '');
  late final _unit = TextEditingController(text: _p['unit'] ?? '');
  late final _quantity = TextEditingController(
      text: _p['quantity'] == null ? '' : '${_p['quantity']}');
  late String _image = _p['prodImg'] ?? '';
  late String _tag =
      kProductTags.contains(_p['tag']) ? _p['tag'] as String : '';
  late bool _published = _p['published'] != false;
  late bool _express = _p['express'] == true;
  late bool _prescription = _p['requiresPrescription'] == true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _description, _price, _section, _unit, _quantity]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final price = parseInt(_price.text);
    final quantity = parseInt(_quantity.text);
    String? error;
    if (_isNew && _seller == null) error = 'Choisissez le commerce.';
    if (_name.text.trim().isEmpty) error ??= 'Indiquez le nom du produit.';
    if (price == null || price <= 0) error ??= 'Indiquez le prix (en FCFA).';
    if (quantity == null || quantity < 0) {
      error ??= 'Indiquez le stock (nombre entier).';
    }
    if (_published && _image.isEmpty) {
      error ??= 'Ajoutez une photo avant de publier ce produit.';
    }
    if (error != null) return setState(() => _error = error);
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaSaveProduct', {
              if (!_isNew) 'id': _p['id'],
              if (_isNew) 'sellerUid': _seller,
              'name': _name.text.trim(),
              'description': _description.text.trim(),
              'price': price,
              'quantity': quantity,
              'section': _section.text.trim(),
              'unit': _unit.text.trim(),
              'tag': _tag,
              'prodImg': _image,
              'published': _published,
              'express': _express,
              'requiresPrescription': _prescription,
            }),
        _isNew ? 'Produit ajouté' : 'Produit modifié');
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
      icon: Icons.shopping_bag_rounded,
      title: _isNew ? 'Nouveau produit' : 'Modifier le produit',
      saving: _saving,
      onSave: _save,
      children: [
        if (_isNew)
          DropdownButtonFormField<String>(
            initialValue: widget.sellers.any((s) => s['uid'] == _seller)
                ? _seller
                : null,
            isExpanded: true,
            decoration: salesInput('Commerce'),
            items: [
              for (final s in widget.sellers)
                DropdownMenuItem(
                  value: s['uid'] as String,
                  child: Text(
                      '${(s['displayName'] as String?)?.isNotEmpty == true ? s['displayName'] : s['email']}'
                      '${(s['category'] as String?)?.isNotEmpty == true ? ' · ${s['category']}' : ''}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _seller = v),
          )
        else
          AdminInfoRow('Emplacement', productLocation(_p)),
        AdminImageField(
          label: 'Photo du produit',
          value: _image,
          height: 170.0,
          allowRemove: true,
          onChanged: (v) => setState(() => _image = v),
        ),
        TextField(
          controller: _name,
          maxLength: 120,
          decoration: salesInput('Nom du produit'),
        ),
        AdminFieldRow(children: [
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: salesInput('Prix de vente (FCFA)'),
          ),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            decoration: salesInput('Stock', helper: '0 = en rupture'),
          ),
        ]),
        AdminFieldRow(children: [
          TextField(
            controller: _section,
            maxLength: 60,
            decoration: salesInput('Rayon', hint: 'Ex. Boissons, Plats'),
          ),
          TextField(
            controller: _unit,
            maxLength: 30,
            decoration: salesInput('Unité de vente', hint: 'Ex. kg, boîte'),
          ),
        ]),
        DropdownButtonFormField<String>(
          initialValue: _tag,
          decoration: salesInput('Mise en avant'),
          items: [
            for (final t in kProductTags)
              DropdownMenuItem(value: t, child: Text(t.isEmpty ? 'Aucune' : t)),
          ],
          onChanged: (v) => setState(() => _tag = v ?? ''),
        ),
        TextField(
          controller: _description,
          maxLines: 3,
          maxLength: 2000,
          decoration: salesInput('Description'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: kSalesRed,
          value: _published,
          onChanged: (v) => setState(() => _published = v),
          title: const Text('Publié'),
          subtitle: const Text(
              'Visible des clients. Désactivé : brouillon, masqué de l\'application.'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: kSalesRed,
          value: _express,
          onChanged: (v) => setState(() => _express = v),
          title: const Text('Livraison express'),
          subtitle: const Text('Affiche le badge ⚡ Express sur le produit.'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: kSalesRed,
          value: _prescription,
          onChanged: (v) => setState(() => _prescription = v),
          title: const Text('Ordonnance obligatoire (pharmacie)'),
        ),
        if (_error != null) Text(_error!, style: salesBody(color: kSalesRed)),
      ],
    );
  }
}
