import 'package:flutter/material.dart';

import '/backend/kitunga_banners.dart' show kBannerTextShadow;
import '/noc/sales/sales_common.dart';
import '/noc/ui/admin_export.dart';
import 'admin_categories_widget.dart' show hexColor, loadAdminCategories;
import 'admin_products_widget.dart' show loadAdminPartners;
import 'admin_shell.dart';

/// Publicités et promotions du carrousel d'accueil de l'application
/// (adresse /publicites) : promotions de Kitunga et publicités des commerces.
/// Voir, ajouter, modifier, activer / désactiver, réordonner, supprimer ;
/// période de diffusion et nombre de clics.
class AdminBannersWidget extends StatefulWidget {
  const AdminBannersWidget({super.key});

  static String routeName = 'AdminBanners';
  static String routePath = AdminPaths.banners;

  @override
  State<AdminBannersWidget> createState() => _AdminBannersWidgetState();
}

Future<List<Map<String, dynamic>>> loadAdminBanners() async =>
    listOf((await salesCall('kitungaListBanners', const {}))['banners']);

const _statusLabels = {
  'pending': 'À valider',
  'rejected': 'Refusée',
  'live': 'Diffusée',
  'scheduled': 'Programmée',
  'expired': 'Terminée',
  'off': 'Désactivée',
};

AdminTone _statusTone(String? s) => switch (s) {
      'live' => kToneGreen,
      'scheduled' => kToneBlue,
      'expired' => kToneOrange,
      'pending' => kToneViolet,
      'rejected' => kToneRed,
      _ => kToneGrey,
    };

const _targetLabels = {
  'shops': 'Liste des commerces',
  'category': 'Une catégorie',
  'shop': 'Le commerce',
  'product': 'Un produit',
  'url': 'Un lien web',
  'none': 'Aucune (bannière seule)',
};

String _targetText(Map<String, dynamic> b) {
  final t = b['target'] is Map ? b['target'] as Map : const {};
  final type = '${t['type'] ?? 'shops'}';
  final v = '${t['value'] ?? ''}';
  return switch (type) {
    'category' => 'Catégorie « $v »',
    'shop' => 'Vitrine${(b['sellerName'] ?? '') != '' ? ' de ${b['sellerName']}' : ' du commerce'}',
    'product' => 'Fiche d\'un produit',
    'url' => v,
    'none' => 'Aucune',
    _ => 'Liste des commerces',
  };
}

String _period(Map<String, dynamic> b) {
  final s = b['startsAt'] as String?;
  final e = b['endsAt'] as String?;
  if (s == null && e == null) return 'Sans limite de durée';
  if (s != null && e != null) return 'Du ${dateFr(s)} au ${dateFr(e)}';
  return s != null ? 'À partir du ${dateFr(s)}' : 'Jusqu\'au ${dateFr(e)}';
}

class _AdminBannersWidgetState extends State<AdminBannersWidget> {
  late Future<List<Map<String, dynamic>>> _future = loadAdminBanners();
  String _status = 'all';
  String _kind = 'all';

  void _reload() {
    setState(() {
      _future = loadAdminBanners();
    });
  }

  Future<void> _edit([Map<String, dynamic>? banner]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BannerForm(banner: banner),
    );
    if (saved == true) _reload();
  }

  Future<void> _toggle(Map<String, dynamic> b) async {
    final on = b['active'] == false;
    final ok = await runSalesAction(
        context,
        () => salesCall(
            'kitungaSetBannerActive', {'id': b['id'], 'active': on}),
        on ? 'Bannière activée' : 'Bannière désactivée');
    if (ok) _reload();
  }

  Future<void> _move(List<Map<String, dynamic>> all, int i, int by) async {
    final ids = [for (final b in all) b['id'] as String];
    final j = i + by;
    if (j < 0 || j >= ids.length) return;
    final tmp = ids[i];
    ids[i] = ids[j];
    ids[j] = tmp;
    final ok = await runSalesAction(context,
        () => salesCall('kitungaReorderBanners', {'ids': ids}), 'Ordre modifié');
    if (ok) _reload();
  }

  /// Publicité proposée par un vendeur : validation ou refus motivé.
  Future<void> _review(Map<String, dynamic> b, bool approve) async {
    String? note;
    if (!approve) {
      note = await askText(context, 'Refuser cette publicité ?',
          label: 'Motif (affiché au vendeur)',
          hint: 'Ex. Photo floue, prix à corriger…');
      if (note == null || !mounted) return;
    }
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaReviewBanner', {
              'id': b['id'],
              'decision': approve ? 'approve' : 'reject',
              if (note != null) 'note': note,
            }),
        approve ? 'Publicité validée' : 'Publicité refusée');
    if (ok) _reload();
  }

  Future<void> _delete(Map<String, dynamic> b) async {
    final ok = await adminConfirm(context,
        title: 'Supprimer cette bannière ?',
        message: '« ${b['title1']} ${b['title2']} » ne sera plus affichée '
            'dans l\'application. Pour l\'arrêter sans la perdre, '
            'désactivez-la plutôt.');
    if (!ok || !mounted) return;
    final done = await runSalesAction(context,
        () => salesCall('kitungaDeleteBanner', {'id': b['id']}),
        'Bannière supprimée');
    if (done) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        final all = snap.data ?? const <Map<String, dynamic>>[];
        final list = [
          for (final b in all)
            if ((_status == 'all' || b['status'] == _status) &&
                (_kind == 'all' || b['kind'] == _kind))
              b,
        ];
        final live = all.where((b) => b['status'] == 'live').length;
        final toReview = all.where((b) => b['status'] == 'pending').length;
        final clicks =
            all.fold<int>(0, (s, b) => s + ((b['clicks'] as num?) ?? 0).toInt());
        return AdminShell(
          current: 'banners',
          title: 'Publicités & promotions',
          subtitle: 'Bannières du carrousel d\'accueil de l\'application',
          actions: [
            OutlinedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded, size: 18.0),
                label: const Text('Actualiser')),
            AdminExportButton(
              data: () => !snap.hasData
                  ? null
                  : AdminExportData(
                      title: 'Publicités & promotions',
                      subtitle: '${all.length} bannière(s) · $live diffusée(s)'
                          ' · $clicks clic(s)',
                      fileName: 'publicites',
                      headers: [
                        'Ordre', 'Bannière', 'Type', 'État', 'Période',
                        'Destination', 'Clics',
                      ],
                      flex: [1, 4, 3, 2, 4, 4, 1],
                      rows: [
                        for (final b in all)
                          [
                            ((b['order'] as num?)?.toInt() ?? 0) + 1,
                            '${b['title1']} ${b['title2']}'.trim(),
                            b['kind'] == 'seller'
                                ? 'Publicité · ${b['sellerName']}'
                                : 'Promotion Kitunga',
                            _statusLabels[b['status']] ?? '',
                            _period(b),
                            _targetText(b),
                            b['clicks'] as num?,
                          ],
                      ],
                    ),
            ),
            adminAddButton('Nouvelle bannière', () => _edit()),
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
            final pad =
                MediaQuery.sizeOf(context).width >= AdminShell.wideBreakpoint
                    ? 28.0
                    : 16.0;
            return ListView(
              padding: EdgeInsets.fromLTRB(pad, 4.0, pad, 40.0),
              children: [
                Wrap(
                  spacing: 10.0,
                  runSpacing: 10.0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AdminSelect<String>(
                      value: _status,
                      icon: Icons.toggle_on_outlined,
                      items: const {
                        'all': 'Tous les états',
                        ..._statusLabels,
                      },
                      onChanged: (v) => setState(() => _status = v),
                    ),
                    AdminSelect<String>(
                      value: _kind,
                      icon: Icons.campaign_outlined,
                      items: const {
                        'all': 'Promotions et publicités',
                        'app': 'Promotions Kitunga',
                        'seller': 'Publicités des commerces',
                      },
                      onChanged: (v) => setState(() => _kind = v),
                    ),
                    if (toReview > 0)
                      ActionChip(
                        avatar: const Icon(Icons.pending_actions_rounded,
                            size: 18.0),
                        label: Text('$toReview à valider'),
                        onPressed: () => setState(() => _status = 'pending'),
                      ),
                    Text(
                        '$live diffusée${live > 1 ? 's' : ''} sur '
                        '${all.length} · $clicks clic${clicks > 1 ? 's' : ''}',
                        style: AdminText.label()),
                  ],
                ),
                const SizedBox(height: 16.0),
                if (list.isEmpty)
                  const SalesEmpty(
                      icon: Icons.campaign_outlined,
                      title: 'Aucune bannière',
                      text: 'Ajoutez-en une avec « Nouvelle bannière ».')
                else
                  LayoutBuilder(
                    builder: (context, box) => Wrap(
                    spacing: 16.0,
                    runSpacing: 16.0,
                    children: [
                      for (final b in list)
                        _BannerCard(
                          width: box.maxWidth < 412.0 ? box.maxWidth : 380.0,
                          banner: b,
                          canUp: all.indexOf(b) > 0,
                          canDown: all.indexOf(b) < all.length - 1,
                          onUp: () => _move(all, all.indexOf(b), -1),
                          onDown: () => _move(all, all.indexOf(b), 1),
                          onEdit: () => _edit(b),
                          onToggle: () => _toggle(b),
                          onDelete: () => _delete(b),
                          onApprove: () => _review(b, true),
                          onReject: () => _review(b, false),
                        ),
                    ],
                  ),
                  ),
              ],
            );
          }),
        );
      },
    );
  }
}

/// Aperçu fidèle de la bannière telle qu'elle apparaît dans l'application.
class BannerPreview extends StatelessWidget {
  const BannerPreview({
    super.key,
    required this.title1,
    required this.title2,
    required this.subtitle,
    required this.button,
    required this.badge,
    required this.image,
    required this.color,
    required this.accent,
    this.dim = false,
  });

  final String title1;
  final String title2;
  final String subtitle;
  final String button;
  final String badge;
  final String image;
  final Color color;
  final Color accent;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 355 / 200,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.0),
        child: Opacity(
          opacity: dim ? 0.45 : 1.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: color),
              if (image.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: AdminImage(image, fit: BoxFit.cover),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    // Dégradé allégé : la photo reste visible, le texte lisible.
                    colors: [
                      color.withValues(alpha: 0.82),
                      color.withValues(alpha: 0.62),
                      color.withValues(alpha: 0.32),
                      color.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.30, 0.50, 0.68, 0.82],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 110.0, 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (badge.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4.0),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7.0, vertical: 2.0),
                            decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(6.0)),
                            child: Text(badge,
                                style: TextStyle(
                                    color: color,
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.w800)),
                          ),
                        if (title1.isNotEmpty)
                          Text(title1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19.0,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  shadows: kBannerTextShadow,
                                  height: 1.1)),
                        if (title2.isNotEmpty)
                          Text(title2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: accent,
                                  fontSize: 26.0,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  shadows: kBannerTextShadow,
                                  height: 1.0)),
                        const SizedBox(height: 4.0),
                        Text(subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                                shadows: kBannerTextShadow)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14.0, vertical: 6.0),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.0)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(button.isEmpty ? 'Découvrir' : button,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold)),
                          Icon(Icons.chevron_right_rounded,
                              color: color, size: 16.0),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.width,
    required this.banner,
    required this.canUp,
    required this.canDown,
    required this.onUp,
    required this.onDown,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onApprove,
    required this.onReject,
  });

  final double width;
  final Map<String, dynamic> banner;
  final bool canUp;
  final bool canDown;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final b = banner;
    final pending = b['status'] == 'pending';
    final off = b['active'] == false;
    final clicks = ((b['clicks'] as num?) ?? 0).toInt();
    return SizedBox(
      width: width,
      child: AdminCard(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BannerPreview(
              title1: b['title1'] ?? '',
              title2: b['title2'] ?? '',
              subtitle: b['subtitle'] ?? '',
              button: b['button'] ?? '',
              badge: b['badge'] ?? '',
              image: b['image'] ?? '',
              color: hexColor(b['color'], const Color(0xFFE51A1A)),
              accent: hexColor(b['accent'], const Color(0xFFFFD200)),
              dim: b['status'] != 'live',
            ),
            const SizedBox(height: 12.0),
            Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              children: [
                AdminBadge('#${((b['order'] as num?)?.toInt() ?? 0) + 1}',
                    tone: kToneGrey),
                AdminBadge(_statusLabels[b['status']] ?? '',
                    tone: _statusTone(b['status'])),
                b['kind'] == 'seller'
                    ? AdminBadge('Publicité · ${b['sellerName'] ?? ''}',
                        tone: kToneViolet)
                    : const AdminBadge('Promotion Kitunga', tone: kToneRed),
              ],
            ),
            const SizedBox(height: 8.0),
            _line(Icons.event_rounded, _period(b)),
            _line(Icons.ads_click_rounded, 'Clic : ${_targetText(b)}'),
            _line(Icons.touch_app_rounded,
                '$clicks clic${clicks > 1 ? 's' : ''}'),
            if (b['bySeller'] == true)
              _line(Icons.storefront_rounded,
                  'Proposée par le commerce depuis son application'),
            if ((b['reviewNote'] ?? '') != '')
              _line(Icons.info_outline_rounded, 'Motif du refus : ${b['reviewNote']}'),
            if (pending) ...[
              const SizedBox(height: 10.0),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: AdminColors.green),
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_rounded, size: 18.0),
                      label: const Text('Valider'),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AdminColors.red),
                      onPressed: onReject,
                      icon: const Icon(Icons.close_rounded, size: 18.0),
                      label: const Text('Refuser'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8.0),
            Row(
              children: [
                Opacity(
                  opacity: canUp ? 1.0 : 0.35,
                  child: AdminActionDot(
                      icon: Icons.arrow_upward_rounded,
                      tooltip: 'Monter',
                      onTap: canUp ? onUp : () {}),
                ),
                const SizedBox(width: 6.0),
                Opacity(
                  opacity: canDown ? 1.0 : 0.35,
                  child: AdminActionDot(
                      icon: Icons.arrow_downward_rounded,
                      tooltip: 'Descendre',
                      onTap: canDown ? onDown : () {}),
                ),
                const Spacer(),
                AdminActionDot(
                    icon: off
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    tooltip: off ? 'Activer' : 'Désactiver',
                    tone: off ? kToneGreen : kToneGrey,
                    onTap: onToggle),
                const SizedBox(width: 6.0),
                AdminActionDot(
                    icon: Icons.edit_rounded,
                    tooltip: 'Modifier',
                    tone: kToneOrange,
                    onTap: onEdit),
                const SizedBox(width: 6.0),
                AdminActionDot(
                    icon: Icons.delete_rounded,
                    tooltip: 'Supprimer',
                    tone: kToneRed,
                    onTap: onDelete),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 3.0),
        child: Row(
          children: [
            Icon(icon, size: 15.0, color: AdminColors.muted),
            const SizedBox(width: 6.0),
            Expanded(
                child: Text(text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminText.label(size: 12.5))),
          ],
        ),
      );
}

/// Couleurs proposées : fond de la bannière et titre mis en avant.
const kBannerColors = [
  '#E51A1A', '#C2185B', '#6A1B9A', '#1565C0', '#00796B', '#2E7D32', //
  '#EF6C00', '#4E342E', '#212121',
];
const kBannerAccents = [
  '#FFD200', '#FFFFFF', '#FFB4C8', '#B3E5FC', '#C8E6C9', '#FFE0B2',
];

class _BannerForm extends StatefulWidget {
  const _BannerForm({this.banner});

  final Map<String, dynamic>? banner;

  @override
  State<_BannerForm> createState() => _BannerFormState();
}

class _BannerFormState extends State<_BannerForm> {
  late final Map<String, dynamic> _b = widget.banner ?? const {};
  late final Map _t = _b['target'] is Map ? _b['target'] as Map : const {};
  late String _kind = _b['kind'] ?? 'app';
  late String? _seller =
      (_b['sellerUid'] ?? '') == '' ? null : _b['sellerUid'] as String;
  late final _title1 = TextEditingController(text: _b['title1'] ?? '');
  late final _title2 = TextEditingController(text: _b['title2'] ?? '');
  late final _subtitle = TextEditingController(text: _b['subtitle'] ?? '');
  late final _button =
      TextEditingController(text: _b['button'] ?? 'Découvrir');
  late final _badge = TextEditingController(text: _b['badge'] ?? '');
  late final _url = TextEditingController(
      text: _t['type'] == 'url' ? '${_t['value'] ?? ''}' : '');
  late String _image = _b['image'] ?? '';
  late String _color = _b['color'] ?? kBannerColors.first;
  late String _accent = _b['accent'] ?? kBannerAccents.first;
  late String _target = '${_t['type'] ?? 'shops'}';
  late String? _category =
      _t['type'] == 'category' ? '${_t['value']}' : null;
  late String? _product = _t['type'] == 'product' ? '${_t['value']}' : null;
  late DateTime? _start = DateTime.tryParse(_b['startsAt'] ?? '')?.toLocal();
  late DateTime? _end = DateTime.tryParse(_b['endsAt'] ?? '')?.toLocal();
  late bool _active = _b['active'] != false;
  bool _saving = false;
  String? _error;

  final _sellers = loadAdminPartners('Seller');
  final _categories = loadAdminCategories();
  Future<List<Map<String, dynamic>>>? _products;

  @override
  void initState() {
    super.initState();
    for (final c in [_title1, _title2, _subtitle, _button, _badge]) {
      c.addListener(() => setState(() {}));
    }
    _loadProducts();
  }

  void _loadProducts() {
    final s = _seller;
    _products = s == null
        ? null
        : salesCall('kitungaCatalogQuery', {'view': 'products', 'sellerUid': s})
            .then((r) => listOf(r['products']));
  }

  @override
  void dispose() {
    for (final c in [_title1, _title2, _subtitle, _button, _badge, _url]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    String? error;
    if (_title1.text.trim().isEmpty && _title2.text.trim().isEmpty) {
      error = 'Indiquez le titre.';
    }
    if (_image.isEmpty) error ??= 'Ajoutez une image.';
    if (_kind == 'seller' && _seller == null) {
      error ??= 'Choisissez le commerce annonceur.';
    }
    if (_target == 'category' && _category == null) {
      error ??= 'Choisissez la catégorie.';
    }
    if (_target == 'shop' && _seller == null) {
      error ??= 'Choisissez le commerce.';
    }
    if (_target == 'product' && _product == null) {
      error ??= 'Choisissez le produit.';
    }
    if (_target == 'url' && !_url.text.trim().startsWith('http')) {
      error ??= 'Lien : il doit commencer par https://';
    }
    if (_start != null && _end != null && !_end!.isAfter(_start!)) {
      error ??= 'La date de fin doit être après la date de début.';
    }
    if (error != null) return setState(() => _error = error);
    setState(() {
      _saving = true;
      _error = null;
    });
    final value = switch (_target) {
      'category' => _category,
      'shop' => _seller,
      'product' => _product,
      'url' => _url.text.trim(),
      _ => '',
    };
    final ok = await runSalesAction(
        context,
        () => salesCall('kitungaSaveBanner', {
              if (_b['id'] != null) 'id': _b['id'],
              'kind': _kind,
              if (_kind == 'seller') 'sellerUid': _seller,
              'title1': _title1.text.trim(),
              'title2': _title2.text.trim(),
              'subtitle': _subtitle.text.trim(),
              'button': _button.text.trim(),
              'badge': _badge.text.trim(),
              'image': _image,
              'color': _color,
              'accent': _accent,
              'target': {'type': _target, 'value': value},
              'active': _active,
              'startsAt': _start == null
                  ? null
                  : brazzavilleDayStart(_start!),
              'endsAt': _end == null ? null : brazzavilleDayEnd(_end!),
            }),
        _b['id'] == null ? 'Bannière ajoutée' : 'Bannière modifiée');
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
    }
  }

  Widget _palette(String label, List<String> colors, String value,
          ValueChanged<String> onPick) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: salesBody(color: kSalesInk)),
          const SizedBox(height: 6.0),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              for (final hex in colors)
                Tooltip(
                  message: hex,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onPick(hex),
                    child: Container(
                      width: 30.0,
                      height: 30.0,
                      decoration: BoxDecoration(
                        color: hexColor(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: value.toUpperCase() == hex
                                ? kSalesRed
                                : AdminColors.border,
                            width: value.toUpperCase() == hex ? 2.5 : 1.0),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );

  Widget _dateButton(String label, DateTime? value, ValueChanged<DateTime?> set) =>
      OutlinedButton.icon(
        onPressed: () async {
          final d = await pickDay(context, value);
          if (d != null) set(d);
        },
        onLongPress: () => set(null),
        icon: const Icon(Icons.event_rounded, size: 18.0),
        label: Text(value == null
            ? label
            : '$label : ${dateFr(value.toIso8601String())}'),
      );

  @override
  Widget build(BuildContext context) {
    return AdminFormDialog(
      icon: Icons.campaign_rounded,
      title: _b['id'] == null ? 'Nouvelle bannière' : 'Modifier la bannière',
      saving: _saving,
      onSave: _save,
      children: [
        Text('Aperçu dans l\'application', style: salesBody(color: kSalesInk)),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380.0),
            child: BannerPreview(
          title1: _title1.text.trim(),
          title2: _title2.text.trim(),
          subtitle: _subtitle.text.trim(),
          button: _button.text.trim(),
          badge: _badge.text.trim(),
          image: _image,
          color: hexColor(_color),
          accent: hexColor(_accent),
            ),
          ),
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
                value: 'app',
                icon: Icon(Icons.local_offer_rounded),
                label: Text('Promotion Kitunga')),
            ButtonSegment(
                value: 'seller',
                icon: Icon(Icons.storefront_rounded),
                label: Text('Publicité d\'un commerce')),
          ],
          selected: {_kind},
          onSelectionChanged: (v) => setState(() {
            _kind = v.first;
            if (_kind == 'seller' && _target == 'shops') _target = 'shop';
          }),
        ),
        if (_kind == 'seller' || _target == 'shop' || _target == 'product')
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _sellers,
            builder: (context, snap) => DropdownButtonFormField<String>(
              key: ValueKey('seller-${snap.hasData}'),
              initialValue: (snap.data ?? const [])
                      .any((s) => s['uid'] == _seller)
                  ? _seller
                  : null,
              isExpanded: true,
              decoration: salesInput(_kind == 'seller'
                  ? 'Commerce annonceur'
                  : 'Commerce'),
              items: [
                for (final s in snap.data ?? const <Map<String, dynamic>>[])
                  DropdownMenuItem(
                      value: s['uid'] as String,
                      child: Text('${s['displayName'] ?? ''}'
                          ' · ${s['category'] ?? ''}')),
              ],
              onChanged: (v) => setState(() {
                _seller = v;
                _product = null;
                _loadProducts();
              }),
            ),
          ),
        AdminImageField(
          label: 'Photo (à droite de la bannière)',
          value: _image,
          height: 130.0,
          onChanged: (v) => setState(() => _image = v),
        ),
        AdminFieldRow(children: [
          TextField(
            controller: _title1,
            maxLength: 30,
            decoration: salesInput('Titre (ligne 1)', hint: 'Ex. Livraison'),
          ),
          TextField(
            controller: _title2,
            maxLength: 24,
            decoration:
                salesInput('Titre mis en avant (ligne 2)', hint: 'Ex. rapide'),
          ),
        ]),
        TextField(
          controller: _subtitle,
          maxLength: 90,
          maxLines: 2,
          decoration: salesInput('Texte',
              hint: 'Ex. Recevez vos commandes à domicile'),
        ),
        AdminFieldRow(children: [
          TextField(
            controller: _badge,
            maxLength: 14,
            decoration: salesInput('Pastille (facultative)',
                hint: 'Ex. -20 %, PROMO, NOUVEAU'),
          ),
          TextField(
            controller: _button,
            maxLength: 20,
            decoration: salesInput('Texte du bouton', hint: 'Découvrir'),
          ),
        ]),
        _palette('Couleur de fond', kBannerColors, _color,
            (v) => setState(() => _color = v)),
        _palette('Couleur du titre mis en avant', kBannerAccents, _accent,
            (v) => setState(() => _accent = v)),
        DropdownButtonFormField<String>(
          initialValue: _target,
          isExpanded: true,
          decoration: salesInput('Quand on touche la bannière, ouvrir…'),
          items: [
            for (final e in _targetLabels.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => _target = v ?? 'shops'),
        ),
        if (_target == 'category')
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _categories,
            builder: (context, snap) => DropdownButtonFormField<String>(
              key: ValueKey('cat-${snap.hasData}'),
              initialValue: (snap.data ?? const [])
                      .any((c) => c['name'] == _category)
                  ? _category
                  : null,
              isExpanded: true,
              decoration: salesInput('Catégorie'),
              items: [
                for (final c in snap.data ?? const <Map<String, dynamic>>[])
                  DropdownMenuItem(
                      value: c['name'] as String, child: Text('${c['name']}')),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
          ),
        if (_target == 'product' && _products != null)
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _products,
            builder: (context, snap) => DropdownButtonFormField<String>(
              key: ValueKey('prod-$_seller-${snap.hasData}'),
              initialValue: (snap.data ?? const [])
                      .any((p) => p['id'] == _product)
                  ? _product
                  : null,
              isExpanded: true,
              decoration: salesInput('Produit'),
              items: [
                for (final p in snap.data ?? const <Map<String, dynamic>>[])
                  DropdownMenuItem(
                      value: p['id'] as String,
                      child: Text('${p['name']} · ${fcfa(p['price'] as num?)}')),
              ],
              onChanged: (v) => setState(() => _product = v),
            ),
          ),
        if (_target == 'url')
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: salesInput('Lien', hint: 'https://…'),
          ),
        Text('Période de diffusion (facultative)',
            style: salesBody(color: kSalesInk)),
        Wrap(
          spacing: 10.0,
          runSpacing: 8.0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _dateButton('Début', _start, (d) => setState(() => _start = d)),
            _dateButton('Fin', _end, (d) => setState(() => _end = d)),
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: kSalesRed,
          value: _active,
          onChanged: (v) => setState(() => _active = v),
          title: const Text('Active'),
          subtitle: const Text(
              'Désactivée : elle reste enregistrée mais n\'est plus diffusée.'),
        ),
        if (_error != null) Text(_error!, style: salesBody(color: kSalesRed)),
      ],
    );
  }
}
