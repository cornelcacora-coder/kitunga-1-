import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_util.dart';
import '/noc/sales/sales_common.dart';
import 'admin_shell.dart';

/// Catégories de commerces (adresse /categories) : celles affichées dans
/// l'application. Voir, ajouter, modifier (nom, image, couleur, ordre,
/// visibilité) et supprimer (les commerces passent dans une autre catégorie).
class AdminCategoriesWidget extends StatefulWidget {
  const AdminCategoriesWidget({super.key});

  static String routeName = 'AdminCategories';
  static String routePath = AdminPaths.categories;

  @override
  State<AdminCategoriesWidget> createState() => _AdminCategoriesWidgetState();
}

Future<List<Map<String, dynamic>>> loadAdminCategories() async =>
    listOf((await salesCall('kitungaCatalogQuery', {'view': 'categories'}))[
        'categories']);

Color hexColor(String? hex, [Color fallback = const Color(0xFFF2F2F5)]) {
  final v = (hex ?? '').replaceFirst('#', '');
  final n = int.tryParse(v, radix: 16);
  return v.length == 6 && n != null ? Color(0xFF000000 | n) : fallback;
}

class _AdminCategoriesWidgetState extends State<AdminCategoriesWidget> {
  late Future<List<Map<String, dynamic>>> _future = loadAdminCategories();

  void _reload() {
    setState(() {
      _future = loadAdminCategories();
    });
  }

  Future<void> _edit([Map<String, dynamic>? category, int nextOrder = 0]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CategoryForm(category: category, nextOrder: nextOrder),
    );
    if (saved == true) _reload();
  }

  void _view(Map<String, dynamic> c) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(c['name'] ?? ''),
        content: SizedBox(
          width: 380.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14.0),
                child: Container(
                  height: 160.0,
                  color: hexColor(c['color']),
                  padding: const EdgeInsets.all(16.0),
                  child: AdminImage(c['image'] ?? '', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 12.0),
              AdminInfoRow('Commerces', '${c['sellers'] ?? 0}'),
              AdminInfoRow('Ordre d\'affichage', '${(c['order'] ?? 0) + 1}'),
              AdminInfoRow('Dans l\'application',
                  c['active'] == false ? 'Masquée' : 'Visible'),
              AdminInfoRow('Couleur de fond', '${c['color'] ?? ''}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(Uri(
                  path: AdminPaths.sellers,
                  queryParameters: {'categorie': c['name']}).toString());
            },
            child: const Text('Voir les commerces'),
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

  Future<void> _delete(
      Map<String, dynamic> c, List<Map<String, dynamic>> all) async {
    final used = (c['sellers'] as num? ?? 0).toInt();
    String? reassignTo;
    if (used > 0) {
      final others = all.where((o) => o['id'] != c['id']).toList();
      reassignTo = await showDialog<String>(
        context: context,
        builder: (_) => _ReassignDialog(category: c, others: others),
      );
      if (reassignTo == null) return;
    } else {
      final ok = await adminConfirm(context,
          title: 'Supprimer « ${c['name']} » ?',
          message: 'Aucun commerce n\'utilise cette catégorie. Elle ne sera '
              'plus proposée dans l\'application.');
      if (!ok) return;
    }
    if (!mounted) return;
    final done = await runSalesAction(
        context,
        () => salesCall('kitungaDeleteCategory',
            {'id': c['id'], if (reassignTo != null) 'reassignTo': reassignTo}),
        'Catégorie supprimée');
    if (done) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        final list = snap.data ?? const <Map<String, dynamic>>[];
        return AdminShell(
          current: 'categories',
          title: 'Catégories',
          subtitle: 'Types de commerce proposés aux clients dans l\'application',
          actions: [
            OutlinedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded, size: 18.0),
                label: const Text('Actualiser')),
            adminAddButton('Nouvelle catégorie',
                () => _edit(null, list.length)),
          ],
          body: Builder(builder: (context) {
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
            if (list.isEmpty) {
              return const SalesEmpty(
                  icon: Icons.category_outlined,
                  title: 'Aucune catégorie',
                  text: 'Ajoutez la première avec « Nouvelle catégorie ».');
            }
            return GridView.builder(
              padding: EdgeInsets.fromLTRB(
                  MediaQuery.sizeOf(context).width >= AdminShell.wideBreakpoint
                      ? 28.0
                      : 16.0,
                  4.0,
                  MediaQuery.sizeOf(context).width >= AdminShell.wideBreakpoint
                      ? 28.0
                      : 16.0,
                  40.0),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280.0,
                mainAxisExtent: 296.0,
                crossAxisSpacing: 14.0,
                mainAxisSpacing: 14.0,
              ),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final c = list[i];
                return _CategoryCard(
                  category: c,
                  onView: () => _view(c),
                  onEdit: () => _edit(c),
                  onDelete: () => _delete(c, list),
                );
              },
            );
          }),
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> category;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = category;
    final sellers = (c['sellers'] as num? ?? 0).toInt();
    final hidden = c['active'] == false;
    return SalesCard(
      onTap: onView,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: Container(
              height: 130.0,
              color: hexColor(c['color']),
              padding: const EdgeInsets.all(12.0),
              child: Opacity(
                opacity: hidden ? 0.4 : 1.0,
                child: AdminImage(c['image'] ?? '', fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 10.0),
          Row(
            children: [
              Expanded(
                child: Text(c['name'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: salesTitle(16.0)),
              ),
              AdminRowActions(actions: [
                viewAction(onView),
                editAction(onEdit),
                deleteAction(onDelete),
              ]),
            ],
          ),
          Text('$sellers commerce${sellers > 1 ? 's' : ''}',
              style: salesBody()),
          const Spacer(),
          Align(
            alignment: Alignment.centerLeft,
            child: hidden
                ? const AdminBadge('Masquée', tone: kToneGrey)
                : const AdminBadge('Visible', tone: kToneGreen),
          ),
        ],
      ),
    );
  }
}

/// Couleurs de fond proposées (celles des catégories d'origine et d'autres).
const kCategoryColors = [
  '#FFE4E1', '#FFEBD6', '#E2F5E9', '#E2EDFB', '#FFF3D1', //
  '#EDE4FB', '#DFF4F4', '#F2F2F5',
];

class _CategoryForm extends StatefulWidget {
  const _CategoryForm({this.category, required this.nextOrder});

  final Map<String, dynamic>? category;
  final int nextOrder;

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  late final Map<String, dynamic> _c = widget.category ?? const {};
  late final _name = TextEditingController(text: _c['name'] ?? '');
  late final _order = TextEditingController(
      text: '${((_c['order'] as num?)?.toInt() ?? widget.nextOrder) + 1}');
  late String _image = _c['image'] ?? '';
  late String _color = _c['color'] ?? kCategoryColors.first;
  late bool _active = _c['active'] != false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final order = parseInt(_order.text);
    if (name.isEmpty) return setState(() => _error = 'Indiquez le nom.');
    if (_image.isEmpty) return setState(() => _error = 'Ajoutez une image.');
    if (order == null || order < 1) {
      return setState(() => _error = 'Position : un nombre à partir de 1.');
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaSaveCategory', {
              if (_c['id'] != null) 'id': _c['id'],
              'name': name,
              'image': _image,
              'color': _color,
              'order': order - 1,
              'active': _active,
            }),
        _c['id'] == null ? 'Catégorie ajoutée' : 'Catégorie modifiée');
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
      icon: Icons.category_rounded,
      title: _c['id'] == null ? 'Nouvelle catégorie' : 'Modifier la catégorie',
      saving: _saving,
      onSave: _save,
      children: [
        AdminImageField(
          label: 'Image',
          value: _image,
          background: hexColor(_color),
          fit: BoxFit.contain,
          onChanged: (v) => setState(() => _image = v),
        ),
        AdminFieldRow(children: [
          TextField(
            controller: _name,
            maxLength: 40,
            decoration: salesInput('Nom', hint: 'Ex. Boulangerie',
                helper: _c['id'] != null
                    ? 'Les commerces de cette catégorie suivent le nouveau nom.'
                    : null),
          ),
          TextField(
            controller: _order,
            keyboardType: TextInputType.number,
            decoration: salesInput('Position', helper: '1 = affichée en premier'),
          ),
        ]),
        Text('Couleur de fond', style: salesBody(color: kSalesInk)),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            for (final hex in kCategoryColors)
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _color = hex),
                child: Container(
                  width: 34.0,
                  height: 34.0,
                  decoration: BoxDecoration(
                    color: hexColor(hex),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _color.toUpperCase() == hex
                            ? kSalesRed
                            : AdminColors.border,
                        width: _color.toUpperCase() == hex ? 2.5 : 1.0),
                  ),
                ),
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: kSalesRed,
          value: _active,
          onChanged: (v) => setState(() => _active = v),
          title: const Text('Visible dans l\'application'),
          subtitle: const Text(
              'Masquée : elle n\'apparaît plus sur l\'accueil des clients.'),
        ),
        if (_error != null)
          Text(_error!, style: salesBody(color: kSalesRed)),
      ],
    );
  }
}

/// Suppression d'une catégorie utilisée : choix de la catégorie d'accueil.
class _ReassignDialog extends StatefulWidget {
  const _ReassignDialog({required this.category, required this.others});

  final Map<String, dynamic> category;
  final List<Map<String, dynamic>> others;

  @override
  State<_ReassignDialog> createState() => _ReassignDialogState();
}

class _ReassignDialogState extends State<_ReassignDialog> {
  String? _target;

  @override
  Widget build(BuildContext context) {
    final n = (widget.category['sellers'] as num? ?? 0).toInt();
    return AlertDialog(
      title: Text('Supprimer « ${widget.category['name']} » ?'),
      content: SizedBox(
        width: 380.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
                '$n commerce${n > 1 ? 's utilisent' : ' utilise'} cette '
                'catégorie. Choisissez où ${n > 1 ? 'les' : 'le'} déplacer :',
                style: salesBody(color: kSalesInk)),
            const SizedBox(height: 14.0),
            DropdownButtonFormField<String>(
              initialValue: _target,
              decoration: salesInput('Nouvelle catégorie'),
              items: [
                for (final o in widget.others)
                  DropdownMenuItem(
                      value: o['id'] as String, child: Text(o['name'] ?? '')),
              ],
              onChanged: (v) => setState(() => _target = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kSalesRed),
          onPressed:
              _target == null ? null : () => Navigator.pop(context, _target),
          child: const Text('Déplacer et supprimer'),
        ),
      ],
    );
  }
}
