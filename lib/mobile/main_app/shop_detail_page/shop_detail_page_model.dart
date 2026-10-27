import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/mobile/components/info_badge/info_badge_widget.dart';
import '/mobile/components/my_products_card/my_products_card_widget.dart';
import 'dart:ui';
import '/index.dart';
import 'shop_detail_page_widget.dart' show ShopDetailPageWidget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ShopDetailPageModel extends FlutterFlowModel<ShopDetailPageWidget> {
  ///  Local state fields for this page.

  String? filter;

  ///  State fields for stateful widgets in this page.

  // Model for InfoBadge component.
  late InfoBadgeModel infoBadgeModel1;
  // Model for InfoBadge component.
  late InfoBadgeModel infoBadgeModel2;
  // Model for InfoBadge component.
  late InfoBadgeModel infoBadgeModel3;
  // Models for MyProductsCard dynamic component.
  late FlutterFlowDynamicModels<MyProductsCardModel> myProductsCardModels;

  @override
  void initState(BuildContext context) {
    infoBadgeModel1 = createModel(context, () => InfoBadgeModel());
    infoBadgeModel2 = createModel(context, () => InfoBadgeModel());
    infoBadgeModel3 = createModel(context, () => InfoBadgeModel());
    myProductsCardModels =
        FlutterFlowDynamicModels(() => MyProductsCardModel());
  }

  @override
  void dispose() {
    infoBadgeModel1.dispose();
    infoBadgeModel2.dispose();
    infoBadgeModel3.dispose();
    myProductsCardModels.dispose();
  }
}
