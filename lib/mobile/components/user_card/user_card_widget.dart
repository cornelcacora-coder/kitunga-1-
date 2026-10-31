import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'user_card_model.dart';
export 'user_card_model.dart';

class UserCardWidget extends StatefulWidget {
  const UserCardWidget({
    super.key,
    this.name,
    this.createdAt,
    this.badge,
    this.badgeBg,
    this.actionToUser,
    this.viewUser,
    this.userImg,
    this.isVerified,
    this.isUserConnected,
    this.iconCard,
    this.isNOC,
    this.subscribAmount,
    this.email,
  });

  final String? name;
  final DateTime? createdAt;
  final String? badge;
  final Color? badgeBg;
  final Future Function()? actionToUser;
  final Future Function()? viewUser;
  final String? userImg;
  final bool? isVerified;
  final bool? isUserConnected;
  final Widget? iconCard;
  final bool? isNOC;
  final String? subscribAmount;
  final String? email;

  @override
  State<UserCardWidget> createState() => _UserCardWidgetState();
}

class _UserCardWidgetState extends State<UserCardWidget> {
  late UserCardModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => UserCardModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () async {
        await widget.viewUser?.call();
      },
      child: Container(
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).primaryBackground,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: FlutterFlowTheme.of(context).primaryBackground,
            width: 1.0,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(10.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40.0,
                    height: 40.0,
                    decoration: BoxDecoration(
                      color: Color(0x22FFE500),
                      image: DecorationImage(
                        fit: BoxFit.cover,
                        image: Image.asset(
                          'assets/images/Gemini_Generated_Image_9i3o3n9i3o3n9i3o.png',
                        ).image,
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: AlignmentDirectional(0.0, 0.0),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      child: Image.network(
                        getCORSProxyUrl(
                          valueOrDefault<String>(
                            widget!.userImg,
                            'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/kitunga-xtvpe4/assets/h5ta1mt8rram/UserIcon.png',
                          ),
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(
                            valueOrDefault<String>(
                              widget!.name,
                              'Global Tech Store',
                            ),
                            maxLines: 1,
                            style: FlutterFlowTheme.of(context)
                                .labelLarge
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelLarge
                                        .fontStyle,
                                  ),
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelLarge
                                      .fontStyle,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget!.isVerified == true)
                            Icon(
                              Icons.check_circle,
                              color: FlutterFlowTheme.of(context).primary,
                              size: 18.0,
                            ),
                        ].divide(SizedBox(width: 5.0)),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (widget!.isUserConnected == true)
                            Container(
                              decoration: BoxDecoration(
                                color: widget!.badgeBg,
                                borderRadius: BorderRadius.circular(6.0),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(5.0),
                                child: Text(
                                  valueOrDefault<String>(
                                    widget!.badge,
                                    'VENDEUR',
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        color: Color(0xFFB8A600),
                                        fontSize: 10.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                              ),
                            ),
                          Text(
                            '•',
                            style: TextStyle(
                              color: FlutterFlowTheme.of(context).hint,
                            ),
                          ),
                          if ((widget!.isUserConnected == false) &&
                              (widget!.isNOC == false))
                            Text(
                              valueOrDefault<String>(
                                dateTimeFormat("yMMMd", widget!.createdAt),
                                '-',
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .fontStyle,
                                  ),
                            ),
                          if ((widget!.isUserConnected == false) &&
                              (widget!.isNOC == true))
                            Text(
                              valueOrDefault<String>(
                                widget!.email,
                                'testDeveoloper@gmail.com',
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .fontStyle,
                                  ),
                            ),
                        ].divide(SizedBox(width: 4.0)),
                      ),
                    ].divide(SizedBox(height: 5.0)),
                  ),
                ].divide(SizedBox(width: 20.0)),
              ),
              if (widget!.isNOC == true)
                Container(
                  width: 110.0,
                  decoration: BoxDecoration(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0x2339D2C0),
                      borderRadius: BorderRadius.circular(8.0),
                      shape: BoxShape.rectangle,
                    ),
                    child: Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(10.0, 4.0, 10.0, 4.0),
                      child: Container(
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              flex: 1,
                              child: Text(
                                valueOrDefault<String>(
                                  widget!.subscribAmount,
                                  '0F',
                                ),
                                maxLines: 1,
                                style: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontStyle,
                                      lineHeight: 1.2,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.check_circle_rounded,
                              color: FlutterFlowTheme.of(context).primaryText,
                              size: 20.0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Container(
                    width: 48.0,
                    height: 48.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    alignment: AlignmentDirectional(0.0, 0.0),
                    child: InkWell(
                      splashColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () async {
                        await widget.actionToUser?.call();
                      },
                      child: widget!.iconCard!,
                    ),
                  ),
                ].divide(SizedBox(width: 10.0)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
