import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'profile_field_group_child5_model.dart';
export 'profile_field_group_child5_model.dart';

class ProfileFieldGroupChild5Widget extends StatefulWidget {
  const ProfileFieldGroupChild5Widget({super.key});

  @override
  State<ProfileFieldGroupChild5Widget> createState() =>
      _ProfileFieldGroupChild5WidgetState();
}

class _ProfileFieldGroupChild5WidgetState
    extends State<ProfileFieldGroupChild5Widget> {
  late ProfileFieldGroupChild5Model _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileFieldGroupChild5Model());

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
