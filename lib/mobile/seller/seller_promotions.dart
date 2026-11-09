import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/backend/kitunga_banners.dart';
import '/backend/server_payment.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/upload_data.dart';
import '/mobile/components/form_styles/form_styles.dart';

/// Publicités et promotions d'un vendeur (carrousel d'accueil) : il les crée
/// lui-même pour sa vitrine ou un de ses produits ; Kitunga les valide avant
/// diffusion (fonctions kitungaSellerBanners, kitungaSaveSellerBanner…).

/// Tests : remplace le serveur.
Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data)?
    sellerPromoBackendOverride;

/// Tests : remplace le choix et l'envoi d'une photo.
Future<String?> Function()? sellerPromoPhotoOverride;

/// Tests : remplace la liste des produits du vendeur.
Stream<List<ProductRecord>>? sellerPromoProductsOverride;

Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) =>
    sellerPromoBackendOverride != null
        ? sellerPromoBackendOverride!(name, data)
        : kitungaCallFunction(name, data);

const _status = {
  'pending': (label: 'En attente de validation', color: Color(0xFF7C4DFF)),
  'rejected': (label: 'Refusée', color: Color(0xFFD32F2F)),
  'live': (label: 'Diffusée', color: Color(0xFF1E9E5A)),
  'scheduled': (label: 'Programmée', color: Color(0xFF1565C0)),
  'expired': (label: 'Terminée', color: Color(0xFFEF6C00)),
  'off': (label: 'En pause', color: Color(0xFF6F737C)),
};

Color _hex(Object? v, Color fallback) {
  final h = '${v ?? ''}'.replaceFirst('#', '');
  final n = int.tryParse(h, radix: 16);
  return h.length == 6 && n != null ? Color(0xFF000000 | n) : fallback;
}

String _hexOf(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

KitungaBanner _bannerOf(Map<String, dynamic> m) => (
      id: '${m['id'] ?? ''}',
      kind: 'seller',
      title1: '${m['title1'] ?? ''}',
      title2: '${m['title2'] ?? ''}',
      subtitle: '${m['subtitle'] ?? ''}',
      button: '${m['button'] ?? ''}'.isEmpty ? 'Voir' : '${m['button']}',
      badge: '${m['badge'] ?? ''}',
      image: '${m['image'] ?? ''}',
      color: _hex(m['color'], const Color(0xFFE51A1A)),
      accent: _hex(m['accent'], const Color(0xFFFFD200)),
      targetType: 'none',
      targetValue: '',
    );

String _day(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  return d == null ? '' : dateTimeFormat('d MMM y', d);
}

class SellerPromotionsPage extends StatefulWidget {
  const SellerPromotionsPage({super.key, required this.shop});

  final UserRecord shop;

  @override
  State<SellerPromotionsPage> createState() => _SellerPromotionsPageState();
}

class _SellerPromotionsPageState extends State<SellerPromotionsPage> {
  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() => _call('kitungaSellerBanners', {});

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _edit([Map<String, dynamic>? banner]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => SellerPromotionForm(shop: widget.shop, banner: banner)));
    if (saved == true) _reload();
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
      _reload();
    } on ServerPaymentException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Connexion impossible. Réessayez.')));
    }
  }

  Future<void> _delete(Map<String, dynamic> b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer cette publicité ?'),
        content: const Text('Elle ne sera plus affichée aux clients.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => _call('kitungaDeleteSellerBanner', {'id': b['id']}),
        'Publicité supprimée');
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final body = GoogleFonts.inter(color: theme.secondaryText, fontSize: 13.5);
    return Scaffold(
      backgroundColor: theme.secondaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0.0,
        iconTheme: IconThemeData(color: theme.primaryText),
        title: Text('Mes publicités',
            style: GoogleFonts.interTight(
                color: theme.primaryText,
                fontSize: 19.0,
                fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(
                child: CircularProgressIndicator(color: theme.primary));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${snap.error}',
                        textAlign: TextAlign.center, style: body),
                    TextButton(
                        onPressed: _reload, child: const Text('Réessayer')),
                  ],
                ),
              ),
            );
          }
          final list = [
            for (final b in (snap.data!['banners'] as List? ?? const []))
              Map<String, dynamic>.from(b as Map),
          ];
          final max = (snap.data!['max'] as num?)?.toInt() ?? 3;
          final running = list
              .where((b) => !['expired', 'rejected'].contains(b['status']))
              .length;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 32.0),
              children: [
                Text(
                    'Mettez en avant vos promotions et nouveautés dans le '
                    'carrousel d\'accueil de Kitunga. Chaque publicité est '
                    'vérifiée par l\'équipe Kitunga avant d\'être diffusée '
                    '($max en même temps au plus).',
                    style: body),
                const SizedBox(height: 14.0),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.primary,
                    minimumSize: const Size.fromHeight(48.0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0)),
                  ),
                  onPressed: running >= max ? null : () => _edit(),
                  icon: const Icon(Icons.campaign_rounded),
                  label: Text(running >= max
                      ? '$max publicités en cours au plus'
                      : 'Nouvelle publicité'),
                ),
                const SizedBox(height: 18.0),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30.0),
                    child: Column(
                      children: [
                        Icon(Icons.campaign_outlined,
                            size: 48.0, color: theme.secondaryText),
                        const SizedBox(height: 8.0),
                        Text('Aucune publicité pour le moment.',
                            style: body),
                      ],
                    ),
                  ),
                for (final b in list) ...[
                  _card(theme, b),
                  const SizedBox(height: 16.0),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card(FlutterFlowTheme theme, Map<String, dynamic> b) {
    final st = _status[b['status']] ?? _status['off']!;
    final approved = !['pending', 'rejected'].contains(b['status']);
    final paused = b['active'] == false;
    final clicks = (b['clicks'] as num?)?.toInt() ?? 0;
    final period = [
      if (b['startsAt'] != null) 'du ${_day(b['startsAt'])}',
      if (b['endsAt'] != null) 'au ${_day(b['endsAt'])}',
    ].join(' ');
    final small = GoogleFonts.inter(color: theme.secondaryText, fontSize: 13.0);
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.primaryBackground,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KitungaBannerView(_bannerOf(b), dim: b['status'] != 'live'),
          const SizedBox(height: 10.0),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: st.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Text(st.label,
                style: GoogleFonts.inter(
                    color: st.color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ),
          if (b['status'] == 'rejected' && '${b['reviewNote']}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text('Motif : ${b['reviewNote']} — modifiez-la puis '
                  'renvoyez-la.',
                  style: small.copyWith(color: const Color(0xFFD32F2F))),
            ),
          const SizedBox(height: 6.0),
          Text(
              '${period.isEmpty ? 'Sans limite de durée' : 'Diffusion $period'}'
              ' · $clicks clic${clicks > 1 ? 's' : ''}',
              style: small),
          const SizedBox(height: 6.0),
          Wrap(
            spacing: 4.0,
            children: [
              TextButton.icon(
                onPressed: () => _edit(b),
                icon: const Icon(Icons.edit_rounded, size: 18.0),
                label: const Text('Modifier'),
              ),
              if (approved && b['status'] != 'expired')
                TextButton.icon(
                  onPressed: () => _run(
                      () => _call('kitungaSetSellerBannerActive',
                          {'id': b['id'], 'active': paused}),
                      paused ? 'Publicité reprise' : 'Publicité en pause'),
                  icon: Icon(
                      paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 18.0),
                  label: Text(paused ? 'Reprendre' : 'Pause'),
                ),
              TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD32F2F)),
                onPressed: () => _delete(b),
                icon: const Icon(Icons.delete_outline_rounded, size: 18.0),
                label: const Text('Supprimer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _colors = [
  Color(0xFFE51A1A), Color(0xFFC2185B), Color(0xFF6A1B9A), Color(0xFF1565C0),
  Color(0xFF00796B), Color(0xFF2E7D32), Color(0xFFEF6C00), Color(0xFF4E342E),
];
const _badges = ['PROMO', '-10 %', '-20 %', '-30 %', 'NOUVEAU', '2 = 1'];

/// Création ou modification d'une publicité par le vendeur.
class SellerPromotionForm extends StatefulWidget {
  const SellerPromotionForm({super.key, required this.shop, this.banner});

  final UserRecord shop;
  final Map<String, dynamic>? banner;

  @override
  State<SellerPromotionForm> createState() => _SellerPromotionFormState();
}

class _SellerPromotionFormState extends State<SellerPromotionForm> {
  late final Map<String, dynamic> _b = widget.banner ?? const {};
  late final Map _t = _b['target'] is Map ? _b['target'] as Map : const {};
  late final _title1 =
      TextEditingController(text: _b['title1'] ?? widget.shop.displayName);
  late final _title2 = TextEditingController(text: _b['title2'] ?? '');
  late final _subtitle = TextEditingController(text: _b['subtitle'] ?? '');
  late final _badge = TextEditingController(text: _b['badge'] ?? '');
  late final _button = TextEditingController(text: _b['button'] ?? 'Voir');
  late String? _product = _t['type'] == 'product' ? '${_t['value']}' : null;
  late String _image = _b['image'] ?? '';
  late Color _color = _hex(_b['color'], _colors.first);
  late DateTime? _start = DateTime.tryParse(_b['startsAt'] ?? '')?.toLocal();
  late DateTime? _end = DateTime.tryParse(_b['endsAt'] ?? '')?.toLocal();
  late final Stream<List<ProductRecord>> _products =
      sellerPromoProductsOverride ?? queryProductRecord(
      queryBuilder: (q) =>
          q.where('seller_ref', isEqualTo: widget.shop.reference));
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_title1, _title2, _subtitle, _badge, _button]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_title1, _title2, _subtitle, _badge, _button]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (sellerPromoPhotoOverride != null) {
      final url = await sellerPromoPhotoOverride!();
      if (url != null) setState(() => _image = url);
      return;
    }
    final media = await selectMediaWithSourceBottomSheet(
      context: context,
      maxWidth: 1400.0,
      maxHeight: 1400.0,
      imageQuality: 85,
      allowPhoto: true,
    );
    if (media == null ||
        media.isEmpty ||
        !mounted ||
        !validateFileFormat(media.first.storagePath, context)) {
      return;
    }
    setState(() => _busy = true);
    try {
      final url = await uploadData(media.first.storagePath, media.first.bytes);
      if (url != null) setState(() => _image = url);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDay(bool start) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('fr'),
    );
    if (d != null) setState(() => start ? _start = d : _end = d);
  }

  Future<void> _send(List<ProductRecord> products) async {
    if (_title1.text.trim().isEmpty && _title2.text.trim().isEmpty) {
      return setState(() => _error = 'Indiquez le titre de la publicité.');
    }
    final chosen = products.where((p) => p.reference.id == _product);
    final productImage = chosen.isEmpty ? '' : chosen.first.prodImg;
    if (_image.isEmpty &&
        productImage.isEmpty &&
        widget.shop.businessCover.isEmpty &&
        widget.shop.photoUrl.isEmpty) {
      return setState(() => _error = 'Ajoutez une photo.');
    }
    if (_start != null && _end != null && !_end!.isAfter(_start!)) {
      return setState(
          () => _error = 'La date de fin doit être après la date de début.');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _call('kitungaSaveSellerBanner', {
        if (_b['id'] != null) 'id': _b['id'],
        'title1': _title1.text.trim(),
        'title2': _title2.text.trim(),
        'subtitle': _subtitle.text.trim(),
        'badge': _badge.text.trim(),
        'button': _button.text.trim(),
        'image': _image,
        'color': _hexOf(_color),
        'accent': '#FFD200',
        'target': _product == null
            ? {'type': 'shop'}
            : {'type': 'product', 'value': _product},
        'startsAt': _start == null
            ? null
            : DateTime(_start!.year, _start!.month, _start!.day)
                .toUtc()
                .toIso8601String(),
        'endsAt': _end == null
            ? null
            : DateTime(_end!.year, _end!.month, _end!.day, 23, 59)
                .toUtc()
                .toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Publicité envoyée : Kitunga la vérifie avant '
              'de la diffuser.')));
      Navigator.pop(context, true);
    } on ServerPaymentException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Connexion impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final field = GoogleFonts.inter(color: theme.primaryText, fontSize: 15.0);
    return Scaffold(
      backgroundColor: theme.secondaryBackground,
      appBar: AppBar(
        backgroundColor: theme.secondaryBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0.0,
        iconTheme: IconThemeData(color: theme.primaryText),
        title: Text(
            _b['id'] == null ? 'Nouvelle publicité' : 'Modifier la publicité',
            style: GoogleFonts.interTight(
                color: theme.primaryText,
                fontSize: 19.0,
                fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<List<ProductRecord>>(
        stream: _products,
        builder: (context, snap) {
          final products = snap.data ?? const <ProductRecord>[];
          final chosen = products.where((p) => p.reference.id == _product);
          final preview = _bannerOf({
            'title1': _title1.text.trim(),
            'title2': _title2.text.trim(),
            'subtitle': _subtitle.text.trim(),
            'badge': _badge.text.trim(),
            'button': _button.text.trim(),
            'image': _image.isNotEmpty
                ? _image
                : chosen.isNotEmpty && chosen.first.prodImg.isNotEmpty
                    ? chosen.first.prodImg
                    : widget.shop.businessCover.isNotEmpty
                        ? widget.shop.businessCover
                        : widget.shop.photoUrl,
            'color': _hexOf(_color),
            'accent': '#FFD200',
          });
          return ListView(
            padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 40.0),
            children: [
              Text('Aperçu sur l\'accueil des clients',
                  style: GoogleFonts.inter(
                      color: theme.secondaryText, fontSize: 13.0)),
              const SizedBox(height: 8.0),
              KitungaBannerView(preview),
              const SizedBox(height: 18.0),
              const KitungaFieldLabel('Ce que vous mettez en avant'),
              DropdownButtonFormField<String>(
                // '' = la boutique elle-même.
                initialValue: products.any((p) => p.reference.id == _product)
                    ? _product
                    : '',
                key: ValueKey('p-${products.length}'),
                isExpanded: true,
                decoration: kitungaInputDecoration(
                    context, 'Ma boutique', Icons.storefront_rounded),
                items: [
                  const DropdownMenuItem<String>(
                      value: '', child: Text('Ma boutique (vitrine)')),
                  for (final p in products.where((p) => p.onSale))
                    DropdownMenuItem<String>(
                        value: p.reference.id,
                        child: Text(p.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(
                    () => _product = (v == null || v.isEmpty) ? null : v),
              ),
              const SizedBox(height: 14.0),
              const KitungaFieldLabel('Photo'),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _pickPhoto,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(_image.isEmpty
                          ? 'Choisir une photo'
                          : 'Changer la photo'),
                    ),
                  ),
                  if (_image.isNotEmpty) ...[
                    const SizedBox(width: 8.0),
                    TextButton(
                      onPressed: () => setState(() => _image = ''),
                      child: const Text('Retirer'),
                    ),
                  ],
                ],
              ),
              Text(
                  'Sans photo choisie : celle du produit, sinon la couverture '
                  'de votre boutique.',
                  style: GoogleFonts.inter(
                      color: theme.secondaryText, fontSize: 12.0)),
              const SizedBox(height: 14.0),
              const KitungaFieldLabel('Titre'),
              TextField(
                controller: _title1,
                maxLength: 30,
                style: field,
                decoration: kitungaInputDecoration(
                    context, 'Ex. Le Crisp\'nCroc', Icons.title_rounded),
              ),
              const KitungaFieldLabel('Titre mis en avant'),
              TextField(
                controller: _title2,
                maxLength: 24,
                style: field,
                decoration: kitungaInputDecoration(
                    context, 'Ex. -20 % ce week-end', Icons.local_offer_outlined),
              ),
              const KitungaFieldLabel('Texte'),
              TextField(
                controller: _subtitle,
                maxLength: 90,
                maxLines: 2,
                style: field,
                decoration: kitungaInputDecoration(context,
                    'Ex. Sur tous les couscous jusqu\'à dimanche', Icons.notes),
              ),
              const KitungaFieldLabel('Pastille'),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  for (final t in _badges)
                    ChoiceChip(
                      label: Text(t),
                      selected: _badge.text == t,
                      onSelected: (on) => _badge.text = on ? t : '',
                    ),
                ],
              ),
              const SizedBox(height: 14.0),
              const KitungaFieldLabel('Couleur'),
              Wrap(
                spacing: 10.0,
                runSpacing: 10.0,
                children: [
                  for (final c in _colors)
                    GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 34.0,
                        height: 34.0,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _color == c
                                  ? theme.primaryText
                                  : Colors.transparent,
                              width: 3.0),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14.0),
              const KitungaFieldLabel('Période (facultative)'),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickDay(true),
                    icon: const Icon(Icons.event_rounded, size: 18.0),
                    label: Text(_start == null
                        ? 'Début'
                        : 'Du ${dateTimeFormat('d MMM y', _start)}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDay(false),
                    icon: const Icon(Icons.event_busy_rounded, size: 18.0),
                    label: Text(_end == null
                        ? 'Fin'
                        : 'Au ${dateTimeFormat('d MMM y', _end)}'),
                  ),
                  if (_start != null || _end != null)
                    TextButton(
                      onPressed: () => setState(() {
                        _start = null;
                        _end = null;
                      }),
                      child: const Text('Sans limite'),
                    ),
                ],
              ),
              const SizedBox(height: 10.0),
              const KitungaFieldLabel('Texte du bouton'),
              TextField(
                controller: _button,
                maxLength: 20,
                style: field,
                decoration: kitungaInputDecoration(
                    context, 'Voir', Icons.smart_button_outlined),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(_error!,
                      style: GoogleFonts.inter(
                          color: theme.error, fontWeight: FontWeight.w600)),
                ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primary,
                  minimumSize: const Size.fromHeight(50.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.0)),
                ),
                onPressed: _busy ? null : () => _send(products),
                icon: _busy
                    ? const SizedBox(
                        width: 18.0,
                        height: 18.0,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.0, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: const Text('Envoyer pour validation'),
              ),
              const SizedBox(height: 8.0),
              Text(
                  'Kitunga vérifie chaque publicité (photo, texte, prix) avant '
                  'de la diffuser. Vous serez fixé dans « Mes publicités ».',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: theme.secondaryText, fontSize: 12.0)),
            ],
          );
        },
      ),
    );
  }
}
