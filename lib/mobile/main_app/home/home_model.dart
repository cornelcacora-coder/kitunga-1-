import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/shop_card_vertical_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/mobile/components/alert_info/alert_info_widget.dart';
import '/mobile/components/empty_card/empty_card_widget.dart';
import '/mobile/components/info_badge/info_badge_widget.dart';
import '/mobile/components/my_products_card/my_products_card_widget.dart';
import '/mobile/components/my_seller_card/my_seller_card_widget.dart';
import '/mobile/components/user_card/user_card_widget.dart';
import 'dart:math';
import 'dart:ui';
import '/index.dart';
import 'home_widget.dart' show HomeWidget;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HomeModel extends FlutterFlowModel<HomeWidget> {
  ///  Local state fields for this page.

  String? userFilter;

  String? productFilter;

  ///  State fields for stateful widgets in this page.

  // State field(s) for Carousel widget.
  CarouselSliderController? carouselController1;
  int carouselCurrentIndex1 = 1;

  // Models for ShopCardVertical dynamic component.
  late FlutterFlowDynamicModels<ShopCardVerticalModel> shopCardVerticalModels1;
  // Models for MySellerCard dynamic component.
  late FlutterFlowDynamicModels<MySellerCardModel> mySellerCardModels1;
  // Models for MySellerCard dynamic component.
  late FlutterFlowDynamicModels<MySellerCardModel> mySellerCardModels2;
  // Models for MySellerCard dynamic component.
  late FlutterFlowDynamicModels<MySellerCardModel> mySellerCardModels3;
  // Models for UserCard dynamic component.
  late FlutterFlowDynamicModels<UserCardModel> userCardModels1;
  // Model for InfoBadge component.
  late InfoBadgeModel infoBadgeModel1;
  // Model for InfoBadge component.
  late InfoBadgeModel infoBadgeModel2;
  // Model for InfoBadge component.
  late InfoBadgeModel infoBadgeModel3;
  // Models for MyProductsCard dynamic component.
  late FlutterFlowDynamicModels<MyProductsCardModel> myProductsCardModels;
  // State field(s) for Carousel widget.
  CarouselSliderController? carouselController2;
  int carouselCurrentIndex2 = 1;

  // Models for ShopCardVertical dynamic component.
  late FlutterFlowDynamicModels<ShopCardVerticalModel> shopCardVerticalModels2;
  // Models for MySellerCard dynamic component.
  late FlutterFlowDynamicModels<MySellerCardModel> mySellerCardModels4;
  // Models for MySellerCard dynamic component.
  late FlutterFlowDynamicModels<MySellerCardModel> mySellerCardModels5;
  // Models for MySellerCard dynamic component.
  late FlutterFlowDynamicModels<MySellerCardModel> mySellerCardModels6;
  // Models for UserCard dynamic component.
  late FlutterFlowDynamicModels<UserCardModel> userCardModels2;

  @override
  void initState(BuildContext context) {
    shopCardVerticalModels1 =
        FlutterFlowDynamicModels(() => ShopCardVerticalModel());
    mySellerCardModels1 = FlutterFlowDynamicModels(() => MySellerCardModel());
    mySellerCardModels2 = FlutterFlowDynamicModels(() => MySellerCardModel());
    mySellerCardModels3 = FlutterFlowDynamicModels(() => MySellerCardModel());
    userCardModels1 = FlutterFlowDynamicModels(() => UserCardModel());
    infoBadgeModel1 = createModel(context, () => InfoBadgeModel());
    infoBadgeModel2 = createModel(context, () => InfoBadgeModel());
    infoBadgeModel3 = createModel(context, () => InfoBadgeModel());
    myProductsCardModels =
        FlutterFlowDynamicModels(() => MyProductsCardModel());
    shopCardVerticalModels2 =
        FlutterFlowDynamicModels(() => ShopCardVerticalModel());
    mySellerCardModels4 = FlutterFlowDynamicModels(() => MySellerCardModel());
    mySellerCardModels5 = FlutterFlowDynamicModels(() => MySellerCardModel());
    mySellerCardModels6 = FlutterFlowDynamicModels(() => MySellerCardModel());
    userCardModels2 = FlutterFlowDynamicModels(() => UserCardModel());
  }

  @override
  void dispose() {
    shopCardVerticalModels1.dispose();
    mySellerCardModels1.dispose();
    mySellerCardModels2.dispose();
    mySellerCardModels3.dispose();
    userCardModels1.dispose();
    infoBadgeModel1.dispose();
    infoBadgeModel2.dispose();
    infoBadgeModel3.dispose();
    myProductsCardModels.dispose();
    shopCardVerticalModels2.dispose();
    mySellerCardModels4.dispose();
    mySellerCardModels5.dispose();
    mySellerCardModels6.dispose();
    userCardModels2.dispose();
  }
}
