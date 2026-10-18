import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The app's loading animation: two little love letters flutter in from
/// either side, meet in the middle and a heart floats up. Used everywhere
/// instead of a spinner.
class CuteLoader extends StatefulWidget {
  const CuteLoader({super.key, this.size = 72});

  /// Width; the height is three quarters of it.
  final double size;

  @override
  State<CuteLoader> createState() => _CuteLoaderState();
}

class _CuteLoaderState extends State<CuteLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paper = scheme.tertiary;
    final ink = Color.lerp(scheme.tertiary, scheme.onTertiary, 0.5)!;
    return Semantics(
      label: 'Loading',
      child: SizedBox(
        width: widget.size,
        height: widget.size * 0.75,
        child: CustomPaint(
          painter: LoveLetterPainter(_c, paper: paper, ink: ink),
        ),
      ),
    );
  }
}

/// Paints one frame of [CuteLoader]; [t] runs 0..1 and loops.
class LoveLetterPainter extends CustomPainter {
  LoveLetterPainter(this.t, {required this.paper, required this.ink}) : super(repaint: t);

  final Animation<double> t;
  final Color paper;
  final Color ink;

  static double _ease(double x) => x < 0.5 ? 2 * x * x : 1 - math.pow(-2 * x + 2, 2) / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    final w = size.width;
    final cy = size.height / 2;
    final env = w * 0.36;
    // Fly together for the first 60%, then rest while the heart floats up.
    final k = v < 0.6 ? _ease(v / 0.6) : 1.0;
    final away = 1 - k;
    final bob = math.sin(v * 12) * size.height * 0.03 * away;

    _envelope(canvas, Offset(w / 2 - w * 0.3 * away - env * 0.08 * k, cy + bob), env,
        -0.3 * away + 0.06 * math.sin(v * math.pi * 2));
    _envelope(canvas, Offset(w / 2 + w * 0.3 * away + env * 0.08 * k, cy - bob), env,
        0.4 * away + away * math.sin(v * 20) * 0.35);

    if (v > 0.6) {
      final p = (v - 0.6) / 0.4;
      _heart(
        canvas,
        Offset(w / 2, cy - env * 0.35 - size.height * 0.3 * p),
        env * (0.14 + 0.1 * p),
        paper.withValues(alpha: 1 - p),
      );
    }
  }

  void _envelope(Canvas canvas, Offset c, double w, double rot) {
    final h = w * 0.64;
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, w * 0.04)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      Radius.circular(w * 0.07),
    );
    canvas.drawRRect(body, Paint()..color = paper);
    canvas.drawRRect(body, stroke);
    // The flap and the two bottom folds.
    canvas.drawPath(
      Path()
        ..moveTo(-w / 2, -h / 2)
        ..lineTo(0, h * 0.05)
        ..lineTo(w / 2, -h / 2),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-w / 2, h / 2)
        ..lineTo(-w * 0.13, 0)
        ..moveTo(w / 2, h / 2)
        ..lineTo(w * 0.13, 0),
      stroke,
    );
    _heart(canvas, Offset(0, h * 0.02), w * 0.11, ink);
    canvas.restore();
  }

  void _heart(Canvas canvas, Offset c, double s, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy + s * 0.9)
      ..cubicTo(c.dx - s * 1.6, c.dy - s * 0.2, c.dx - s * 0.6, c.dy - s * 1.4, c.dx, c.dy - s * 0.4)
      ..cubicTo(c.dx + s * 0.6, c.dy - s * 1.4, c.dx + s * 1.6, c.dy - s * 0.2, c.dx, c.dy + s * 0.9);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(LoveLetterPainter old) => old.paper != paper || old.ink != ink;
}
