import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'profile_field_group_child2_model.dart';
export 'profile_field_group_child2_model.dart';

class ProfileFieldGroupChild2Widget extends StatefulWidget {
  const ProfileFieldGroupChild2Widget({super.key});

  @override
  State<ProfileFieldGroupChild2Widget> createState() =>
      _ProfileFieldGroupChild2WidgetState();
}

class _ProfileFieldGroupChild2WidgetState
    extends State<ProfileFieldGroupChild2Widget> {
  late ProfileFieldGroupChild2Model _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileFieldGroupChild2Model());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.0,
      height: 0.0,
    );
  }
}
