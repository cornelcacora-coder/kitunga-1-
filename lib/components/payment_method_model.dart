import '/flutter_flow/flutter_flow_util.dart';
import 'payment_method_widget.dart' show PaymentMethodWidget;
import 'package:flutter/material.dart';

class PaymentMethodModel extends FlutterFlowModel<PaymentMethodWidget> {
  /// Mobile Money choisi (toujours vrai : MTN ou Airtel).
  bool? isMoMoValue;

  /// Opérateur choisi : 'MTN' ou 'Airtel'.
  String operator = 'MTN';

  /// Numéro qui paiera (modifiable par le client).
  final TextEditingController phoneController = TextEditingController();

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() => phoneController.dispose();
}
