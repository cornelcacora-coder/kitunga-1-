import 'dart:async';

import 'package:flutter/material.dart';

import '/noc/sales/sales_common.dart';
import 'admin_categories_widget.dart' show loadAdminCategories;
import 'admin_shell.dart';

/// Produits (adresse /produits) : tous les produits, avec leur emplacement
/// (catégorie › commerce › rayon). Voir, ajouter, modifier, supprimer.
/// [sellerUid] (paramètre « commerce ») limite la liste à un commerce.
class AdminProductsWidget extends StatefulWidget {
  const AdminProductsWidget({super.key, this.sellerUid});

  static String routeName = 'AdminProducts';
  static String routePath = AdminPaths.products;

  final String? sellerUid;

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
  bool _missingImage = false;
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

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 12.0),
      child: Wrap(
        spacing: 10.0,
        runSpacing: 10.0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AdminSearchField(
            hint: 'Produit, commerce ou rayon',
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () {
                _q = v.trim();
                _reload();
              });
            },
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _categories,
            builder: (context, snap) => _Filter(
              label: 'Catégorie',
              value: _category,
              items: {
                for (final c in snap.data ?? const <Map<String, dynamic>>[])
                  c['name'] as String: c['name'] as String,
              },
              onChanged: (v) {
                _category = v;
                _reload();
              },
            ),
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _sellers,
            builder: (context, snap) => _Filter(
              label: 'Commerce',
              value: _sellerUid,
              items: {
                for (final s in snap.data ?? const <Map<String, dynamic>>[])
                  s['uid'] as String: (s['displayName'] as String?)?.isNotEmpty ==
                          true
                      ? s['displayName'] as String
                      : s['email'] as String? ?? s['uid'] as String,
              },
              onChanged: (v) {
                _sellerUid = v;
                _reload();
              },
            ),
          ),
          FilterChip(
            label: const Text('Sans image'),
            selected: _missingImage,
            selectedColor: kSalesRed.withValues(alpha: 0.15),
            checkmarkColor: kSalesRed,
            onSelected: (v) {
              _missingImage = v;
              _reload();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      current: 'products',
      title: 'Produits',
      subtitle: 'Tous les produits des commerces, avec leur emplacement',
      actions: [
        IconButton(
            tooltip: 'Actualiser',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded)),
        adminAddButton('Nouveau produit', () => _edit()),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _filters(),
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
                final list = listOf(snap.data!['products']);
                if (list.isEmpty) {
                  return const SalesEmpty(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Aucun produit',
                      text: 'Aucun produit ne correspond à ces filtres.');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 40.0),
                  itemCount: list.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 8.0),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Text(
                          '${list.length} produit${list.length > 1 ? 's' : ''}'
                          '${list.length >= 300 ? ' (affinez la recherche pour voir les autres)' : ''}',
                          style: salesBody());
                    }
                    final p = list[i - 1];
                    return _ProductRow(
                      product: p,
                      onView: () => _view(p),
                      onEdit: () => _edit(p),
                      onDelete: () => _delete(p),
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

/// Liste déroulante de filtre (« Tous » = aucun filtre).
class _Filter extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220.0,
      child: DropdownButtonFormField<String?>(
        key: ValueKey('$label-${items.length}-$value'),
        initialValue: items.containsKey(value) ? value : null,
        isExpanded: true,
        decoration: salesInput(label)
            .copyWith(isDense: true, fillColor: Colors.white),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text('Tous')),
          for (final e in items.entries)
            DropdownMenuItem<String?>(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> product;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final published = p['published'] != false;
    final qty = p['quantity'];
    return SalesCard(
      onTap: onView,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10.0),
            child: AdminImage(p['prodImg'] ?? '', width: 60.0, height: 60.0),
          ),
          const SizedBox(width: 14.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['name'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: salesTitle(15.0)),
                const SizedBox(height: 2.0),
                Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 14.0, color: kSalesMuted),
                    const SizedBox(width: 4.0),
                    Expanded(
                      child: Text(productLocation(p),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: salesBody(size: 12.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(fcfa(p['price']), style: salesTitle(14.0)),
                    if (qty != null)
                      Text('Stock : $qty',
                          style: salesBody(
                              size: 12.0,
                              color: qty == 0 ? kSalesRed : kSalesMuted)),
                    StatusChip(published
                        ? (label: 'Publié', color: const Color(0xFF1E9E5A))
                        : (label: 'Brouillon', color: kSalesMuted)),
                    if (p['express'] == true)
                      const StatusChip(
                          (label: '⚡ Express', color: Color(0xFFE08A00))),
                    if ((p['tag'] ?? '').isNotEmpty)
                      StatusChip(
                          (label: p['tag'], color: const Color(0xFF2F6FDB))),
                  ],
                ),
              ],
            ),
          ),
          AdminRowActions(actions: [
            viewAction(onView),
            editAction(onEdit),
            deleteAction(onDelete),
          ]),
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
