import '/backend/backend.dart';
import '/components/order_comp_n_o_c_widget.dart';
import '/components/view_deliver_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/noc/n_o_c_order_item_view/n_o_c_order_item_view_widget.dart';
import 'dart:ui';
import 'n_o_c_orders_delivered_widget.dart' show NOCOrdersDeliveredWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class NOCOrdersDeliveredModel
    extends FlutterFlowModel<NOCOrdersDeliveredWidget> {
  ///  State fields for stateful widgets in this component.

  // Models for OrderCompNOC dynamic component.
  late FlutterFlowDynamicModels<OrderCompNOCModel> orderCompNOCModels;

  @override
  void initState(BuildContext context) {
    orderCompNOCModels = FlutterFlowDynamicModels(() => OrderCompNOCModel());
  }

  @override
  void dispose() {
    orderCompNOCModels.dispose();
  }
}
