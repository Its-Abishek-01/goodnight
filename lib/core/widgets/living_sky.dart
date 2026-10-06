import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Full-screen animated sky behind the whole app. Night has twinkling stars
/// and the odd shooting star; dusk and dawn have a low sun and fading stars;
/// day has a smiling sun with turning rays and drifting clouds. Changes of
/// phase glide over a couple of seconds. Reduced motion freezes it.
class LivingSky extends StatefulWidget {
  const LivingSky({super.key, required this.phase, required this.child});

  final SkyPhase phase;
  final Widget child;

  @override
  State<LivingSky> createState() => _LivingSkyState();
}

class _Look {
  const _Look(this.stars, this.sun, this.sunAlpha, this.sunColor, this.clouds, this.cloudColor);

  final double stars;

  /// Sun centre as a fraction of the screen.
  final Offset sun;
  final double sunAlpha;
  final Color sunColor;
  final double clouds;
  final Color cloudColor;

  static _Look of(SkyPhase p) => switch (p) {
        SkyPhase.night => const _Look(1, Offset(0.85, 1.15), 0, Color(0xFFFFB347), 0, Colors.white),
        SkyPhase.dusk => const _Look(0.45, Offset(0.18, 0.88), 1, Color(0xFFFF8A5C), 0.25, Color(0xFFFFC2C7)),
        SkyPhase.dawn => const _Look(0.12, Offset(0.80, 0.86), 1, Color(0xFFFFB066), 0.6, Color(0xFFFFE6EC)),
        // By day the journey shows the sun, so the sky's sun peeks from the corner.
        SkyPhase.day => const _Look(0, Offset(1.02, -0.02), 1, Color(0xFFFFC94D), 0.85, Colors.white),
      };
}

class _LivingSkyState extends State<LivingSky> with SingleTickerProviderStateMixin {
  // One slow clock drives twinkling, clouds, rays and shooting stars.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );
  final _stars = _Star.generate(80);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = _Look.of(widget.phase);
    // context.sky is lerped by the app's AnimatedTheme, so the gradient
    // glides between phases on its own.
    final colors = context.sky.sky;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: _AnimatedLook(
                target: target,
                builder: (look) => RepaintBoundary(
                  child: CustomPaint(
                    painter: _SkyPainter(
                      _stars,
                      _clock,
                      look,
                      shooting: widget.phase == SkyPhase.night,
                      rays: widget.phase == SkyPhase.day,
                    ),
                  ),
                ),
              ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// Animates every number of [_Look] toward [target].
class _AnimatedLook extends StatelessWidget {
  const _AnimatedLook({required this.target, required this.builder});

  final _Look target;
  final Widget Function(_Look) builder;

  @override
  Widget build(BuildContext context) {
    const d = Duration(milliseconds: 2400);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: target.stars),
      duration: d,
      builder: (_, stars, _) => TweenAnimationBuilder<Offset>(
        tween: Tween(end: target.sun),
        duration: d,
        curve: Curves.easeInOut,
        builder: (_, sun, _) => TweenAnimationBuilder<double>(
          tween: Tween(end: target.sunAlpha),
          duration: d,
          builder: (_, sunAlpha, _) => TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: target.sunColor),
            duration: d,
            builder: (_, sunColor, _) => TweenAnimationBuilder<double>(
              tween: Tween(end: target.clouds),
              duration: d,
              builder: (_, clouds, _) => TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: target.cloudColor),
                duration: d,
                builder: (_, cloudColor, _) => builder(
                  _Look(stars, sun, sunAlpha, sunColor!, clouds, cloudColor!),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Star {
  const _Star(this.x, this.y, this.radius, this.phase);

  final double x, y, radius, phase;

  /// Same sky every time, so stars do not jump around between screens.
  static List<_Star> generate(int count) {
    final r = Random(7);
    return [
      for (var i = 0; i < count; i++)
        _Star(r.nextDouble(), r.nextDouble() * 0.85, 0.5 + r.nextDouble() * 1.3, r.nextDouble()),
    ];
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.stars, this.clock, this.look, {required this.shooting, required this.rays})
      : super(repaint: clock);

  final List<_Star> stars;
  final Animation<double> clock;
  final _Look look;
  final bool shooting;
  final bool rays;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    if (look.stars > 0.01) _stars(canvas, size, t);
    if (shooting) _shootingStar(canvas, size, t);
    if (look.sunAlpha > 0.01) _sun(canvas, size, t);
    if (look.clouds > 0.01) _clouds(canvas, size, t);
  }

  void _stars(Canvas canvas, Size size, double t) {
    final paint = Paint();
    for (final s in stars) {
      // Twinkle ten times per minute, each star on its own beat.
      final glow = 0.35 + 0.65 * (0.5 + 0.5 * sin((t * 10 + s.phase) * 2 * pi));
      paint.color = Colors.white.withValues(alpha: glow * 0.8 * look.stars);
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.radius, paint);
    }
  }

  /// A streak across the top of the sky, once every 15 seconds.
  void _shootingStar(Canvas canvas, Size size, double t) {
    final cycle = (t * 4) % 1;
    if (cycle > 0.08) return;
    final p = cycle / 0.08;
    final round = (t * 4).floor();
    final startX = 0.15 + 0.5 * ((round * 37) % 10) / 10;
    final head = Offset((startX + 0.35 * p) * size.width, (0.08 + 0.12 * p) * size.height);
    final tail = head - Offset(0.12 * size.width, 0.04 * size.height);
    final fade = sin(p * pi);
    canvas.drawLine(
      tail,
      head,
      Paint()
        ..shader = LinearGradient(colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.9 * fade),
        ]).createShader(Rect.fromPoints(tail, head))
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _sun(Canvas canvas, Size size, double t) {
    final c = Offset(look.sun.dx * size.width, look.sun.dy * size.height);
    final r = size.width * 0.11;
    final a = look.sunAlpha;
    canvas.drawCircle(
      c,
      r * 3,
      Paint()
        ..shader = RadialGradient(colors: [
          look.sunColor.withValues(alpha: 0.45 * a),
          look.sunColor.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: r * 3)),
    );
    if (rays) {
      final ray = Paint()
        ..color = look.sunColor.withValues(alpha: 0.55 * a)
        ..strokeWidth = r * 0.16
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 12; i++) {
        final ang = t * 2 * pi + i * pi / 6;
        final dir = Offset(cos(ang), sin(ang));
        canvas.drawLine(c + dir * r * 1.3, c + dir * r * 1.75, ray);
      }
    }
    canvas.drawCircle(c, r, Paint()..color = look.sunColor.withValues(alpha: a));
    // A sleepy-happy face, like the icons.
    final face = Paint()
      ..color = const Color(0xFF7A3B00).withValues(alpha: 0.75 * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round;
    for (final dx in [-0.35, 0.35]) {
      canvas.drawArc(Rect.fromCircle(center: c + Offset(dx * r, -0.1 * r), radius: r * 0.16), pi, pi, false, face);
    }
    canvas.drawArc(Rect.fromCircle(center: c + Offset(0, 0.18 * r), radius: r * 0.22), 0.2, pi - 0.4, false, face);
    final blush = Paint()..color = const Color(0xFFFF8FA3).withValues(alpha: 0.6 * a);
    canvas.drawCircle(c + Offset(-0.55 * r, 0.2 * r), r * 0.12, blush);
    canvas.drawCircle(c + Offset(0.55 * r, 0.2 * r), r * 0.12, blush);
  }

  void _clouds(Canvas canvas, Size size, double t) {
    const clouds = [(0.10, 0.18, 1.0, 1), (0.55, 0.30, 0.75, 2), (0.30, 0.50, 0.6, 3)];
    final paint = Paint()..color = look.cloudColor.withValues(alpha: 0.75 * look.clouds);
    for (final (x0, y, scale, speed) in clouds) {
      final x = ((x0 + t * speed * 0.5) % 1.4) - 0.2;
      final c = Offset(x * size.width, y * size.height);
      final w = size.width * 0.16 * scale;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: w * 2.2, height: w * 0.7), Radius.circular(w)),
        paint,
      );
      canvas.drawCircle(c + Offset(-w * 0.35, -w * 0.3), w * 0.45, paint);
      canvas.drawCircle(c + Offset(w * 0.25, -w * 0.4), w * 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.look != look || old.shooting != shooting || old.rays != rays;
}
