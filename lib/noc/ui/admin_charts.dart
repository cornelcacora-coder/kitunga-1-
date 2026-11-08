import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'admin_kit.dart';

/// Graphiques de l'administration, dessinés sans bibliothèque externe.

/// Graduation « ronde » de l'axe vertical (0 à max, 4 intervalles).
({double max, double step}) niceScale(double maxValue, {int ticks = 4}) {
  if (maxValue <= 0) return (max: ticks.toDouble(), step: 1.0);
  final raw = maxValue / ticks;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final norm = raw / mag;
  final nice = norm <= 1
      ? 1.0
      : norm <= 2
          ? 2.0
          : norm <= 2.5
              ? 2.5
              : norm <= 5
                  ? 5.0
                  : 10.0;
  final step = math.max(nice * mag, 1.0);
  return (max: step * ticks, step: step);
}

/// Courbe lissée avec aire dégradée ; au survol ou au toucher, la valeur du
/// point le plus proche s'affiche.
class AdminAreaChart extends StatefulWidget {
  const AdminAreaChart({
    super.key,
    required this.values,
    required this.labels,
    this.color = AdminColors.red,
    this.height = 230.0,
    this.format,
    this.tooltipLabels,
  });

  final List<double> values;

  /// Libellés sous l'axe (souvent un sur deux affiché si nombreux).
  final List<String> labels;
  final Color color;
  final double height;
  final String Function(double v)? format;

  /// Libellé complet du point au survol (sinon [labels]).
  final List<String>? tooltipLabels;

  @override
  State<AdminAreaChart> createState() => _AdminAreaChartState();
}

class _AdminAreaChartState extends State<AdminAreaChart> {
  int? _hover;

  static const _left = 40.0;
  static const _bottom = 26.0;
  static const _top = 12.0;

  int? _indexAt(Offset p, Size size) {
    final n = widget.values.length;
    if (n == 0) return null;
    final w = size.width - _left;
    if (p.dx < _left - 10) return null;
    final x = (p.dx - _left).clamp(0.0, w);
    return n == 1 ? 0 : (x / w * (n - 1)).round().clamp(0, n - 1);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = widget.format ?? (v) => v.round().toString();
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, widget.height);
        final scale = niceScale(widget.values.fold(0.0, math.max));
        final i = _hover;
        Widget? tip;
        if (i != null && i < widget.values.length) {
          final n = widget.values.length;
          final w = size.width - _left;
          final h = size.height - _bottom - _top;
          final x = _left + (n == 1 ? w / 2 : w * i / (n - 1));
          final y = _top + h * (1 - widget.values[i] / scale.max);
          final label = (widget.tooltipLabels ?? widget.labels)[i];
          tip = Positioned(
            left: (x - 70).clamp(0.0, math.max(0.0, size.width - 140)),
            top: math.max(0.0, y - 62),
            child: IgnorePointer(
              child: Container(
                width: 140.0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF23262E),
                  borderRadius: BorderRadius.circular(AdminRadius.sm),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AdminText.label(
                            color: Colors.white70, size: 11.5)),
                    Text(fmt(widget.values[i]),
                        style: AdminText.strong(color: Colors.white)),
                  ],
                ),
              ),
            ),
          );
        }
        return MouseRegion(
          onHover: (e) => setState(() => _hover = _indexAt(e.localPosition, size)),
          onExit: (_) => setState(() => _hover = null),
          child: GestureDetector(
            onTapDown: (e) =>
                setState(() => _hover = _indexAt(e.localPosition, size)),
            onPanUpdate: (e) =>
                setState(() => _hover = _indexAt(e.localPosition, size)),
            child: Stack(
              children: [
                CustomPaint(
                  size: size,
                  painter: _AreaPainter(
                    values: widget.values,
                    labels: widget.labels,
                    color: widget.color,
                    max: scale.max,
                    step: scale.step,
                    hover: _hover,
                    format: fmt,
                  ),
                ),
                if (tip != null) tip,
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _AreaPainter extends CustomPainter {
  _AreaPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.max,
    required this.step,
    required this.hover,
    required this.format,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;
  final double max;
  final double step;
  final int? hover;
  final String Function(double) format;

  static const left = _AdminAreaChartState._left;
  static const bottom = _AdminAreaChartState._bottom;
  static const top = _AdminAreaChartState._top;

  void _text(Canvas canvas, String s, Offset at,
      {TextAlign align = TextAlign.left, double maxWidth = 60.0}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s, style: AdminText.label(color: AdminColors.faint, size: 11.0)),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    final dx = switch (align) {
      TextAlign.right => at.dx - tp.width,
      TextAlign.center => at.dx - tp.width / 2,
      _ => at.dx,
    };
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - left;
    final h = size.height - bottom - top;
    final grid = Paint()
      ..color = AdminColors.border
      ..strokeWidth = 1.0;

    // Grille horizontale et graduations.
    for (var v = 0.0; v <= max + 0.001; v += step) {
      final y = top + h * (1 - v / max);
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      _text(canvas, format(v), Offset(left - 8, y), align: TextAlign.right);
    }

    final n = values.length;
    if (n == 0) return;
    Offset pt(int i) => Offset(
        left + (n == 1 ? w / 2 : w * i / (n - 1)),
        top + h * (1 - (values[i] / max).clamp(0.0, 1.0)));

    // Libellés de l'axe horizontal, espacés pour rester lisibles.
    final every = math.max(1, (n / math.max(1, w ~/ 64)).ceil());
    for (var i = 0; i < n; i += every) {
      _text(canvas, labels[i], Offset(pt(i).dx, size.height - bottom / 2),
          align: TextAlign.center);
    }

    // Courbe lissée (Catmull-Rom → Bézier), sans dépasser les bornes.
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 0; i < n - 1; i++) {
      final p0 = pt(math.max(0, i - 1));
      final p1 = pt(i);
      final p2 = pt(i + 1);
      final p3 = pt(math.min(n - 1, i + 2));
      final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6,
          (p1.dy + (p2.dy - p0.dy) / 6).clamp(top, top + h));
      final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6,
          (p2.dy - (p3.dy - p1.dy) / 6).clamp(top, top + h));
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    final area = Path.from(path)
      ..lineTo(pt(n - 1).dx, top + h)
      ..lineTo(pt(0).dx, top + h)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, top, size.width, h)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );

    final i = hover;
    if (i != null && i < n) {
      final p = pt(i);
      canvas.drawLine(Offset(p.dx, top), Offset(p.dx, top + h),
          Paint()
            ..color = color.withValues(alpha: 0.25)
            ..strokeWidth = 1.5);
      canvas.drawCircle(p, 7.0, Paint()..color = Colors.white);
      canvas.drawCircle(p, 5.0, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_AreaPainter old) =>
      old.values != values || old.hover != hover || old.max != max;
}

typedef AdminDonutSlice = ({String label, double value, Color color});

/// Anneau de répartition avec total au centre et légende.
class AdminDonut extends StatelessWidget {
  const AdminDonut({
    super.key,
    required this.slices,
    required this.centerLabel,
    this.size = 170.0,
    this.thickness = 26.0,
  });

  final List<AdminDonutSlice> slices;
  final String centerLabel;
  final double size;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold(0.0, (s, e) => s + e.value);
    final shown = slices.where((s) => s.value > 0).toList();
    final ring = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(shown, total, thickness),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(total.round().toString(), style: AdminText.display()),
              Text(centerLabel, style: AdminText.label(size: 12.0)),
            ],
          ),
        ),
      ),
    );
    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Container(
                  width: 10.0,
                  height: 10.0,
                  decoration: BoxDecoration(
                      color: s.color, borderRadius: BorderRadius.circular(3.0)),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminText.label(color: AdminColors.text)),
                ),
                Text(s.value.round().toString(), style: AdminText.strong()),
                SizedBox(
                  width: 46.0,
                  child: Text(
                    total == 0 ? '' : '${(s.value * 100 / total).round()} %',
                    textAlign: TextAlign.right,
                    style: AdminText.label(color: AdminColors.faint, size: 12.0),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 340.0) {
        return Column(
          children: [ring, const SizedBox(height: 18.0), legend],
        );
      }
      return Row(
        children: [
          ring,
          const SizedBox(width: 28.0),
          Expanded(child: legend),
        ],
      );
    });
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.total, this.thickness);

  final List<AdminDonutSlice> slices;
  final double total;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(thickness / 2, thickness / 2,
        size.width - thickness, size.height - thickness);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = AdminColors.greySoft;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    if (total <= 0) return;
    // Petit espace entre les parts quand il y en a plusieurs.
    final gap = slices.length > 1 ? 0.035 : 0.0;
    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = s.value / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(0.0, sweep - gap),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.butt
          ..color = s.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.slices != slices || old.total != total;
}

/// Barre de progression arrondie (zones, objectifs).
class AdminBar extends StatelessWidget {
  const AdminBar(
      {super.key, required this.value, this.color = AdminColors.red});

  /// Entre 0 et 1.
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AdminRadius.pill),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 8.0,
        color: color,
        backgroundColor: AdminColors.greySoft,
      ),
    );
  }
}
