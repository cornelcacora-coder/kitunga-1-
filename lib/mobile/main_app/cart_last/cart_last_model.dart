import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/payment_method_widget.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import '/mobile/components/empty_card/empty_card_widget.dart';
import 'dart:ui';
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'cart_last_widget.dart' show CartLastWidget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CartLastModel extends FlutterFlowModel<CartLastWidget> {
  ///  Local state fields for this page.

  List<DocumentReference> cartItems = [];
  void addToCartItems(DocumentReference item) => cartItems.add(item);
  void removeFromCartItems(DocumentReference item) => cartItems.remove(item);
  void removeAtIndexFromCartItems(int index) => cartItems.removeAt(index);
  void insertAtIndexInCartItems(int index, DocumentReference item) =>
      cartItems.insert(index, item);
  void updateCartItemsAtIndex(
          int index, Function(DocumentReference) updateFn) =>
      cartItems[index] = updateFn(cartItems[index]);

  DocumentReference? orderRefs;

  bool emptyCart = false;

  String? zone;

  double deliveryFees = 2000.0;

  bool newPage = true;

  ///  State fields for stateful widgets in this page.

  List<CartRecord>? cartPreviousSnapshot;
  // State field(s) for Zone widget.
  String? zoneValue;
  FormFieldController<String>? zoneValueController;
  // State field(s) for location widget.
  FocusNode? locationFocusNode;
  TextEditingController? locationTextController;
  String? Function(BuildContext, String?)? locationTextControllerValidator;
  // Model for PaymentMethod.
  late PaymentMethodModel paymentMethodModel;
  // Stores action output result for [Backend Call - Create Document] action in Button widget.
  OrdersRecord? orderReference;

  @override
  void initState(BuildContext context) {
    paymentMethodModel = createModel(context, () => PaymentMethodModel());
  }

  @override
  void dispose() {
    locationFocusNode?.dispose();
    locationTextController?.dispose();

    paymentMethodModel.dispose();
  }
}
