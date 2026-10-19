import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// The ring screen's sky: dusk purple warming to dawn while a smiling sun
/// climbs over soft hills, its rays slowly turning. [rise] (0..1) is how far
/// up the sun is; it takes about a minute.
class SunriseSky extends StatefulWidget {
  const SunriseSky({super.key, this.child});

  final Widget? child;

  @override
  State<SunriseSky> createState() => _SunriseSkyState();
}

class _SunriseSkyState extends State<SunriseSky> with TickerProviderStateMixin {
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..forward();
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void dispose() {
    _rise.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SunrisePainter(
        rise: CurvedAnimation(parent: _rise, curve: Curves.easeOutCubic),
        spin: _spin,
      ),
      child: widget.child,
    );
  }
}

class SunrisePainter extends CustomPainter {
  SunrisePainter({required this.rise, required this.spin}) : super(repaint: Listenable.merge([rise, spin]));

  final Animation<double> rise;
  final Animation<double> spin;

  static final _dusk = SkyColors.dusk.sky;
  static final _dawn = SkyColors.dawn.sky;
  static final _sun = SkyColors.dawn.accent;

  @override
  void paint(Canvas canvas, Size size) {
    final r = rise.value;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            for (var i = 0; i < 3; i++) Color.lerp(_dusk[i], _dawn[i], r * 0.85)!,
          ],
        ).createShader(rect),
    );

    // Fading stars at the top.
    final stars = Paint()..color = Colors.white.withValues(alpha: 0.7 * (1 - r));
    final rnd = math.Random(3);
    for (var i = 0; i < 28; i++) {
      final p = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height * 0.4);
      canvas.drawCircle(p, 0.8 + rnd.nextDouble() * 1.2, stars);
    }

    // The sun, climbing from behind the hills.
    final horizon = size.height * 0.62;
    final radius = size.width * 0.16;
    final c = Offset(size.width / 2, horizon + radius * 1.2 - (radius * 1.2 + size.height * 0.22) * r);
    canvas.drawCircle(c, radius * 2.4, Paint()..color = _sun.withValues(alpha: 0.12 + 0.1 * r));
    canvas.drawCircle(c, radius * 1.6, Paint()..color = _sun.withValues(alpha: 0.18));
    final rays = Paint()
      ..color = _sun.withValues(alpha: 0.75)
      ..strokeWidth = radius * 0.11
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6 + spin.value * 2 * math.pi;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * radius * 1.3,
        c + Offset(math.cos(a), math.sin(a)) * radius * 1.65,
        rays,
      );
    }
    canvas.drawCircle(c, radius, Paint()..color = _sun);
    // A sleepy-to-happy little face.
    final face = Paint()
      ..color = SkyColors.dawn.onAccent.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.07
      ..strokeCap = StrokeCap.round;
    for (final dx in [-0.35, 0.35]) {
      final e = c + Offset(dx * radius, -0.12 * radius);
      canvas.drawArc(Rect.fromCenter(center: e, width: radius * 0.28, height: radius * 0.22),
          r < 0.5 ? 0 : math.pi, math.pi, false, face);
    }
    canvas.drawArc(Rect.fromCenter(center: c + Offset(0, 0.18 * radius), width: radius * 0.5, height: radius * 0.34),
        0, math.pi, false, face);

    // Two layers of hills in front of the sun.
    void hill(double y, double amp, Color color) {
      final path = Path()..moveTo(0, size.height);
      path.lineTo(0, y);
      for (var i = 0; i <= 24; i++) {
        final x = size.width * i / 24;
        path.lineTo(x, y - amp * math.sin(i / 24 * math.pi * 1.6 + 0.4));
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    hill(horizon, size.height * 0.04, Color.lerp(const Color(0xFF6B3A78), const Color(0xFFE79A86), r)!);
    hill(horizon + size.height * 0.06, size.height * 0.03,
        Color.lerp(const Color(0xFF4A2A63), const Color(0xFFC9727A), r)!);
  }

  @override
  bool shouldRepaint(SunrisePainter old) => false;
}
