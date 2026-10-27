import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

class FlutterFlowIconButton extends StatelessWidget {
  const FlutterFlowIconButton({
    super.key,
    this.borderColor,
    this.borderRadius,
    this.borderWidth,
    this.buttonSize,
    this.fillColor,
    this.icon,
    this.iconData,
    this.onPressed,
    this.mouseCursor,
    this.splashColor,
    this.hoverColor,
    this.hoverBorderColor,
    this.hoverFillColor,
    this.disabledColor,
    this.disabledBorderColor,
    this.showLoadingIndicator = false,
  });

  final Color? borderColor;
  final double? borderRadius;
  final double? borderWidth;
  final double? buttonSize;
  final Color? fillColor;
  final Widget? icon;
  final IconData? iconData;
  final Function()? onPressed;
  final MouseCursor? mouseCursor;
  final Color? splashColor;
  final Color? hoverColor;
  final Color? hoverBorderColor;
  final Color? hoverFillColor;
  final Color? disabledColor;
  final Color? disabledBorderColor;
  final bool showLoadingIndicator;

  @override
  Widget build(context) {
    return Container(
      width: buttonSize ?? 40.0,
      height: buttonSize ?? 40.0,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(borderRadius ?? 8.0),
        border: Border.all(
          color: borderColor ?? Colors.transparent,
          width: borderWidth ?? 1.0,
        ),
      ),
      child: IconButton(
        icon: icon ??
            (iconData is FaIconData
                ? FaIcon(
                    iconData as FaIconData,
                    size: buttonSize != null ? buttonSize! * 0.5 : 20.0,
                  )
                : Icon(
                    iconData,
                    size: buttonSize != null ? buttonSize! * 0.5 : 20.0,
                  )),
        onPressed: onPressed,
        splashColor: splashColor,
        hoverColor: hoverColor,
      ),
    );
  }
}