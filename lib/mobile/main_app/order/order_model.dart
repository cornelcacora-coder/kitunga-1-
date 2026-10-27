import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/mobile/components/add_delivery_proof/add_delivery_proof_widget.dart';
import '/mobile/components/empty_card/empty_card_widget.dart';
import 'dart:ui';
import '/index.dart';
import 'order_widget.dart' show OrderWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class OrderModel extends FlutterFlowModel<OrderWidget> {
  ///  Local state fields for this page.

  List<OrdersRecord> order = [];
  void addToOrder(OrdersRecord item) => order.add(item);
  void removeFromOrder(OrdersRecord item) => order.remove(item);
  void removeAtIndexFromOrder(int index) => order.removeAt(index);
  void insertAtIndexInOrder(int index, OrdersRecord item) =>
      order.insert(index, item);
  void updateOrderAtIndex(int index, Function(OrdersRecord) updateFn) =>
      order[index] = updateFn(order[index]);

  bool inProgress = true;

  ///  State fields for stateful widgets in this page.

  // Model for EmptyCard component.
  late EmptyCardModel emptyCardModel;

  @override
  void initState(BuildContext context) {
    emptyCardModel = createModel(context, () => EmptyCardModel());
  }

  @override
  void dispose() {
    emptyCardModel.dispose();
  }
}
