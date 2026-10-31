import '/backend/backend.dart';
import '/backend/order_status.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Une commande payée doit être remboursée si elle est refusée ou annulée.
Map<String, dynamic> kitungaRefundFields(OrdersRecord order) => {
      if (order.snapshotData['payment_status'] == 'Réussi')
        'refund_needed': true,
    };

/// Suivi d'une commande pour le client : statut, étapes, motif de refus,
/// annulation possible tant que le vendeur n'a pas accepté.
class KitungaOrderProgress extends StatelessWidget {
  const KitungaOrderProgress({
    super.key,
    required this.order,
    this.canCancel = false,
  });

  final OrdersRecord order;

  /// Le client peut annuler (affiché seulement si la commande est en attente).
  final bool canCancel;

  Future<void> _cancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Annuler la commande ?'),
        content: Text(
            'Le commerce sera prévenu. Si vous avez déjà payé, contactez le support Kitunga pour le remboursement (contact@ntemoconsulting.com).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('Garder la commande')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Annuler la commande',
                style: TextStyle(color: FlutterFlowTheme.of(context).error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await order.reference.update({
      'status': OrderStatus.cancelled,
      'status_updated_at': getCurrentTimestamp,
      ...kitungaRefundFields(order),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final status = order.status.isEmpty ? OrderStatus.pending : order.status;
    final color = OrderStatus.color(status);
    final step = OrderStatus.stepIndex(status);
    final reason = '${order.snapshotData['refusal_reason'] ?? ''}'.trim();

    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: theme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10.0,
                height: 10.0,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  OrderStatus.label(status),
                  style: GoogleFonts.interTight(
                    color: theme.primaryText,
                    fontSize: 17.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (order.createdAt != null)
                Text(
                  dateTimeFormat('d/M H:mm', order.createdAt),
                  style: GoogleFonts.inter(
                      color: theme.secondaryText, fontSize: 12.5),
                ),
            ],
          ),
          SizedBox(height: 14.0),
          if (step >= 0)
            Row(
              children: [
                for (var i = 0; i < OrderStatus.steps.length; i++) ...[
                  _dot(theme, i <= step, i == step, color),
                  if (i < OrderStatus.steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 3.0,
                        color: i < step ? color : theme.divider,
                      ),
                    ),
                ],
              ],
            ),
          if (step >= 0) ...[
            SizedBox(height: 6.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < OrderStatus.steps.length; i++)
                  Text(
                    OrderStatus.stepLabel(OrderStatus.steps[i]),
                    style: GoogleFonts.inter(
                      color:
                          i <= step ? theme.primaryText : theme.secondaryText,
                      fontSize: 11.0,
                      fontWeight: i == step ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
          if (status == OrderStatus.refused)
            Text(
              reason.isEmpty
                  ? 'Le commerce n\'a pas pu accepter votre commande.'
                  : 'Motif du commerce : $reason',
              style:
                  GoogleFonts.inter(color: theme.primaryText, fontSize: 13.5),
            ),
          if (OrderStatus.isStopped(status) &&
              order.snapshotData['refund_needed'] == true) ...[
            SizedBox(height: 6.0),
            Text(
              'Remboursement à traiter : contactez le support Kitunga (contact@ntemoconsulting.com) en indiquant votre numéro de commande.',
              style:
                  GoogleFonts.inter(color: theme.secondaryText, fontSize: 12.5),
            ),
          ],
          if (status == OrderStatus.notReceived) ...[
            SizedBox(height: 8.0),
            Text(
              'Vous avez signalé ne pas avoir reçu cette commande. Le support Kitunga va vous contacter.',
              style:
                  GoogleFonts.inter(color: theme.primaryText, fontSize: 13.0),
            ),
          ],
          if (canCancel && status == OrderStatus.pending) ...[
            SizedBox(height: 12.0),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () => _cancel(context),
                icon: Icon(Icons.close_rounded, color: theme.error),
                label: Text(
                  'Annuler la commande',
                  style: GoogleFonts.inter(
                      color: theme.error, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dot(FlutterFlowTheme theme, bool done, bool current, Color color) {
    return Container(
      width: current ? 22.0 : 16.0,
      height: current ? 22.0 : 16.0,
      decoration: BoxDecoration(
        color: done ? color : theme.secondaryBackground,
        shape: BoxShape.circle,
        border: Border.all(color: done ? color : theme.divider, width: 2.0),
      ),
      child: done
          ? Icon(Icons.check_rounded,
              size: current ? 14.0 : 10.0, color: Colors.white)
          : null,
    );
  }
}
