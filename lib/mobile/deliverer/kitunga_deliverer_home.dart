import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/kitunga_notifications.dart' show KitungaNotificationBell;
import '/backend/order_status.dart';
import '/backend/server_payment.dart' show ServerPaymentException;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart' show OrderViewSellerDeliverWidget, OrderWidget;
import '/mobile/components/delivery/kitunga_deliverer_panel.dart';
import '/mobile/components/delivery/kitunga_delivery.dart'
    show kitungaTakeDelivery;
import '/mobile/components/delivery/kitunga_live_tracking.dart';
import '/mobile/components/finance/kitunga_earnings.dart'
    show kitungaMyEarnings, openKitungaEarnings;
import '/mobile/components/kitunga_contact.dart' show kCompanyPhones;
import 'kitunga_deliverer_pro.dart'
    show
        DelivererDocumentsPage,
        DelivererPerformancePage,
        DelivererSafetyPage,
        kVerification;
import '/mobile/components/support/kitunga_support.dart'
    show openKitungaSupport;

/// Accueil du livreur : outil de travail de la journée.
///
/// En-tête aux couleurs de Kitunga (salutation, disponibilité, notifications),
/// chiffres du jour, course en cours, nouvelles courses de ses quartiers,
/// aperçu, dernières courses et assistance. Chaque état a son écran :
/// en service, en pause, hors service, aucune course, connexion perdue.

/// Remplace les commandes (les miennes, puis les courses disponibles) dans
/// les tests.
@visibleForTesting
Stream<List<OrdersRecord>>? delivererMyOrdersOverride;
@visibleForTesting
Stream<List<OrdersRecord>>? delivererOpenOrdersOverride;

/// Mes courses (toutes), en direct.
Stream<List<OrdersRecord>> delivererMyOrdersStream() =>
    delivererMyOrdersOverride ??
    queryOrdersRecord(
        queryBuilder: (o) => o.where('deliverer_ref', isEqualTo: currentUserUid));

/// Courses prêtes ou en livraison (pour les propositions et la carte).
Stream<List<OrdersRecord>> delivererOpenOrdersStream() =>
    delivererOpenOrdersOverride ??
    queryOrdersRecord(
        queryBuilder: (o) =>
            o.where('status', whereIn: OrderStatus.forDeliverers));

/// Commandes simulées (tests) : ni GPS ni carte réseau.
bool get delivererSimulated => delivererMyOrdersOverride != null;

/// Course proposée en exclusivité à ce livreur (champs écrits par le
/// serveur : offer_to, offer_expires_at, offer_mission).
DateTime? offerExpiry(OrdersRecord o) {
  final v = o.snapshotData['offer_expires_at'];
  if (v is DateTime) return v;
  try {
    return (v as dynamic)?.toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}

bool offeredToOther(OrdersRecord o, String me, DateTime now) {
  final to = o.snapshotData['offer_to'];
  final until = offerExpiry(o);
  return to is String && to.isNotEmpty && to != me &&
      until != null && until.isAfter(now);
}

bool offeredToMe(OrdersRecord o, String me, DateTime now) {
  final until = offerExpiry(o);
  return o.snapshotData['offer_to'] == me &&
      until != null && until.isAfter(now) &&
      o.status == OrderStatus.ready;
}

const _red = Color(0xFFE51A1A);
const _redDark = Color(0xFFB0101A);
const _yellow = Color(0xFFFFC21A);
const _orange = Color(0xFFFF8A00);
const _green = Color(0xFF17A35B);

bool _sameDay(DateTime? a, DateTime b) =>
    a != null && a.year == b.year && a.month == b.month && a.day == b.day;

String _fcfa(num v) => '${NumberFormat.decimalPattern('fr').format(v)} F';

/// Statut d'une course, pour le livreur.
({String label, Color color}) courseStatusOf(OrdersRecord o) {
  if (o.status == OrderStatus.ready) {
    return (label: 'Prête', color: _green);
  }
  if (o.status == OrderStatus.delivering) {
    return (label: 'En cours', color: _red);
  }
  if (OrderStatus.successful.contains(o.status)) {
    return (label: 'Livrée', color: _green);
  }
  if (o.status == OrderStatus.notReceived) {
    return (label: 'Litige', color: _orange);
  }
  return (label: 'Annulée', color: const Color(0xFF8A94A6));
}

class KitungaDelivererHome extends StatefulWidget {
  const KitungaDelivererHome({super.key});

  @override
  State<KitungaDelivererHome> createState() => _KitungaDelivererHomeState();
}

class _KitungaDelivererHomeState extends State<KitungaDelivererHome> {
  Timer? _ping;
  Timer? _tick;

  // Gains du jour (grand livre du serveur), rechargés après chaque course
  // livrée.
  num? _earnedToday;
  int _deliveredSeen = -1;

  void _loadEarnings() {
    kitungaMyEarnings().then((r) {
      if (mounted) setState(() => _earnedToday = r['today'] as num?);
    }).catchError((_) {});
  }

  @override
  void initState() {
    super.initState();
    // Position envoyée toutes les 2 minutes, seulement en service (le
    // serveur l'ignore sinon) : elle sert à choisir le livreur le plus
    // proche.
    // (Pas de GPS dans les tests, où les commandes sont simulées.)
    if (delivererMyOrdersOverride == null) {
      _sendPosition();
      _ping = Timer.periodic(
          const Duration(minutes: 2), (_) => _sendPosition());
    }
    // Compte à rebours des propositions.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ping?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _sendPosition() async {
    try {
      final p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      await delivererCall('kitungaDelivererPing',
          {'lat': pos.latitude, 'lng': pos.longitude});
    } catch (_) {
      // GPS ou réseau indisponible : nouvel essai au prochain passage.
    }
  }

  Stream<List<OrdersRecord>> _mine() =>
      delivererMyOrdersOverride ??
      queryOrdersRecord(
          queryBuilder: (o) => o.where('deliverer_ref', isEqualTo: currentUserUid));

  Stream<List<OrdersRecord>> _open() =>
      delivererOpenOrdersOverride ??
      queryOrdersRecord(
          queryBuilder: (o) =>
              o.where('status', whereIn: OrderStatus.forDeliverers));

  // Créés une fois : l'écran se redessine chaque seconde (compte à rebours).
  late final Stream<List<OrdersRecord>> _mineStream = _mine();
  late final Stream<List<OrdersRecord>> _openStream = _open();

  @override
  Widget build(BuildContext context) {
    return DelivererStateBuilder(
      builder: (context, state) => StreamBuilder<List<OrdersRecord>>(
        stream: _mineStream,
        builder: (context, mineSnap) {
          final delivered = (mineSnap.data ?? const <OrdersRecord>[])
              .where((o) => OrderStatus.successful.contains(o.status))
              .length;
          if (mineSnap.hasData && delivered != _deliveredSeen &&
              !delivererSimulated) {
            _deliveredSeen = delivered;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _loadEarnings());
          }
          return StreamBuilder<List<OrdersRecord>>(
            stream: _openStream,
            builder: (context, openSnap) => _DelivererHomeBody(
              state: state,
              mine: mineSnap.data,
              open: openSnap.data,
              offline: mineSnap.hasError || openSnap.hasError,
              earnedToday: _earnedToday,
            ),
          );
        },
      ),
    );
  }
}

class _DelivererHomeBody extends StatelessWidget {
  const _DelivererHomeBody({
    required this.state,
    required this.mine,
    required this.open,
    required this.offline,
    this.earnedToday,
  });

  final DelivererState state;
  final List<OrdersRecord>? mine;
  final List<OrdersRecord>? open;
  final bool offline;

  /// Gains du jour selon le serveur (null tant qu'ils ne sont pas chargés).
  final num? earnedToday;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final now = DateTime.now();
    final my = [...?mine]..sort((a, b) => (b.createdAt ?? DateTime(0))
        .compareTo(a.createdAt ?? DateTime(0)));
    final active =
        my.where((o) => o.status == OrderStatus.delivering).toList();
    final doneToday = my
        .where((o) =>
            OrderStatus.successful.contains(o.status) &&
            _sameDay(o.createdAt, now))
        .toList();
    final feesToday =
        doneToday.fold<double>(0, (s, o) => s + o.deliveryFees);
    final delivered =
        my.where((o) => OrderStatus.successful.contains(o.status)).length;
    final problems = my
        .where((o) => [
              OrderStatus.notReceived,
              OrderStatus.cancelled,
              OrderStatus.refused
            ].contains(o.status))
        .length;
    final me = currentUserUid;
    final forMe = [
      for (final o in open ?? const <OrdersRecord>[])
        if (offeredToMe(o, me, now)) o
    ];
    // Courses ouvertes : ni proposées à un autre livreur en ce moment, ni
    // déjà prises.
    final offers = [
      for (final o in open ?? const <OrdersRecord>[])
        if (o.status == OrderStatus.ready &&
            o.delivererRef.isEmpty &&
            !offeredToMe(o, me, now) &&
            !offeredToOther(o, me, now) &&
            delivererCovers(state.zones, o.deliveryZone))
          o
    ];
    final loading = mine == null || open == null;

    // Fond uni (sans les vagues décoratives) : lecture plus nette.
    return ColoredBox(
      color: theme.primaryBackground,
      child: RefreshIndicator(
      color: _red,
      onRefresh: () async =>
          Future<void>.delayed(const Duration(milliseconds: 400)),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _Header(state: state, feesToday: earnedToday ?? feesToday,
              coursesToday: doneToday.length),
          if (offline)
            const _Notice(
              icon: Icons.wifi_off_rounded,
              color: _orange,
              text: 'Connexion perdue. Les informations affichées peuvent '
                  'ne pas être à jour.',
            ),
          // Compte suspendu ou documents à régler : action proposée.
          if (state.suspended)
            _AccountBanner(
              icon: Icons.block_rounded,
              title: 'Compte suspendu',
              text: 'Vous ne recevez plus de courses. Contactez le support '
                  'Kitunga pour en connaître la raison.',
              action: 'Contacter le support',
              onTap: () => openKitungaSupport(context),
            )
          else if (state.verification != 'verified')
            _AccountBanner(
              icon: Icons.badge_outlined,
              title: kVerification[state.verification]?.$1 ??
                  'Documents à compléter',
              text: kVerification[state.verification]?.$3 ??
                  'Déposez vos documents pour être vérifié.',
              action: 'Mes documents',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const DelivererDocumentsPage())),
            ),
          for (final o in forMe) KitungaOfferCard(order: o),
          if (active.isNotEmpty) KitungaActiveDeliveryBanner(orders: active),
          _AvailabilityStrip(state: state),
          _SectionTitle(
            title: 'Nouvelles courses',
            trailing: state.state == 'on' && offers.isNotEmpty
                ? '${offers.length}'
                : null,
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: _red)),
            )
          else if (state.state != 'on')
            _EmptyCard(
              icon: state.state == 'pause'
                  ? Icons.coffee_rounded
                  : Icons.bedtime_outlined,
              title: state.state == 'pause'
                  ? 'Vous êtes en pause'
                  : 'Vous êtes hors service',
              text: active.isNotEmpty
                  ? 'Terminez votre course en cours. Passez en service pour '
                      'recevoir de nouvelles courses.'
                  : 'Passez en service pour recevoir les nouvelles courses '
                      'de vos quartiers.',
            )
          else if (offers.isEmpty)
            _EmptyCard(
              icon: Icons.inbox_rounded,
              title: 'Aucune course pour le moment',
              text: state.zones.isEmpty
                  ? 'Vous serez prévenu dès qu\'une commande est prête.'
                  : 'Vous serez prévenu dès qu\'une commande est prête dans '
                      'vos quartiers. Ajoutez des quartiers pour en recevoir '
                      'plus.',
            )
          else
            for (final o in offers.take(10))
              KitungaCourseCard(
                order: o,
                mine: false,
                onDetails: () => _openDetails(context, o),
                onAction: () async {
                  final taken = await kitungaTakeDelivery(context, o);
                  if (taken && context.mounted) {
                    await openDelivererMission(context, o);
                  }
                },
              ),
          // Statistiques détaillées : page « Mes performances ».
          _SectionTitle(
            title: 'Aperçu',
            action: 'Mes performances',
            onAction: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const DelivererPerformancePage())),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.task_alt_rounded,
                    color: _green,
                    value: '$delivered',
                    label: 'Livrées au total',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.report_gmailerrorred_rounded,
                    color: _red,
                    value: '$problems',
                    label: 'Annulées ou litiges',
                  ),
                ),
              ],
            ),
          ),
          _SectionTitle(
            title: 'Dernières courses',
            action: my.isEmpty ? null : 'Tout voir',
            onAction: () => context.pushNamed(OrderWidget.routeName),
          ),
          if (!loading && my.isEmpty)
            const _EmptyCard(
              icon: Icons.two_wheeler_rounded,
              title: 'Pas encore de course',
              text: 'Vos courses acceptées apparaîtront ici.',
            ),
          for (final o in my.take(5)) _RecentCourse(order: o),
          const _HelpCard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              'Gains calculés par Kitunga à chaque course livrée ; le '
              'détail et vos versements sont dans « Mes gains ».',
              style: GoogleFonts.inter(
                  fontSize: 11.5, color: theme.secondaryText),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

void _openDetails(BuildContext context, OrdersRecord o) {
  context.pushNamed(
    OrderViewSellerDeliverWidget.routeName,
    queryParameters: {
      'orderRefer': serializeParam(o.orderUniqueReference, ParamType.String),
      'deliveryZone': serializeParam(o.deliveryZone, ParamType.String),
      'statu': serializeParam(o.status, ParamType.String),
      'amount': serializeParam('${o.totalAmount}', ParamType.String),
    }.withoutNulls,
  );
}

// ── En-tête ──────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header(
      {required this.state,
      required this.feesToday,
      required this.coursesToday});

  final DelivererState state;
  final num feesToday;
  final int coursesToday;

  /// Bouton rond blanc de l'en-tête (menu, mode sombre).
  Widget _round(BuildContext context,
      {required Key key,
      required String tooltip,
      required IconData icon,
      Color? iconColor,
      required VoidCallback onTap}) {
    // Mêmes ronds que l'accueil client : blancs en clair, foncés en sombre.
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF1E242B) : Colors.white,
      shape: const CircleBorder(),
      child: IconButton(
        key: key,
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon,
            color: iconColor ??
                (dark ? Colors.white : const Color(0xFF1E242B)),
            size: 21),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final name = currentUserDisplayName.isNotEmpty
        ? currentUserDisplayName.split(' ').first
        : 'Livreur';
    final photo = currentUserPhoto;
    final verified =
        valueOrDefault<bool>(currentUserDocument?.verified, false);
    return Stack(
      children: [
        Container(
          height: top + 248,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_red, _redDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, top + 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Actions : menu à gauche ; mode sombre et notifications.
              Row(
                children: [
                  _round(context,
                    key: const ValueKey('deliverer-menu'),
                    tooltip: 'Menu',
                    icon: Icons.menu_rounded,
                    onTap: () => Scaffold.maybeOf(context)?.openDrawer(),
                  ),
                  const SizedBox(width: 10),
                  // Disponibilité, toujours visible en haut.
                  _StatePill(state: state),
                  const Spacer(),
                  _round(context,
                    key: const ValueKey('deliverer-theme'),
                    tooltip: dark ? 'Mode clair' : 'Mode sombre',
                    iconColor: dark ? const Color(0xFFFFD200) : null,
                    icon: dark
                        ? Icons.light_mode_rounded
                        : Icons.nightlight_round,
                    onTap: () => setDarkModeSetting(
                        context, dark ? ThemeMode.light : ThemeMode.dark),
                  ),
                  const SizedBox(width: 10),
                  const KitungaNotificationBell(size: 44),
                ],
              ),
              const SizedBox(height: 16),
              // 2. Identité et disponibilité.
              Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFFF1F4F8),
                          backgroundImage:
                              photo.isNotEmpty ? NetworkImage(photo) : null,
                          child: photo.isEmpty
                              ? const Icon(Icons.person_rounded,
                                  color: Color(0xFF8A94A6))
                              : null,
                        ),
                      ),
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: state.state == 'on'
                                ? const Color(0xFF2BD47D)
                                : state.state == 'pause'
                                    ? _yellow
                                    : const Color(0xFFB8BEC8),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bonjour, $name 👋',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.interTight(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                                verified
                                    ? Icons.verified_rounded
                                    : Icons.hourglass_top_rounded,
                                size: 14,
                                color: Colors.white),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                  [
                                    verified
                                        ? 'Livreur vérifié'
                                        : 'Vérification en attente',
                                    if (state.rating != null)
                                      '★ ${state.rating!.toStringAsFixed(1)} (${state.ratingCount})',
                                  ].join('  ·  '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                      color: Colors.white
                                          .withValues(alpha: 0.92),
                                      fontSize: 12.5)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 34),
              // 3. Chiffres du jour (cartes entières cliquables).
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _MoneyCard(
                        title: 'Gains du jour',
                        value: _fcfa(feesToday),
                        icon: Icons.account_balance_wallet_rounded,
                        colors: const [Color(0xFF2A2F3A), Color(0xFF151922)],
                        button: 'Mes gains',
                        onTap: () => openKitungaEarnings(context),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _MoneyCard(
                        title: 'Courses du jour',
                        value: '$coursesToday',
                        icon: Icons.two_wheeler_rounded,
                        colors: const [_yellow, _orange],
                        button: 'Historique',
                        onTap: () => context.pushNamed(OrderWidget.routeName),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pastille de disponibilité : ouvre le choix En service / En pause /
/// Hors service.
class _StatePill extends StatelessWidget {
  const _StatePill({required this.state});

  final DelivererState state;

  static const _labels = {
    'on': 'En service',
    'pause': 'En pause',
    'off': 'Hors service',
  };

  @override
  Widget build(BuildContext context) {
    final on = state.state == 'on';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        key: const ValueKey('deliverer-state-pill'),
        borderRadius: BorderRadius.circular(30),
        onTap: () => chooseDelivererState(context, state),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 15,
                padding: const EdgeInsets.all(2),
                alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: on ? _green : const Color(0xFFCBD2DC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 6),
              Text(_labels[state.state]!,
                  style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E242B))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Choix de la disponibilité (feuille du bas).
Future<void> chooseDelivererState(
    BuildContext context, DelivererState state) async {
  final chosen = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (key, label, hint, icon, color) in const [
            ('on', 'En service', 'Je reçois les nouvelles courses.',
                Icons.delivery_dining_rounded, _green),
            ('pause', 'En pause',
                'Pas de nouvelle course ; je termine mes courses en cours.',
                Icons.coffee_rounded, _orange),
            ('off', 'Hors service', 'Je ne travaille pas.',
                Icons.bedtime_outlined, Color(0xFF8A94A6)),
          ])
            ListTile(
              key: ValueKey('state-$key'),
              leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, color: color)),
              title: Text(label,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              subtitle: Text(hint),
              trailing: state.state == key
                  ? const Icon(Icons.check_circle_rounded, color: _green)
                  : null,
              onTap: () => Navigator.pop(c, key),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (chosen == null || chosen == state.state || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  try {
    await delivererCall('kitungaSetDelivererStatus', {'state': chosen});
    messenger.showSnackBar(SnackBar(
        content: Text(chosen == 'on'
            ? 'Vous êtes en service.'
            : chosen == 'pause'
                ? 'Vous êtes en pause.'
                : 'Vous êtes hors service.')));
  } on ServerPaymentException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Connexion impossible. Réessayez.')));
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.colors,
    required this.button,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final List<Color> colors;
  final String button;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
              color: Color(0x26000000), blurRadius: 16, offset: Offset(0, 6))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: Colors.white, size: 17),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(value,
                      style: GoogleFonts.interTight(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900)),
                ),
                const Spacer(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(button,
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// Course proposée en exclusivité : compte à rebours, Accepter / Refuser.
class KitungaOfferCard extends StatefulWidget {
  const KitungaOfferCard({required this.order});

  final OrdersRecord order;

  @override
  State<KitungaOfferCard> createState() => _KitungaOfferCardState();
}

class _KitungaOfferCardState extends State<KitungaOfferCard> {
  bool _busy = false;

  Future<void> _answer(bool accept) async {
    final mission = widget.order.snapshotData['offer_mission'];
    if (mission is! String) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    try {
      await delivererCall('kitungaRespondMission',
          {'missionId': mission, 'accept': accept});
      if (!mounted) return;
      if (accept) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Course acceptée. Bonne route !')));
        await openDelivererMission(context, widget.order);
      } else {
        messenger.showSnackBar(const SnackBar(
            content: Text('Course refusée : elle est proposée à un autre '
                'livreur.')));
      }
    } on ServerPaymentException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Connexion impossible. Réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final theme = FlutterFlowTheme.of(context);
    final until = offerExpiry(o);
    final left = until == null
        ? 0
        : until.difference(DateTime.now()).inSeconds.clamp(0, 600);
    final km = o.snapshotData['delivery_km'];
    final shopZone = '${o.snapshotData['shop_zone'] ?? ''}';
    return Container(
      key: ValueKey('offer-${o.reference.id}'),
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _red, width: 2),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33E51A1A), blurRadius: 18, offset: Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: _red),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Course proposée pour vous',
                    style: GoogleFonts.interTight(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryText)),
              ),
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: left / 60.0 > 1 ? 1 : left / 60.0,
                      strokeWidth: 4,
                      color: left <= 10 ? _red : _green,
                      backgroundColor: theme.alternate,
                    ),
                    Text('$left s',
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${shopZone.isEmpty ? 'Commerce' : shopZone} → '
                        '${o.deliveryZone.isEmpty ? 'Brazzaville' : o.deliveryZone}',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: theme.primaryText)),
                    if (km is num)
                      Text('≈ ${km.toStringAsFixed(1).replaceAll('.', ',')} km',
                          style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: theme.secondaryText)),
                  ],
                ),
              ),
              Text(_fcfa(o.deliveryFees),
                  style: GoogleFonts.interTight(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _green)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('offer-decline'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _red,
                    side: const BorderSide(color: _red),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _busy || left == 0 ? null : () => _answer(false),
                  child: const Text('Refuser'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: const ValueKey('offer-accept'),
                  style: FilledButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: _green,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _busy || left == 0 ? null : () => _answer(true),
                  child: Text('Accepter',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sections ─────────────────────────────────────────────────────────────

class _AvailabilityStrip extends StatelessWidget {
  const _AvailabilityStrip({required this.state});

  final DelivererState state;

  static const _vehicles = [
    ('moto', 'Moto', Icons.two_wheeler_rounded),
    ('voiture', 'Voiture', Icons.directions_car_rounded),
  ];

  Future<void> _save(BuildContext context, String name,
      Map<String, dynamic> data, String done) async {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    try {
      await delivererCall(name, data);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on ServerPaymentException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Enregistrement impossible. Réessayez.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget label(String t) => Text(t.toUpperCase(),
        style: GoogleFonts.inter(
            fontSize: 11,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
            color: theme.secondaryText));
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quartiers couverts.
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    label('Mes quartiers'),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 18, color: _red),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            state.zones.isEmpty
                                ? 'Toute la ville'
                                : state.zones.join(', '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.primaryText),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const ValueKey('deliverer-zones'),
                onPressed: () async {
                  final chosen =
                      await pickDelivererZones(context, state.zones);
                  if (chosen == null || !context.mounted) return;
                  await _save(context, 'kitungaSetDelivererStatus',
                      {'zones': chosen}, 'Quartiers enregistrés.');
                },
                child: const Text('Modifier',
                    style:
                        TextStyle(color: _red, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: theme.alternate),
          ),
          // Véhicule (capacité de courses simultanées).
          label('Mon véhicule'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final (key, text, icon) in _vehicles)
                ChoiceChip(
                  key: ValueKey('vehicle-$key'),
                  avatar: Icon(icon,
                      size: 18,
                      color: state.vehicle == key ? Colors.white : _red),
                  label: Text(text),
                  selected: state.vehicle == key,
                  selectedColor: _red,
                  backgroundColor: theme.primaryBackground,
                  side: BorderSide(
                      color: state.vehicle == key ? _red : theme.alternate),
                  showCheckmark: false,
                  labelStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: state.vehicle == key
                          ? Colors.white
                          : theme.primaryText),
                  onSelected: (_) => state.vehicle == key
                      ? null
                      : _save(context, 'kitungaSetVehicle', {'vehicle': key},
                          'Véhicule enregistré : $text.'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(
      {required this.title, this.trailing, this.action, this.onAction});

  final String title;
  final String? trailing;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 12, 6),
      child: Row(
        children: [
          Text(title,
              style: GoogleFonts.interTight(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryText)),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: _red, borderRadius: BorderRadius.circular(20)),
              child: Text(trailing!,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ],
          const Spacer(),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!,
                  style: const TextStyle(
                      color: _red, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.alternate),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: GoogleFonts.interTight(
                  fontSize: 26, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 12.5, color: theme.secondaryText)),
        ],
      ),
    );
  }
}

class _RecentCourse extends StatelessWidget {
  const _RecentCourse({required this.order});

  final OrdersRecord order;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final st = courseStatusOf(order);
    final at = order.createdAt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Material(
      color: theme.secondaryBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.alternate),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => order.status == OrderStatus.delivering
            ? openDelivererMission(context, order)
            : _openDetails(context, order),
        leading: CircleAvatar(
          backgroundColor: _red.withValues(alpha: 0.1),
          child: const Icon(Icons.shopping_bag_rounded, color: _red),
        ),
        title: Text(
            order.deliveryZone.isEmpty ? 'Brazzaville' : order.deliveryZone,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: theme.primaryText)),
        subtitle: Text(
            [
              'N° ${order.orderUniqueReference}',
              if (at != null) dateTimeFormatFr(at),
            ].join(' · '),
            style:
                GoogleFonts.inter(fontSize: 12, color: theme.secondaryText)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: st.color, borderRadius: BorderRadius.circular(20)),
              child: Text(st.label,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 4),
            Text(_fcfa(order.deliveryFees),
                style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: theme.primaryText)),
          ],
        ),
      ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(
      {required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.alternate),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _red.withValues(alpha: 0.08),
            child: Icon(icon, color: _red),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: theme.primaryText)),
                const SizedBox(height: 2),
                Text(text,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: theme.secondaryText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 13))),
        ]),
      );
}

/// Assistance : joindre l'équipe Kitunga (NTEMO CONSULTING).
class _HelpCard extends StatelessWidget {
  const _HelpCard();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final n = kCompanyPhones.first;
    Widget action(Key key, IconData icon, String label, Color color,
            VoidCallback onTap) =>
        Expanded(
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryText)),
                ],
              ),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 30, 20, 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent_rounded, color: _red, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Besoin d\'aide ?',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            color: theme.primaryText)),
                    Text('L\'équipe Kitunga vous répond.',
                        style: GoogleFonts.inter(
                            fontSize: 12.5, color: theme.secondaryText)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              action(
                  const ValueKey('deliverer-sos'),
                  Icons.sos_rounded,
                  'Urgence',
                  _red,
                  () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const DelivererSafetyPage()))),
              action(const ValueKey('deliverer-support'), Icons.forum_rounded,
                  'Écrire', const Color(0xFF2563EB),
                  () => openKitungaSupport(context)),
              action(const ValueKey('deliverer-call'), Icons.call_rounded,
                  'Appeler', _green, () => launchURL('tel:+242$n')),
              action(const ValueKey('deliverer-whatsapp'), Icons.chat_rounded,
                  'WhatsApp', const Color(0xFF25D366),
                  () => launchURL('https://wa.me/242$n')),
            ],
          ),
        ],
      ),
    );
  }
}


/// Bandeau d'état du compte (suspendu, documents).
class _AccountBanner extends StatelessWidget {
  const _AccountBanner({
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      key: const ValueKey('account-banner'),
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      decoration: BoxDecoration(
        color: _orange.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: _orange),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            color: theme.primaryText)),
                    Text(text,
                        style: GoogleFonts.inter(
                            fontSize: 12.5, color: theme.secondaryText)),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onTap, child: Text(action)),
          ),
        ],
      ),
    );
  }
}
