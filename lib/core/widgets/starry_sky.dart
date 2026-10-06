import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Night-sky gradient with softly twinkling stars, painted behind the whole
/// app. Twinkling stops when the system asks for reduced motion.
class StarrySky extends StatefulWidget {
  const StarrySky({super.key, required this.child});

  final Widget child;

  @override
  State<StarrySky> createState() => _StarrySkyState();
}

class _StarrySkyState extends State<StarrySky> with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  final _stars = _Star.generate(70);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _twinkle.stop();
    } else if (!_twinkle.isAnimating) {
      _twinkle.repeat();
    }
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GnColors.skyTop, GnColors.skyBottom],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _StarPainter(_stars, _twinkle)),
            ),
          ),
          widget.child,
        ],
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
        _Star(r.nextDouble(), r.nextDouble(), 0.5 + r.nextDouble() * 1.3, r.nextDouble()),
    ];
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.stars, this.time) : super(repaint: time);

  final List<_Star> stars;
  final Animation<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in stars) {
      final glow = 0.35 + 0.65 * (0.5 + 0.5 * sin((time.value + s.phase) * 2 * pi));
      paint.color = Colors.white.withValues(alpha: glow * 0.8);
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}
