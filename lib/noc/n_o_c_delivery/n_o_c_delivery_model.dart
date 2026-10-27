import '/backend/backend.dart';
import '/components/delivery_story_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'n_o_c_delivery_widget.dart' show NOCDeliveryWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class NOCDeliveryModel extends FlutterFlowModel<NOCDeliveryWidget> {
  ///  State fields for stateful widgets in this component.

  // Models for DeliveryStory dynamic component.
  late FlutterFlowDynamicModels<DeliveryStoryModel> deliveryStoryModels;

  @override
  void initState(BuildContext context) {
    deliveryStoryModels = FlutterFlowDynamicModels(() => DeliveryStoryModel());
  }

  @override
  void dispose() {
    deliveryStoryModels.dispose();
  }
}
