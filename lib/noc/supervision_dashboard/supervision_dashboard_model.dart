import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/alert_card_widget.dart';
import '/components/delivery_story_widget.dart';
import '/components/order_comp_n_o_c_widget.dart';
import '/components/stat_comp_widget.dart';
import '/components/view_deliver_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/noc/n_o_c_alert/n_o_c_alert_widget.dart';
import '/noc/n_o_c_delivers/n_o_c_delivers_widget.dart';
import '/noc/n_o_c_delivery/n_o_c_delivery_widget.dart';
import '/noc/n_o_c_order_item_view/n_o_c_order_item_view_widget.dart';
import '/noc/n_o_c_orders/n_o_c_orders_widget.dart';
import '/noc/n_o_c_orders_delivered/n_o_c_orders_delivered_widget.dart';
import '/noc/n_o_c_sellers/n_o_c_sellers_widget.dart';
import '/noc/n_o_c_uers/n_o_c_uers_widget.dart';
import '/noc/noc_cta/noc_cta_widget.dart';
import 'dart:ui';
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'supervision_dashboard_widget.dart' show SupervisionDashboardWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class SupervisionDashboardModel
    extends FlutterFlowModel<SupervisionDashboardWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for Switch widget.
  bool? switchValue;
  // Model for StatComp component.
  late StatCompModel statCompModel1;
  // Model for StatComp component.
  late StatCompModel statCompModel2;
  // Model for StatComp component.
  late StatCompModel statCompModel3;
  // Model for StatComp component.
  late StatCompModel statCompModel4;
  // Models for OrderCompNOC dynamic component.
  late FlutterFlowDynamicModels<OrderCompNOCModel> orderCompNOCModels;
  // Models for DeliveryStory dynamic component.
  late FlutterFlowDynamicModels<DeliveryStoryModel> deliveryStoryModels;
  // Model for AlertCard.
  late AlertCardModel alertCardModel1;
  // Model for AlertCard.
  late AlertCardModel alertCardModel2;
  // Model for AlertCard.
  late AlertCardModel alertCardModel3;

  @override
  void initState(BuildContext context) {
    statCompModel1 = createModel(context, () => StatCompModel());
    statCompModel2 = createModel(context, () => StatCompModel());
    statCompModel3 = createModel(context, () => StatCompModel());
    statCompModel4 = createModel(context, () => StatCompModel());
    orderCompNOCModels = FlutterFlowDynamicModels(() => OrderCompNOCModel());
    deliveryStoryModels = FlutterFlowDynamicModels(() => DeliveryStoryModel());
    alertCardModel1 = createModel(context, () => AlertCardModel());
    alertCardModel2 = createModel(context, () => AlertCardModel());
    alertCardModel3 = createModel(context, () => AlertCardModel());
  }

  @override
  void dispose() {
    statCompModel1.dispose();
    statCompModel2.dispose();
    statCompModel3.dispose();
    statCompModel4.dispose();
    orderCompNOCModels.dispose();
    deliveryStoryModels.dispose();
    alertCardModel1.dispose();
    alertCardModel2.dispose();
    alertCardModel3.dispose();
  }
}
