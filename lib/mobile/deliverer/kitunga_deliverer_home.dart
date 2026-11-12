import 'package:flutter/material.dart';
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
import '/mobile/components/kitunga_contact.dart' show kCompanyPhones;

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

class KitungaDelivererHome extends StatelessWidget {
  const KitungaDelivererHome({super.key});

  Stream<List<OrdersRecord>> _mine() =>
      delivererMyOrdersOverride ??
      queryOrdersRecord(
          queryBuilder: (o) => o.where('deliverer_ref', isEqualTo: currentUserUid));

  Stream<List<OrdersRecord>> _open() =>
      delivererOpenOrdersOverride ??
      queryOrdersRecord(
          queryBuilder: (o) =>
              o.where('status', whereIn: OrderStatus.forDeliverers));

  @override
  Widget build(BuildContext context) {
    return DelivererStateBuilder(
      builder: (context, state) => StreamBuilder<List<OrdersRecord>>(
        stream: _mine(),
        builder: (context, mineSnap) => StreamBuilder<List<OrdersRecord>>(
          stream: _open(),
          builder: (context, openSnap) => _DelivererHomeBody(
            state: state,
            mine: mineSnap.data,
            open: openSnap.data,
            offline: mineSnap.hasError || openSnap.hasError,
          ),
        ),
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
  });

  final DelivererState state;
  final List<OrdersRecord>? mine;
  final List<OrdersRecord>? open;
  final bool offline;

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
    final offers = [
      for (final o in open ?? const <OrdersRecord>[])
        if (o.status == OrderStatus.ready &&
            o.delivererRef.isEmpty &&
            delivererCovers(state.zones, o.deliveryZone))
          o
    ];
    final loading = mine == null || open == null;

    return RefreshIndicator(
      color: _red,
      onRefresh: () async =>
          Future<void>.delayed(const Duration(milliseconds: 400)),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _Header(state: state, feesToday: feesToday,
              coursesToday: doneToday.length),
          if (offline)
            const _Notice(
              icon: Icons.wifi_off_rounded,
              color: _orange,
              text: 'Connexion perdue. Les informations affichées peuvent '
                  'ne pas être à jour.',
            ),
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
          const _SectionTitle(title: 'Aperçu'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.task_alt_rounded,
                    color: _green,
                    value: '$delivered',
                    label: 'Livrées',
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
              'Les frais de livraison affichés sont ceux payés par les '
              'clients pour vos courses livrées aujourd\'hui.',
              style: GoogleFonts.inter(
                  fontSize: 11.5, color: theme.secondaryText),
            ),
          ),
        ],
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
  final double feesToday;
  final int coursesToday;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final name = currentUserDisplayName.isNotEmpty
        ? currentUserDisplayName.split(' ').first
        : 'Livreur';
    final photo = currentUserPhoto;
    final verified =
        valueOrDefault<bool>(currentUserDocument?.verified, false);
    return Stack(
      children: [
        Container(
          height: top + 196,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_red, _redDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, top + 14, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white24,
                        backgroundImage:
                            photo.isNotEmpty ? NetworkImage(photo) : null,
                        child: photo.isEmpty
                            ? const Icon(Icons.person_rounded,
                                color: Colors.white)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 13,
                          height: 13,
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bonjour, $name 👋',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.interTight(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800)),
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
                                  verified
                                      ? 'Livreur vérifié'
                                      : 'Vérification en attente',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                      color: Colors.white
                                          .withValues(alpha: 0.9),
                                      fontSize: 12.5)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _StatePill(state: state),
                      ],
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const KitungaNotificationBell(size: 36),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _MoneyCard(
                      title: 'Frais du jour',
                      value: _fcfa(feesToday),
                      colors: const [Color(0xFF2A2F3A), Color(0xFF151922)],
                      button: 'Mes courses',
                      onTap: () => context.pushNamed(OrderWidget.routeName),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MoneyCard(
                      title: 'Courses du jour',
                      value: '$coursesToday',
                      colors: const [_yellow, _orange],
                      button: 'Historique',
                      onTap: () => context.pushNamed(OrderWidget.routeName),
                    ),
                  ),
                ],
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
    required this.colors,
    required this.button,
    required this.onTap,
  });

  final String title;
  final String value;
  final List<Color> colors;
  final String button;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x26000000), blurRadius: 14, offset: Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              maxLines: 2,
              style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: GoogleFonts.interTight(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E242B),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onTap,
              child: Text(button,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ),
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

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.alternate),
      ),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, size: 20, color: _red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.zones.isEmpty
                  ? 'Mes quartiers : toute la ville'
                  : 'Mes quartiers : ${state.zones.join(', ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 13.5, color: theme.primaryText),
            ),
          ),
          TextButton(
            key: const ValueKey('deliverer-zones'),
            onPressed: () async {
              final chosen = await pickDelivererZones(context, state.zones);
              if (chosen == null || !context.mounted) return;
              final messenger = ScaffoldMessenger.of(context);
              try {
                await delivererCall(
                    'kitungaSetDelivererStatus', {'zones': chosen});
                messenger.showSnackBar(
                    const SnackBar(content: Text('Quartiers enregistrés.')));
              } catch (_) {
                messenger.showSnackBar(const SnackBar(
                    content: Text('Enregistrement impossible. Réessayez.')));
              }
            },
            child: const Text('Modifier',
                style: TextStyle(color: _red, fontWeight: FontWeight.w700)),
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
      padding: const EdgeInsets.fromLTRB(20, 22, 12, 4),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.support_agent_rounded, color: _red, size: 30),
          const SizedBox(width: 12),
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
          IconButton(
            tooltip: 'Appeler',
            onPressed: () => launchURL('tel:+242$n'),
            icon: const Icon(Icons.call_rounded, color: _red),
          ),
          IconButton(
            tooltip: 'WhatsApp',
            onPressed: () => launchURL('https://wa.me/242$n'),
            icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
          ),
        ],
      ),
    );
  }
}
