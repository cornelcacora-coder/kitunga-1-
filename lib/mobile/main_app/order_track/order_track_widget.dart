import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/order_status.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/mobile/components/delivery/kitunga_delivery.dart';
import '/mobile/components/order_progress/order_progress_widget.dart';
import '/mobile/components/support/kitunga_support.dart';
import '/mobile/main_app/order_view/order_view_widget.dart'
    show kitungaPageBar;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'order_track_model.dart';
export 'order_track_model.dart';

const _red = Color(0xFFE51A1A);
const _green = Color(0xFF1E9E5A);

/// Suivi d'une commande (client) : carte du livreur en direct, code de
/// remise, étapes ; une fois livrée, le client confirme la réception ou
/// signale qu'il ne l'a pas reçue.
class OrderTrackWidget extends StatefulWidget {
  const OrderTrackWidget({
    super.key,
    this.orderRef,
  });

  final DocumentReference? orderRef;

  static String routeName = 'Order_Track';
  static String routePath = '/orderTrack';

  @override
  State<OrderTrackWidget> createState() => _OrderTrackWidgetState();
}

class _OrderTrackWidgetState extends State<OrderTrackWidget> {
  bool _busy = false;

  Future<bool> _ask(String title, String text, String yes) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true), child: Text(yes)),
          ],
        ),
      ) ==
      true;

  /// Réception confirmée (« Reçu ») ou signalée absente (« Non Reçu » :
  /// le serveur ouvre alors une demande au support).
  Future<void> _answer(OrdersRecord o, bool received) async {
    final ok = received
        ? await _ask('Confirmer la réception',
            'Vous avez bien reçu toute votre commande ?', 'Oui, reçue')
        : await _ask(
            'Commande non reçue',
            'Nous allons ouvrir une réclamation et le support Kitunga vous '
                'recontactera rapidement.',
            'Signaler');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await o.reference.update(createOrdersRecordData(
          status: received ? OrderStatus.received : OrderStatus.notReceived));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(received
              ? 'Merci ! Réception confirmée.'
              : 'Réclamation envoyée au support Kitunga.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Impossible d\'enregistrer votre réponse. '
              'Vérifiez votre connexion et réessayez.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101418) : Colors.white,
      appBar: kitungaPageBar(context, 'Suivi de la commande'),
      body: StreamBuilder<OrdersRecord>(
        stream: OrdersRecord.getDocument(widget.orderRef!),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: _red));
          }
          final o = snap.data!;
          final mine = o.userRef == currentUserReference;
          final delivered = o.status == OrderStatus.delivered;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              // Carte du livreur en direct, code de remise, reçu.
              KitungaDeliveryExtras(order: o),
              const SizedBox(height: 12),
              KitungaOrderProgress(order: o, canCancel: mine),
              if (mine && delivered) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _green.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Votre commande a été livrée',
                          style: GoogleFonts.interTight(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: theme.primaryText)),
                      const SizedBox(height: 4),
                      Text('Confirmez la réception, ou signalez un problème.',
                          style: GoogleFonts.inter(
                              fontSize: 13.5, color: theme.secondaryText)),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : () => _answer(o, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: _green,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.check_circle_rounded),
                          label: Text('J\'ai reçu ma commande',
                              style: GoogleFonts.inter(
                                  fontSize: 15, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => _answer(o, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _red,
                            side: const BorderSide(color: _red),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text('Je ne l\'ai pas reçue',
                              style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (o.status == OrderStatus.received)
                _Banner(
                    color: _green,
                    icon: Icons.verified_rounded,
                    text: 'Réception confirmée. Merci d\'avoir commandé avec '
                        'Kitunga !'),
              if (o.status == OrderStatus.notReceived)
                const _Banner(
                    color: _red,
                    icon: Icons.report_rounded,
                    text: 'Réclamation en cours : le support Kitunga traite '
                        'votre signalement.'),
              const SizedBox(height: 16),
              Material(
                color: theme.secondaryBackground,
                borderRadius: BorderRadius.circular(18),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: theme.alternate)),
                  leading: const Icon(Icons.support_agent_rounded,
                      color: Color(0xFF2F6FDE)),
                  title: Text('Besoin d\'aide ?',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: theme.primaryText)),
                  subtitle: Text('Écrire au support à propos de cette commande',
                      style: GoogleFonts.inter(
                          fontSize: 12.5, color: theme.secondaryText)),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: theme.secondaryText),
                  onTap: () => openNewTicket(context,
                      orderId: o.reference.id,
                      orderRef: o.orderUniqueReference),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.text});

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: FlutterFlowTheme.of(context).primaryText)),
          ),
        ]),
      );
}
