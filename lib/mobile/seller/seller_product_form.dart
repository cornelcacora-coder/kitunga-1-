import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/upload_data.dart';
import '/mobile/components/form_styles/form_styles.dart';
import '/mobile/components/kitunga_image/kitunga_image.dart';
import '/backend/kitunga_options.dart';
import '/backend/kitunga_cuisines.dart';
import 'seller_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Création ou modification d'un produit, avec les champs adaptés à
/// l'activité du commerce. [product] nul : création.
class SellerProductFormPage extends StatefulWidget {
  const SellerProductFormPage({
    super.key,
    required this.shop,
    this.product,
    this.existingSections = const [],
  });

  final UserRecord shop;
  final ProductRecord? product;

  /// Rubriques déjà utilisées par le vendeur (proposées en premier).
  final List<String> existingSections;

  @override
  State<SellerProductFormPage> createState() => _SellerProductFormPageState();
}

class _SellerProductFormPageState extends State<SellerProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  final _nameFocus = FocusNode();

  /// Cuisines du restaurant (suggestions de plats en premier).
  List<String> get _cuisines => [
        for (final c in (widget.shop.snapshotData['cuisines'] as List? ?? const []))
          '$c',
      ];
  late final _description =
      TextEditingController(text: widget.product?.description ?? '');
  late final _price = TextEditingController(
      text: widget.product == null
          ? ''
          : '${widget.product!.salePrice > 0 ? widget.product!.salePrice : widget.product!.price.round()}');
  late final _stock = TextEditingController(
      text: widget.product == null ? '' : '${widget.product!.quantity}');
  late final _section =
      TextEditingController(text: widget.product?.section ?? '');

  late String _photoUrl = widget.product?.prodImg ?? '';
  late String _unit = (widget.product?.unit.isNotEmpty ?? false)
      ? widget.product!.unit
      : 'pièce';
  late String _tag = widget.product?.specifications ?? '';
  late bool _express = widget.product?.instantDisponibilty ?? false;
  late bool _prescription = widget.product?.requiresPrescription ?? false;

  late List<KitungaOptionGroup> _groups =
      (widget.product?.options ?? []).map((g) => g.copy()).toList();

  bool _uploading = false;
  bool _saving = false;

  String get _category => widget.shop.category;
  bool get _editing => widget.product != null;

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    _description.dispose();
    _price.dispose();
    _stock.dispose();
    _section.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final media = await selectMediaWithSourceBottomSheet(
      context: context,
      maxWidth: 1200.0,
      maxHeight: 1200.0,
      imageQuality: 85,
      allowPhoto: true,
    );
    if (media == null ||
        media.isEmpty ||
        !validateFileFormat(media.first.storagePath, context)) {
      return;
    }
    setState(() => _uploading = true);
    try {
      final url = await uploadData(media.first.storagePath, media.first.bytes);
      if (url != null) setState(() => _photoUrl = url);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save({required bool publish}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // Restaurants : un plat peut être publié sans photo.
    if (publish && _photoUrl.isEmpty && !hasCuisines(_category)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ajoutez une photo avant de publier ce produit.')));
      return;
    }
    setState(() => _saving = true);
    final price = int.parse(_price.text.trim());
    final data = createProductRecordData(
      name: _name.text.trim(),
      description: _description.text.trim(),
      price: price.toDouble(),
      salePrice: price,
      quantity: int.parse(_stock.text.trim()),
      prodImg: _photoUrl,
      section: _section.text.trim(),
      unit: sellerUsesUnits(_category) ? _unit : null,
      requiresPrescription: _category == 'Pharmacie' ? _prescription : null,
      instantDisponibilty: _express,
      specifications: _tag,
      onSale: publish,
      modifiedAt: getCurrentTimestamp,
      optionsRaw: encodeOptionGroups(_groups),
    );
    try {
      if (_editing) {
        await widget.product!.reference.update(data);
      } else {
        await ProductRecord.collection.doc().set({
          ...data,
          ...createProductRecordData(
            sellerRef: currentUserReference,
            createdAt: getCurrentTimestamp,
          ),
        });
      }
      if (!mounted) return;
      // Récupéré avant de quitter la page (son contexte disparaît ensuite).
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
          content: Text(publish
              ? 'Produit publié : il est visible par les clients.'
              : 'Brouillon enregistré : il n\'est pas visible par les clients.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Enregistrement impossible. Réessayez.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Supprimer ce produit ?'),
        content: Text(
            'Il disparaîtra définitivement du catalogue. Pour le retirer temporairement, enregistrez-le plutôt en brouillon.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Supprimer',
                style: TextStyle(color: FlutterFlowTheme.of(context).error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.product!.reference.delete();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final item = sellerItemLabel(_category);
    final fieldStyle =
        GoogleFonts.inter(color: theme.primaryText, fontSize: 15.0);
    final suggestions = {
      ...widget.existingSections,
      ...sellerSectionSuggestions(_category),
    }.toList();

    return Scaffold(
      backgroundColor: theme.secondaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0.0,
        iconTheme: IconThemeData(color: theme.primaryText),
        title: Text(
          _editing ? 'Modifier le $item' : 'Nouveau $item',
          style: GoogleFonts.interTight(
            color: theme.primaryText,
            fontSize: 19.0,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Supprimer',
              onPressed: _saving ? null : _delete,
              icon: Icon(Icons.delete_outline_rounded, color: theme.error),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 32.0),
          children: [
            // Photo
            InkWell(
              borderRadius: BorderRadius.circular(18.0),
              onTap: _uploading ? null : _pickPhoto,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18.0),
                child: Container(
                  height: 190.0,
                  color: theme.primaryBackground,
                  alignment: Alignment.center,
                  child: _uploading
                      ? CircularProgressIndicator(color: theme.primary)
                      : _photoUrl.isEmpty
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_a_photo_outlined,
                                    size: 36.0, color: theme.secondaryText),
                                SizedBox(height: 8.0),
                                Text(
                                  'Ajouter une photo (obligatoire pour publier)',
                                  style: GoogleFonts.inter(
                                      color: theme.secondaryText,
                                      fontSize: 13.0),
                                ),
                              ],
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                KitungaImage(_photoUrl,
                                    width: double.infinity, height: 190.0),
                                Positioned(
                                  right: 10.0,
                                  bottom: 10.0,
                                  child: Container(
                                    padding: EdgeInsets.fromLTRB(
                                        10.0, 6.0, 10.0, 6.0),
                                    decoration: BoxDecoration(
                                      color: Color(0x99000000),
                                      borderRadius: BorderRadius.circular(20.0),
                                    ),
                                    child: Text(
                                      'Changer la photo',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
            ),
            SizedBox(height: 20.0),
            KitungaFieldLabel('Nom du $item'),
            // Restaurants : suggestions de plats (cuisines du commerce
            // d'abord) ; le plat choisi remplit aussi la rubrique.
            RawAutocomplete<KitungaDish>(
              textEditingController: _name,
              focusNode: _nameFocus,
              displayStringForOption: (d) => d.name,
              optionsBuilder: (v) => hasCuisines(_category)
                  ? dishSuggestions(v.text, cuisines: _cuisines)
                  : const <KitungaDish>[],
              onSelected: (d) {
                if (_section.text.trim().isEmpty) _section.text = d.section;
                setState(() {});
              },
              fieldViewBuilder: (context, controller, focus, onSubmit) =>
                  TextFormField(
                controller: controller,
                focusNode: focus,
                textCapitalization: TextCapitalization.sentences,
                style: fieldStyle,
                decoration: kitungaInputDecoration(
                    context, 'Ex : ${_example()}', Icons.label_outline_rounded),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Le nom est obligatoire.' : null,
              ),
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 6.0,
                  borderRadius: BorderRadius.circular(14.0),
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(maxHeight: 280.0, maxWidth: 360.0),
                    child: ListView(
                      padding: EdgeInsets.symmetric(vertical: 6.0),
                      shrinkWrap: true,
                      children: [
                        for (final d in options)
                          ListTile(
                            dense: true,
                            leading: Icon(Icons.restaurant_menu_rounded,
                                color: FlutterFlowTheme.of(context).primary),
                            title: Text(d.name),
                            subtitle: Text(d.section),
                            onTap: () => onSelected(d),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16.0),
            KitungaFieldLabel('Description'),
            TextFormField(
              controller: _description,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: fieldStyle,
              decoration: kitungaInputDecoration(
                  context,
                  _category == 'Restaurant' || _category == 'Fast Food'
                      ? 'Ingrédients, accompagnement, portion…'
                      : 'Caractéristiques, taille, marque…',
                  Icons.notes_rounded),
            ),
            SizedBox(height: 16.0),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KitungaFieldLabel('Prix (F CFA)'),
                      TextFormField(
                        controller: _price,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: fieldStyle,
                        decoration: kitungaInputDecoration(
                            context, '2500', Icons.payments_outlined),
                        validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0
                            ? 'Prix requis.'
                            : null,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KitungaFieldLabel('Stock disponible'),
                      TextFormField(
                        controller: _stock,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: fieldStyle,
                        decoration: kitungaInputDecoration(
                            context, '10', Icons.inventory_2_outlined),
                        validator: (v) => int.tryParse(v ?? '') == null
                            ? 'Stock requis.'
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (sellerUsesUnits(_category)) ...[
              SizedBox(height: 16.0),
              KitungaFieldLabel('Unité de vente'),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  for (final u in sellerUnits)
                    ChoiceChip(
                      label: Text(u),
                      selected: _unit == u,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _unit = u),
                      labelStyle: GoogleFonts.inter(
                        color: _unit == u ? Colors.white : theme.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                      selectedColor: theme.primary,
                      backgroundColor: theme.primaryBackground,
                      side: BorderSide.none,
                      shape: StadiumBorder(),
                    ),
                ],
              ),
            ],
            SizedBox(height: 16.0),
            KitungaFieldLabel(sellerSectionLabel(_category)),
            TextFormField(
              controller: _section,
              textCapitalization: TextCapitalization.sentences,
              style: fieldStyle,
              decoration: kitungaInputDecoration(
                  context, 'Choisissez ou saisissez', Icons.view_list_outlined),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: 8.0),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                for (final s in suggestions)
                  ActionChip(
                    label: Text(s),
                    onPressed: () => setState(() => _section.text = s),
                    labelStyle: GoogleFonts.inter(
                      color: _section.text.trim() == s
                          ? Colors.white
                          : theme.primaryText,
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: _section.text.trim() == s
                        ? theme.primary
                        : theme.primaryBackground,
                    side: BorderSide.none,
                    shape: StadiumBorder(),
                  ),
              ],
            ),
            SizedBox(height: 20.0),
            _optionsSection(theme),
            SizedBox(height: 16.0),
            KitungaFieldLabel('Mise en avant'),
            Wrap(
              spacing: 8.0,
              children: [
                for (final t in [
                  (label: 'Aucune', value: ''),
                  (label: 'Nouveauté', value: 'Nouveauté'),
                  (label: 'Tendance', value: 'Tendance'),
                ])
                  ChoiceChip(
                    label: Text(t.label),
                    selected: _tag == t.value,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _tag = t.value),
                    labelStyle: GoogleFonts.inter(
                      color: _tag == t.value ? Colors.white : theme.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                    selectedColor: theme.primary,
                    backgroundColor: theme.primaryBackground,
                    side: BorderSide.none,
                    shape: StadiumBorder(),
                  ),
              ],
            ),
            SizedBox(height: 8.0),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _express,
              activeThumbColor: theme.primary,
              onChanged: (v) => setState(() => _express = v),
              title: Text('Livraison express',
                  style: GoogleFonts.inter(
                      color: theme.primaryText, fontWeight: FontWeight.w600)),
              subtitle: Text('Affiche le badge ⚡ Express sur le produit.',
                  style: GoogleFonts.inter(
                      color: theme.secondaryText, fontSize: 12.0)),
            ),
            if (_category == 'Pharmacie')
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _prescription,
                activeThumbColor: theme.primary,
                onChanged: (v) => setState(() => _prescription = v),
                title: Text('Sur ordonnance',
                    style: GoogleFonts.inter(
                        color: theme.primaryText, fontWeight: FontWeight.w600)),
                subtitle: Text(
                    'Visible par les clients mais non commandable en ligne.',
                    style: GoogleFonts.inter(
                        color: theme.secondaryText, fontSize: 12.0)),
              ),
            SizedBox(height: 24.0),
            KitungaPrimaryButton(
              text: 'Publier',
              loading: _saving,
              onPressed: () => _save(publish: true),
            ),
            SizedBox(height: 10.0),
            SizedBox(
              height: 52.0,
              child: OutlinedButton(
                onPressed: _saving ? null : () => _save(publish: false),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.divider),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0)),
                ),
                child: Text(
                  'Enregistrer en brouillon',
                  style: GoogleFonts.interTight(
                    color: theme.primaryText,
                    fontSize: 15.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Options, suppléments, variantes ─────────────────────────────────
  String get _optionsTitle => switch (_category) {
        'Restaurant' => 'Options et suppléments',
        'Fast Food' => 'Composition et suppléments',
        'Boutique' => 'Variantes',
        'Magasin' => 'Conditionnements',
        'Pharmacie' => 'Formats',
        _ => 'Options',
      };

  bool get _tracksVariantStock => _category == 'Boutique';

  List<KitungaOptionGroup> get _presets => switch (_category) {
        'Restaurant' => [
            KitungaOptionGroup(
                name: 'Accompagnement',
                required: true,
                choices: [
                  for (final s in kCommonSides.take(8))
                    KitungaOptionChoice(label: s),
                ]),
            KitungaOptionGroup(name: 'Cuisson', required: true),
            KitungaOptionGroup(name: 'Suppléments', max: 0),
          ],
        'Fast Food' => [
            KitungaOptionGroup(name: 'Taille', required: true),
            KitungaOptionGroup(name: 'Boisson', required: true),
            KitungaOptionGroup(name: 'Sauce', max: 2),
            KitungaOptionGroup(name: 'Suppléments', max: 0),
          ],
        'Boutique' => [
            KitungaOptionGroup(name: 'Taille', required: true),
            KitungaOptionGroup(name: 'Couleur', required: true),
          ],
        'Magasin' => [
            KitungaOptionGroup(name: 'Conditionnement', required: true),
          ],
        _ => [KitungaOptionGroup(name: 'Format', required: true)],
      };

  Future<void> _editGroup({KitungaOptionGroup? group, int? index}) async {
    final result = await Navigator.of(context).push<KitungaOptionGroup>(
      MaterialPageRoute(
        builder: (_) => _OptionGroupEditor(
          group: group?.copy() ?? KitungaOptionGroup(name: ''),
          showStock: _tracksVariantStock,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        _groups.add(result);
      } else {
        _groups[index] = result;
      }
    });
  }

  Widget _optionsSection(FlutterFlowTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitungaFieldLabel(_optionsTitle),
        Text(
          'Le client fera ses choix avant d\'ajouter le produit au panier. Le prix final inclut les suppléments.',
          style: GoogleFonts.inter(
              color: theme.secondaryText, fontSize: 12.5, height: 1.4),
        ),
        SizedBox(height: 10.0),
        for (var i = 0; i < _groups.length; i++)
          Container(
            margin: EdgeInsets.only(bottom: 10.0),
            padding: EdgeInsets.fromLTRB(14.0, 10.0, 6.0, 10.0),
            decoration: BoxDecoration(
              color: theme.primaryBackground,
              borderRadius: BorderRadius.circular(14.0),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _groups[i].name,
                        style: GoogleFonts.interTight(
                          color: theme.primaryText,
                          fontSize: 15.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _groups[i].rule,
                        style: GoogleFonts.inter(
                            color: theme.primary, fontSize: 12.0),
                      ),
                      SizedBox(height: 2.0),
                      Text(
                        _groups[i]
                            .choices
                            .map((c) => [
                                  c.label,
                                  if (c.price > 0) '+${c.price} F',
                                  if (c.stock != null) 'stock ${c.stock}',
                                ].join(' '))
                            .join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            color: theme.secondaryText, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Modifier',
                  onPressed: () => _editGroup(group: _groups[i], index: i),
                  icon: Icon(Icons.edit_outlined, color: theme.secondaryText),
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  onPressed: () => setState(() => _groups.removeAt(i)),
                  icon: Icon(Icons.close_rounded, color: theme.error),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            for (final preset
                in _presets.where((p) => !_groups.any((g) => g.name == p.name)))
              ActionChip(
                avatar:
                    Icon(Icons.add_rounded, size: 16.0, color: theme.primary),
                label: Text(preset.name),
                onPressed: () => _editGroup(group: preset),
                labelStyle: GoogleFonts.inter(
                    color: theme.primaryText, fontWeight: FontWeight.w600),
                backgroundColor: theme.primaryBackground,
                side: BorderSide.none,
                shape: StadiumBorder(),
              ),
            ActionChip(
              avatar: Icon(Icons.add_rounded, size: 16.0, color: theme.primary),
              label: Text('Autre groupe'),
              onPressed: () => _editGroup(),
              labelStyle: GoogleFonts.inter(
                  color: theme.primaryText, fontWeight: FontWeight.w600),
              backgroundColor: theme.primaryBackground,
              side: BorderSide.none,
              shape: StadiumBorder(),
            ),
          ],
        ),
      ],
    );
  }

  String _example() => switch (_category) {
        'Restaurant' => 'Poulet braisé',
        'Fast Food' => 'Menu burger frites',
        'Pharmacie' => 'Paracétamol 500 mg',
        'Magasin' => 'Riz parfumé 5 kg',
        _ => 'Chemise en lin',
      };
}

/// Édition d'un groupe d'options : nom, règle et choix.
class _OptionGroupEditor extends StatefulWidget {
  const _OptionGroupEditor({required this.group, required this.showStock});

  final KitungaOptionGroup group;
  final bool showStock;

  @override
  State<_OptionGroupEditor> createState() => _OptionGroupEditorState();
}

class _OptionGroupEditorState extends State<_OptionGroupEditor> {
  late final _name = TextEditingController(text: widget.group.name);
  late bool _required = widget.group.required;
  late bool _multiple = !widget.group.single;
  late final _max = TextEditingController(
      text: widget.group.max > 1 ? '${widget.group.max}' : '');
  late final List<
      ({
        TextEditingController label,
        TextEditingController price,
        TextEditingController stock
      })> _choices = (widget.group.choices.isEmpty
          ? [KitungaOptionChoice(label: '')]
          : widget.group.choices)
      .map((c) => (
            label: TextEditingController(text: c.label),
            price: TextEditingController(text: c.price > 0 ? '${c.price}' : ''),
            stock: TextEditingController(
                text: c.stock == null ? '' : '${c.stock}'),
          ))
      .toList();

  @override
  void dispose() {
    _name.dispose();
    _max.dispose();
    for (final c in _choices) {
      c.label.dispose();
      c.price.dispose();
      c.stock.dispose();
    }
    super.dispose();
  }

  void _save() {
    final choices = _choices
        .where((c) => c.label.text.trim().isNotEmpty)
        .map((c) => KitungaOptionChoice(
              label: c.label.text.trim(),
              price: int.tryParse(c.price.text.trim()) ?? 0,
              stock:
                  widget.showStock ? int.tryParse(c.stock.text.trim()) : null,
            ))
        .toList();
    if (_name.text.trim().isEmpty || choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Donnez un nom au groupe et au moins un choix.')));
      return;
    }
    Navigator.of(context).pop(KitungaOptionGroup(
      name: _name.text.trim(),
      required: _required,
      max: _multiple ? (int.tryParse(_max.text.trim()) ?? 0) : 1,
      choices: choices,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final style = GoogleFonts.inter(color: theme.primaryText, fontSize: 15.0);
    return Scaffold(
      backgroundColor: theme.secondaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0.0,
        iconTheme: IconThemeData(color: theme.primaryText),
        title: Text(
          widget.group.name.isEmpty ? 'Nouveau groupe' : widget.group.name,
          style: GoogleFonts.interTight(
            color: theme.primaryText,
            fontSize: 19.0,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 32.0),
        children: [
          KitungaFieldLabel('Nom du groupe'),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            style: style,
            decoration: kitungaInputDecoration(
                context, 'Ex : Accompagnement', Icons.label_outline_rounded),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _required,
            activeThumbColor: theme.primary,
            onChanged: (v) => setState(() => _required = v),
            title: Text('Choix obligatoire', style: style),
            subtitle: Text('Le client doit choisir avant d\'ajouter au panier.',
                style: GoogleFonts.inter(
                    color: theme.secondaryText, fontSize: 12.0)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _multiple,
            activeThumbColor: theme.primary,
            onChanged: (v) => setState(() => _multiple = v),
            title: Text('Plusieurs choix possibles', style: style),
            subtitle: Text('Ex : plusieurs suppléments.',
                style: GoogleFonts.inter(
                    color: theme.secondaryText, fontSize: 12.0)),
          ),
          if (_multiple)
            TextField(
              controller: _max,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: style,
              decoration: kitungaInputDecoration(context,
                  'Nombre maximum (vide = sans limite)', Icons.tune_rounded),
            ),
          SizedBox(height: 20.0),
          KitungaFieldLabel('Choix proposés'),
          for (var i = 0; i < _choices.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: 10.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: TextField(
                      controller: _choices[i].label,
                      style: style,
                      decoration: kitungaInputDecoration(
                          context, 'Choix', Icons.circle_outlined),
                    ),
                  ),
                  SizedBox(width: 8.0),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _choices[i].price,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: style,
                      decoration: kitungaInputDecoration(
                          context, '+ F', Icons.add_rounded),
                    ),
                  ),
                  if (widget.showStock) ...[
                    SizedBox(width: 8.0),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _choices[i].stock,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: style,
                        decoration: kitungaInputDecoration(
                            context, 'Stock', Icons.inventory_2_outlined),
                      ),
                    ),
                  ],
                  IconButton(
                    tooltip: 'Retirer',
                    onPressed: _choices.length == 1
                        ? null
                        : () => setState(() => _choices.removeAt(i)),
                    icon: Icon(Icons.close_rounded, color: theme.error),
                  ),
                ],
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _choices.add((
                    label: TextEditingController(),
                    price: TextEditingController(),
                    stock: TextEditingController(),
                  ))),
              icon: Icon(Icons.add_rounded, color: theme.primary),
              label: Text('Ajouter un choix',
                  style: GoogleFonts.inter(
                      color: theme.primary, fontWeight: FontWeight.w700)),
            ),
          ),
          SizedBox(height: 20.0),
          KitungaPrimaryButton(text: 'Valider le groupe', onPressed: _save),
        ],
      ),
    );
  }
}
