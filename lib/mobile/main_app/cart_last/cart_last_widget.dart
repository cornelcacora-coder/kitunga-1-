import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/server_payment.dart';
import '/backend/subscription.dart';
import '/components/payment_method_widget.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/mobile/components/delivery/kitunga_exact_point.dart';
import '/mobile/components/empty_card/empty_card_widget.dart';
import '/mobile/components/kitunga_image/kitunga_image.dart';
import '/mobile/components/product_card/product_card_widget.dart'
    show kitungaPrice, kitungaNoPhoto;
import '/mobile/components/shop_card_kitunga/kitunga_shop_card.dart'
    show KitungaClosedNotice, kitungaShopPlaceholder, openKitungaShop;
import '/mobile/main_app/subscription/my_subscription_page.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'cart_last_model.dart';
export 'cart_last_model.dart';

const _red = Color(0xFFE51A1A);

/// Quartiers de livraison (mêmes noms que le serveur : pricing.js).
const _zones = [
  'Académie', 'Avenue de la Paix', 'Bacongo', 'Barrage', 'Batignolles',
  'Centre sportif', 'Centre-ville', 'Château d\'eau', 'Cité des 17', 'Diata',
  'Djiri', 'Kibina', 'Kingouari', 'Kinsoundi', 'Kintélé', 'Kombo', 'Kombé',
  'La Base', 'La Tsiémé', 'Ma-Mboualé', 'Madibou', 'Mafouta', 'Makabandilou',
  'Makélékélé', 'Mansimou', 'Mapassi', 'Marché Moungali', 'Massengo',
  'Massissia', 'Mayanga', 'Mbouono', 'Mfilou', 'Mikalou', 'Moukondo',
  'Moukoundzi-Ngouaka', 'Moungali', 'Moussosso', 'Mpila', 'Mpissa',
  'Ngamakosso', 'Nganga-Lingolo', 'Ndjiri', 'O.C.H', 'Ouenzé',
  'Plateau des 15 ans', 'Poto-Poto', 'Sadelmi', 'Soprogie', 'Talangaï',
];

/// Panier : commerce, articles (quantités), adresse de livraison, moyen de
/// paiement et récapitulatif ; « Commander et payer » toujours visible en
/// bas. Le paiement et le prix final sont calculés par le serveur.
class CartLastWidget extends StatefulWidget {
  const CartLastWidget({
    super.key,
    this.deliveryAddress,
    this.sellerRef,
    this.cartRef,
    this.airtelNumber,
    this.mtnNumber,
    this.orderitem,
    this.asTab = false,
  });

  final String? deliveryAddress;
  final DocumentReference? sellerRef;
  final CartRecord? cartRef;
  final String? airtelNumber;
  final String? mtnNumber;
  final DocumentReference? orderitem;

  /// Affiché comme onglet « Panier » de la barre du bas : pas de retour.
  final bool asTab;

  static String routeName = 'CartLast';
  static String routePath = '/cartLast';

  @override
  State<CartLastWidget> createState() => _CartLastWidgetState();
}

class _CartLastWidgetState extends State<CartLastWidget> {
  late CartLastModel _model;

  /// Frais calculés par le serveur (distance commerce → client), par
  /// « commerce|quartier|position ». Le paiement refait le même calcul.
  final Map<String, double> _quotes = {};
  final Set<String> _quoting = {};

  /// Position exacte du client (facultative) : frais de porte à porte.
  Map<String, double>? _deliveryPoint;

  /// Détail des devis (distance, source).
  final Map<String, Map<String, dynamic>> _quoteInfo = {};

  /// Lignes affichées, et donc payées, sur cet écran.
  List<CartRecord> _cartLines = [];
  bool _paying = false;

  String? get _quoteKey {
    final seller = _sellerRef;
    final zone = _model.zoneValue;
    if (seller == null || zone == null || zone.isEmpty) return null;
    return '${seller.path}|$zone|'
        '${_deliveryPoint?['lat']},${_deliveryPoint?['lng']}';
  }

  /// Frais confirmés par le serveur pour ce commerce, quartier et position.
  bool get _feeQuoted {
    final key = _quoteKey;
    return key == null || _quotes.containsKey(key);
  }

  /// « 9,6 km par la route » ou « environ 8 km (estimation) ».
  String? get _quoteNote {
    final key = _quoteKey;
    final q = key == null ? null : _quoteInfo[key];
    if (q == null) return null;
    final km = (q['km'] as num?)?.toDouble();
    final kmText =
        km == null ? '' : km.toStringAsFixed(1).replaceAll('.', ',');
    switch (q['source']) {
      case 'route':
        return 'Frais calculés sur $kmText km par la route.';
      case 'estimate':
        return 'Frais estimés sur environ $kmText km.';
      default:
        return 'Tarif du quartier de livraison.';
    }
  }

  double getDeliveryFeeForZone(String? zone) {
    final seller = _sellerRef;
    if (seller != null && zone != null && zone.isNotEmpty) {
      final key = '${seller.path}|$zone|'
          '${_deliveryPoint?['lat']},${_deliveryPoint?['lng']}';
      final quoted = _quotes[key];
      if (quoted != null) return quoted;
      if (_quoting.add(key)) {
        kitungaCallFunction('kitungaDeliveryQuote', {
          'sellerPath': seller.path,
          'zone': zone,
          if (_deliveryPoint != null) 'point': _deliveryPoint,
        }).then((r) {
          final fee = (r['fee'] as num?)?.toDouble();
          if (fee == null || !mounted) return;
          safeSetState(() {
            _quotes[key] = fee;
            _quoteInfo[key] = Map<String, dynamic>.from(r);
            if (_model.zoneValue == zone) {
              _model.deliveryFees = fee;
              FFAppState().fixedShippingFee = fee;
              FFAppState().GrandTotalCart = FFAppState().totalCart + fee;
            }
          });
        }).catchError((_) {
          _quoting.remove(key); // nouvel essai au prochain affichage
        });
      }
    }
    // En attendant la réponse du serveur : ancien tarif par quartier.
    return _zoneFee(zone);
  }

  double _zoneFee(String? zone) {
    if (zone == null || zone.isEmpty) return 1000.0;
    if (const [
      'Ouenzé', 'Mapassi', 'Mpila', 'La Tsiémé', 'Talangaï', 'Mikalou',
      'Ngamakosso', 'Ma-Mboualé', 'Kanga Mbandz', 'Mfilou', 'Sadelmi',
      'La Base', 'Mazala', 'Cité des 17', 'Soprogie'
    ].contains(zone)) {
      return 1500.0;
    }
    if (const [
      'Madibou', 'Mansimou', 'Mafouta', 'Massissia', 'Djiri', 'Ndjiri',
      'Massengo', 'Kombo', 'Kintélé', 'Makabandilou'
    ].contains(zone)) {
      return 2000.0;
    }
    if (const [
      'Mayanga', 'Moussosso', 'Mbouono', 'Kombé', 'Kibina', 'Nganga-Lingolo'
    ].contains(zone)) {
      return 2500.0;
    }
    return 1000.0;
  }

  /// Commerce de la commande : celui demandé à l'ouverture de l'écran, sinon
  /// celui des lignes affichées (panier ouvert depuis l'onglet, l'accueil…).
  DocumentReference? get _sellerRef =>
      widget.sellerRef ?? _cartLines.firstOrNull?.sellerRef;

  /// Une commande ne concerne qu'un seul commerce. Sans commerce précisé, on
  /// garde celui du dernier article ajouté (anciens paniers mélangés).
  List<CartRecord> _linesOfOneSeller(List<CartRecord> lines) {
    if (widget.sellerRef != null || lines.isEmpty) return lines;
    var latest = lines.first;
    for (final line in lines) {
      final at = line.createdAt;
      final best = latest.createdAt;
      if (at != null && (best == null || at.isAfter(best))) latest = line;
    }
    return lines.where((l) => l.sellerRef == latest.sellerRef).toList();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CartLastModel());
    _model.locationTextController ??=
        TextEditingController(text: widget.deliveryAddress ?? '');
    _model.locationFocusNode ??= FocusNode();
    // MTN MoMo est le moyen de paiement (Airtel : bientôt).
    _model.paymentMethodModel.isMoMoValue = true;
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  /// Totaux partagés (FFAppState) : mêmes valeurs que l'écran.
  void _syncTotals(double subtotal, double fee) {
    final total = subtotal + fee;
    if (FFAppState().totalCart == subtotal &&
        FFAppState().fixedShippingFee == fee &&
        FFAppState().GrandTotalCart == total) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FFAppState().totalCart = subtotal;
      FFAppState().fixedShippingFee = fee;
      FFAppState().GrandTotalCart = total;
      _model.deliveryFees = fee;
    });
  }

  Future<void> _alert(String title, String text) => showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('Ok')),
          ],
        ),
      );

  /// « Commander et payer » : vérifications, puis paiement par le serveur.
  Future<void> _checkout() async {
    if (_paying) return;
    final lines = List<CartRecord>.of(_cartLines);
    if (lines.isEmpty || _sellerRef == null) {
      await _alert(
          lines.isEmpty ? 'Panier vide' : 'Commerce introuvable',
          lines.isEmpty
              ? 'Ajoutez un produit à votre panier avant de commander.'
              : 'Retirez cet article du panier puis ajoutez-le de nouveau '
                  'depuis la page du commerce.');
      return;
    }
    if (_model.zoneValue == null || _model.zoneValue!.trim().isEmpty) {
      await _alert('Quartier requis',
          'Choisissez votre quartier de livraison avant de commander.');
      return;
    }
    if (!kitungaCanOrder()) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Abonnement requis'),
          content: const Text(kitungaSubscriptionRequired),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Compris')),
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                openMySubscription(context);
              },
              child: const Text('S\'abonner'),
            ),
          ],
        ),
      );
      return;
    }
    // Numéro saisi dans « Paiement » (MTN), sinon celui du compte.
    final operator = _model.paymentMethodModel.operator;
    final typed = _model.paymentMethodModel.phoneController.text.trim();
    final raw = typed.isNotEmpty
        ? typed
        : _mtnDefault.trim();
    var phone = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('06') && phone.length == 9) {
      phone = '242$phone';
    } else if (phone.startsWith('6') && phone.length == 8) {
      phone = '2420$phone';
    }
    if (phone.isEmpty) {
      await _alert('Numéro requis',
          'Renseignez votre numéro ${kPaymentOperators[operator]!.label} avant de commander.');
      return;
    }
    setState(() => _paying = true);
    try {
      await _payOnServer(phone, operator);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  /// Paiement contrôlé par le serveur : prix, stock et commande calculés
  /// par les Cloud Functions (voir lib/backend/server_payment.dart).
  Future<void> _payOnServer(String phone, [String operator = 'MTN']) async {
    final label = kPaymentOperators[operator]?.label ?? 'Mobile Money';
    final short = operator == 'Airtel' ? 'Airtel' : 'MTN';
    final theme = FlutterFlowTheme.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final router = GoRouter.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _red),
              const SizedBox(height: 18.0),
              Text(
                'Validez le paiement sur votre téléphone\n'
                '(saisissez votre code PIN $label)…',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    color: theme.primaryText,
                    decoration: TextDecoration.none),
              ),
            ],
          ),
        ),
      ),
    );
    String title;
    String message;
    var paid = false;
    try {
      final r = await kitungaServerPay(
        sellerRef: _sellerRef!,
        zone: _model.zoneValue ?? '',
        deliveryLocation: _model.locationTextController!.text,
        phone: phone,
        operator: operator,
        deliveryPoint: _deliveryPoint,
      );
      switch (r.status) {
        case 'paid':
          paid = true;
          title = 'Commande confirmée';
          message = 'Paiement de ${kitungaPrice(r.amount)} reçu. Le commerce '
              'prépare votre commande, suivez-la dans « Mes commandes ».';
        case 'paid_refund':
          title = 'Article plus disponible';
          message = 'Votre paiement a été reçu, mais un article n\'est plus '
              'disponible${r.reason?.isNotEmpty == true ? ' :\n${r.reason}' : '.'}'
              '\nLe support Kitunga va vous rembourser '
              '(contact@ntemoconsulting.com).';
        case 'failed':
          title = 'Paiement refusé';
          message =
              '$short a refusé le paiement. Vérifiez votre solde puis réessayez.';
        default:
          title = 'Paiement en attente';
          message = 'Nous n\'avons pas encore reçu la validation $short. Si '
              'vous avez validé, votre commande apparaîtra dans « Mes '
              'commandes » dans quelques minutes.';
      }
    } on ServerPaymentException catch (e) {
      title = 'Paiement impossible';
      message = e.message;
    }
    navigator.pop();
    if (!mounted) return;
    if (paid) {
      FFAppState().GrandTotalCart = 0.0;
      FFAppState().totalCart = 0.0;
      FFAppState().isSameOrder = false;
      FFAppState().orderReferenceUnique = '';
    }
    await _alert(title, message);
    if (paid) router.pushNamed(HomeWidget.routeName);
  }

  /// Numéro MTN du compte : le principal, sinon le second s'il est MTN
  /// (06…), pour préremplir le paiement.
  String get _mtnDefault {
    if ((widget.mtnNumber ?? '').isNotEmpty) return widget.mtnNumber!;
    final second =
        '${currentUserDocument?.snapshotData['phone_number_2'] ?? ''}'.trim();
    bool mtn(String n) {
      final d = n.replaceAll(RegExp(r'\D'), '');
      final local = d.startsWith('242') ? d.substring(3) : d;
      return local.startsWith('06');
    }
    if (!mtn(currentPhoneNumber) && second.isNotEmpty && mtn(second)) {
      return second;
    }
    return currentPhoneNumber;
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      context.safePop();
    } else {
      context.goNamed(HomeWidget.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF101418) : Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: widget.asTab ? 20 : 4,
          leading: widget.asTab
              ? null
              : IconButton(
                  tooltip: 'Retour',
                  onPressed: _back,
                  icon:
                      Icon(Icons.arrow_back_rounded, color: theme.primaryText),
                ),
          title: Text('Mon panier',
              style: GoogleFonts.poppins(
                  fontSize: widget.asTab ? 26 : 20,
                  fontWeight: FontWeight.w600,
                  color: theme.primaryText)),
        ),
        body: StreamBuilder<List<CartRecord>>(
          stream: queryCartRecord(
            queryBuilder: (q) => q
                .where('user_ref', isEqualTo: currentUserReference)
                .where('is_ordered', isEqualTo: false)
                .where('seller_ref', isEqualTo: widget.sellerRef),
          ),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: _red));
            }
            final lines = _linesOfOneSeller(snap.data!);
            _cartLines = lines;
            if (lines.isEmpty) {
              return EmptyCardWidget(
                title: 'Votre panier est vide',
                description:
                    'Parcourez les commerces et ajoutez vos produits avec le '
                    'bouton +.',
                buttonText: 'Découvrir les commerces',
                photo: 'assets/images/app/emptycart.png',
                action: () async => context.goNamed(HomeWidget.routeName),
              );
            }
            final subtotal = functions.calculateSubtotal(lines) ?? 0.0;
            final fee = getDeliveryFeeForZone(_model.zoneValue);
            _syncTotals(subtotal, fee);
            final count = lines.fold<int>(0, (s, l) => s + l.quantity);
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      if (_sellerRef != null) ...[
                        _ShopHeader(shopRef: _sellerRef!),
                        KitungaClosedNotice(sellerRef: _sellerRef!),
                        const SizedBox(height: 12),
                      ],
                      for (final line in lines) ...[
                        _CartLine(line: line),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 8),
                      _Section(
                        icon: Icons.location_on_rounded,
                        title: 'Livraison',
                        child: _delivery(theme),
                      ),
                      const SizedBox(height: 14),
                      _Section(
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Paiement',
                        child: AuthUserStreamWidget(
                          builder: (context) => wrapWithModel(
                            model: _model.paymentMethodModel,
                            updateCallback: () => safeSetState(() {}),
                            child: PaymentMethodWidget(
                              selected: true,
                              icon: Icon(Icons.phone_android_rounded,
                                  color: theme.primaryText, size: 24.0),
                              airtelNumber:
                                  (widget.airtelNumber ?? '').isNotEmpty
                                      ? widget.airtelNumber!
                                      : currentPhoneNumber,
                              mtnNumber: _mtnDefault,
                              isMoMo: () async {
                                _model.paymentMethodModel.isMoMoValue = true;
                                safeSetState(() {});
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Section(
                        icon: Icons.receipt_long_rounded,
                        title: 'Récapitulatif',
                        child: Column(children: [
                          _AmountRow(
                              label: 'Sous-total ($count article'
                                  '${count > 1 ? 's' : ''})',
                              value: kitungaPrice(subtotal)),
                          _AmountRow(
                              label: 'Livraison',
                              value: _model.zoneValue == null
                                  ? 'Choisissez le quartier'
                                  : _feeQuoted
                                      ? kitungaPrice(fee)
                                      : 'calcul…'),
                          if (_quoteNote != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(_quoteNote!,
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: theme.secondaryText)),
                              ),
                            ),
                          Divider(color: theme.alternate, height: 22),
                          _AmountRow(
                              label: 'Total à payer',
                              value: kitungaPrice(subtotal + fee),
                              strong: true),
                        ]),
                      ),
                    ],
                  ),
                ),
                _PayBar(
                  total: subtotal + fee,
                  ready: _model.zoneValue != null && _feeQuoted,
                  busy: _paying,
                  onPay: _checkout,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _delivery(FlutterFlowTheme theme) {
    InputDecoration deco(String label, IconData icon) => InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: theme.secondaryText, size: 20),
          filled: true,
          fillColor: theme.primaryBackground,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _red, width: 1.4)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _model.zoneValue,
          isExpanded: true,
          menuMaxHeight: 380,
          borderRadius: BorderRadius.circular(14),
          decoration: deco('Quartier', Icons.map_outlined),
          items: [
            for (final z in _zones) DropdownMenuItem(value: z, child: Text(z)),
          ],
          onChanged: (val) {
            final fee = getDeliveryFeeForZone(val);
            safeSetState(() {
              _model.zoneValue = val;
              _model.zone = val;
              _model.deliveryFees = fee;
              FFAppState().fixedShippingFee = fee;
              FFAppState().GrandTotalCart = FFAppState().totalCart + fee;
            });
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _model.locationTextController,
          focusNode: _model.locationFocusNode,
          textCapitalization: TextCapitalization.sentences,
          decoration: deco(
              'Rue, repère (ex. 32 bis av. Corniche)', Icons.home_outlined),
        ),
        const SizedBox(height: 10),
        KitungaExactPointButton(
          point: _deliveryPoint,
          onChanged: (p) => safeSetState(() {
            _deliveryPoint = p;
            final fee = getDeliveryFeeForZone(_model.zoneValue);
            _model.deliveryFees = fee;
          }),
        ),
      ],
    );
  }
}

/// Commerce de la commande : logo, nom, lien pour ajouter d'autres articles.
class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.shopRef});

  final DocumentReference shopRef;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return StreamBuilder<UserRecord>(
      stream: UserRecord.getDocument(shopRef),
      builder: (context, snap) {
        final shop = snap.data;
        if (shop == null) return const SizedBox(height: 56);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            ClipOval(
              child: SizedBox(
                width: 44,
                height: 44,
                child: KitungaImage(shop.photoUrl,
                    width: 44,
                    height: 44,
                    fallbackIcon: Icons.storefront_rounded,
                    placeholder: kitungaShopPlaceholder(context, shop,
                        width: 44, height: 44)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Commande chez',
                      style: GoogleFonts.poppins(
                          fontSize: 12.5, color: theme.secondaryText)),
                  Text(shop.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryText)),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => openKitungaShop(context, shop),
              style: TextButton.styleFrom(foregroundColor: _red),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Ajouter',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ]),
        );
      },
    );
  }
}

/// Une ligne du panier : photo, nom, options, prix, quantité + / −.
class _CartLine extends StatelessWidget {
  const _CartLine({required this.line});

  final CartRecord line;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return StreamBuilder<ProductRecord>(
      stream: ProductRecord.getDocument(line.productRef!),
      builder: (context, snap) {
        final p = snap.data;
        final stock = p?.quantity ?? 0;
        final name = p?.name ?? line.productName;
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.alternate),
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 68,
                height: 68,
                color: theme.primaryBackground,
                child: p == null
                    ? null
                    : KitungaImage(p.prodImg,
                        width: 68,
                        height: 68,
                        fallbackIcon: Icons.image_outlined,
                        placeholder: kitungaNoPhoto(theme, p, 68, width: 68)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryText)),
                  if (line.options.isNotEmpty)
                    Text(line.options,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: theme.secondaryText)),
                  const SizedBox(height: 4),
                  Text(kitungaPrice(line.price * line.quantity),
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _red)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _Stepper(
              quantity: line.quantity,
              canAdd: p != null && line.quantity < stock,
              onMinus: () async {
                if (line.quantity > 1) {
                  await line.reference
                      .update({'quantity': FieldValue.increment(-1)});
                } else {
                  await line.reference.delete();
                  FFAppState().removeFromCartitems(line.reference);
                }
              },
              onPlus: () =>
                  line.reference.update({'quantity': FieldValue.increment(1)}),
            ),
          ]),
        );
      },
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.quantity,
    required this.canAdd,
    required this.onMinus,
    required this.onPlus,
  });

  final int quantity;
  final bool canAdd;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget btn(IconData icon, String tip, VoidCallback? onTap,
            {Color? color}) =>
        Tooltip(
          message: tip,
          child: InkResponse(
            onTap: onTap,
            radius: 20,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: onTap == null
                    ? theme.alternate
                    : (color ?? _red).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 18,
                  color: onTap == null ? theme.secondaryText : color ?? _red),
            ),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.add_rounded, 'Plus', canAdd ? onPlus : null),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text('$quantity',
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.primaryText)),
        ),
        btn(
            quantity > 1 ? Icons.remove_rounded : Icons.delete_outline_rounded,
            quantity > 1 ? 'Moins' : 'Retirer',
            onMinus,
            color: quantity > 1 ? _red : theme.secondaryText),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(
      {required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(icon, size: 20, color: _red),
            const SizedBox(width: 8),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryText)),
          ]),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(
      {required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: strong ? 16.5 : 14,
                  fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
                  color: strong ? theme.primaryText : theme.secondaryText)),
        ),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: strong ? 18 : 14,
                fontWeight: FontWeight.w600,
                color: strong ? _red : theme.primaryText)),
      ]),
    );
  }
}

/// Barre du bas, toujours visible : total et « Commander et payer ».
class _PayBar extends StatelessWidget {
  const _PayBar({
    required this.total,
    required this.ready,
    required this.busy,
    required this.onPay,
  });

  final double total;
  final bool ready;
  final bool busy;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total',
                    style: GoogleFonts.poppins(
                        fontSize: 12.5, color: theme.secondaryText)),
                Text(kitungaPrice(total),
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryText)),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  // Toujours cliquable : le client est guidé (quartier…).
                  onPressed: busy ? null : onPay,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        ready ? _red : _red.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : Text('Commander et payer',
                          style: GoogleFonts.poppins(
                              fontSize: 15.5, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
