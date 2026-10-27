import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/mobile/components/item/item_widget.dart';
import 'dart:ui';
import '/index.dart';
import 'dart:math' as math;
import 'onboarding_widget.dart' show OnboardingWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class OnboardingModel extends FlutterFlowModel<OnboardingWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for item component.
  late ItemModel itemModel1;
  // Model for item component.
  late ItemModel itemModel2;

  @override
  void initState(BuildContext context) {
    itemModel1 = createModel(context, () => ItemModel());
    itemModel2 = createModel(context, () => ItemModel());
  }

  @override
  void dispose() {
    itemModel1.dispose();
    itemModel2.dispose();
  }
}
