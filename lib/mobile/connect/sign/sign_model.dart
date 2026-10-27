import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/index.dart';
import 'sign_widget.dart' show SignWidget;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class SignModel extends FlutterFlowModel<SignWidget> {
  ///  State fields for stateful widgets in this page.

  final formKey2 = GlobalKey<FormState>();
  final formKey1 = GlobalKey<FormState>();
  // State field(s) for Subscrib_Typ_Business widget.
  String? subscribTypBusinessValue;
  FormFieldController<String>? subscribTypBusinessValueController;
  // State field(s) for UserType widget.
  String? userTypeValue;
  FormFieldController<String>? userTypeValueController;
  // State field(s) for Business_Name widget.
  FocusNode? businessNameFocusNode;
  TextEditingController? businessNameTextController;
  String? Function(BuildContext, String?)? businessNameTextControllerValidator;
  // State field(s) for Email_Business widget.
  FocusNode? emailBusinessFocusNode;
  TextEditingController? emailBusinessTextController;
  String? Function(BuildContext, String?)? emailBusinessTextControllerValidator;
  String? _emailBusinessTextControllerValidator(
      BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Please enter valid email address.';
    }

    if (!RegExp(kTextValidatorEmailRegex).hasMatch(val)) {
      return 'Please enter valid email address.';
    }
    return null;
  }

  // State field(s) for Phone_Business widget.
  FocusNode? phoneBusinessFocusNode;
  TextEditingController? phoneBusinessTextController;
  String? Function(BuildContext, String?)? phoneBusinessTextControllerValidator;
  // State field(s) for Category widget.
  String? categoryValue;
  FormFieldController<String>? categoryValueController;
  // State field(s) for Bio widget.
  FocusNode? bioFocusNode;
  TextEditingController? bioTextController;
  String? Function(BuildContext, String?)? bioTextControllerValidator;
  // State field(s) for Horraire widget.
  FocusNode? horraireFocusNode;
  TextEditingController? horraireTextController;
  String? Function(BuildContext, String?)? horraireTextControllerValidator;
  // State field(s) for Pwd_Business widget.
  FocusNode? pwdBusinessFocusNode;
  TextEditingController? pwdBusinessTextController;
  late bool pwdBusinessVisibility;
  String? Function(BuildContext, String?)? pwdBusinessTextControllerValidator;
  String? _pwdBusinessTextControllerValidator(
      BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Please enter valid password.';
    }

    return null;
  }

  // State field(s) for ConfPwd_Business widget.
  FocusNode? confPwdBusinessFocusNode;
  TextEditingController? confPwdBusinessTextController;
  late bool confPwdBusinessVisibility;
  String? Function(BuildContext, String?)?
      confPwdBusinessTextControllerValidator;
  // State field(s) for Certified widget.
  bool? certifiedValue;
  // State field(s) for Subscrib_Type_User widget.
  String? subscribTypeUserValue;
  FormFieldController<String>? subscribTypeUserValueController;
  // State field(s) for Display_Name widget.
  FocusNode? displayNameFocusNode;
  TextEditingController? displayNameTextController;
  String? Function(BuildContext, String?)? displayNameTextControllerValidator;
  String? _displayNameTextControllerValidator(
      BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Please ente valid first name';
    }

    return null;
  }

  // State field(s) for Email_User widget.
  FocusNode? emailUserFocusNode;
  TextEditingController? emailUserTextController;
  String? Function(BuildContext, String?)? emailUserTextControllerValidator;
  String? _emailUserTextControllerValidator(BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Please enter valid email address.';
    }

    if (!RegExp(kTextValidatorEmailRegex).hasMatch(val)) {
      return 'Please enter valid email address.';
    }
    return null;
  }

  // State field(s) for Phone_User widget.
  FocusNode? phoneUserFocusNode;
  TextEditingController? phoneUserTextController;
  String? Function(BuildContext, String?)? phoneUserTextControllerValidator;
  // State field(s) for Password_User widget.
  FocusNode? passwordUserFocusNode;
  TextEditingController? passwordUserTextController;
  late bool passwordUserVisibility;
  String? Function(BuildContext, String?)? passwordUserTextControllerValidator;
  String? _passwordUserTextControllerValidator(
      BuildContext context, String? val) {
    if (val == null || val.isEmpty) {
      return 'Please enter valid password.';
    }

    return null;
  }

  // State field(s) for ConfirmPassword_User widget.
  FocusNode? confirmPasswordUserFocusNode;
  TextEditingController? confirmPasswordUserTextController;
  late bool confirmPasswordUserVisibility;
  String? Function(BuildContext, String?)?
      confirmPasswordUserTextControllerValidator;

  @override
  void initState(BuildContext context) {
    emailBusinessTextControllerValidator =
        _emailBusinessTextControllerValidator;
    pwdBusinessVisibility = false;
    pwdBusinessTextControllerValidator = _pwdBusinessTextControllerValidator;
    confPwdBusinessVisibility = false;
    displayNameTextControllerValidator = _displayNameTextControllerValidator;
    emailUserTextControllerValidator = _emailUserTextControllerValidator;
    passwordUserVisibility = false;
    passwordUserTextControllerValidator = _passwordUserTextControllerValidator;
    confirmPasswordUserVisibility = false;
  }

  @override
  void dispose() {
    businessNameFocusNode?.dispose();
    businessNameTextController?.dispose();

    emailBusinessFocusNode?.dispose();
    emailBusinessTextController?.dispose();

    phoneBusinessFocusNode?.dispose();
    phoneBusinessTextController?.dispose();

    bioFocusNode?.dispose();
    bioTextController?.dispose();

    horraireFocusNode?.dispose();
    horraireTextController?.dispose();

    pwdBusinessFocusNode?.dispose();
    pwdBusinessTextController?.dispose();

    confPwdBusinessFocusNode?.dispose();
    confPwdBusinessTextController?.dispose();

    displayNameFocusNode?.dispose();
    displayNameTextController?.dispose();

    emailUserFocusNode?.dispose();
    emailUserTextController?.dispose();

    phoneUserFocusNode?.dispose();
    phoneUserTextController?.dispose();

    passwordUserFocusNode?.dispose();
    passwordUserTextController?.dispose();

    confirmPasswordUserFocusNode?.dispose();
    confirmPasswordUserTextController?.dispose();
  }
}
