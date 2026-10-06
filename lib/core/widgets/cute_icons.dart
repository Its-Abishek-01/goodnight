import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// The five bottom-bar icons. Each has its own pastel colour and a short
/// animation that plays when it is tapped.
enum CuteIconKind {
  tonight(Color(0xFFFDE29B)),
  week(Color(0xFFC9B8FF)),
  moments(Color(0xFFFFB7CF)),
  coupons(Color(0xFFFFC9A3)),
  us(Color(0xFFA8E6CF));

  const CuteIconKind(this.color);

  final Color color;
}

const _ink = Color(0xFF2B1B3A);
const _blush = Color(0xFFF7A1B5);
const _heart = Color(0xFFF0628F);
const _rose = Color(0xFFFFB7CF);
const _spark = Color(0xFFFDE29B);

/// Value at [t] of a keyframe track: (time, value) pairs, eased between.
double keyframe(double t, List<(double, double)> track) {
  if (t <= track.first.$1) return track.first.$2;
  for (var i = 1; i < track.length; i++) {
    final (t1, v1) = track[i];
    if (t <= t1) {
      final (t0, v0) = track[i - 1];
      final f = Curves.easeInOut.transform((t - t0) / (t1 - t0));
      return v0 + (v1 - v0) * f;
    }
  }
  return track.last.$2;
}

/// A cute icon that plays its animation each time [selected] turns true.
/// Reduced-motion settings skip the animation.
class CuteIcon extends StatefulWidget {
  const CuteIcon({
    super.key,
    required this.kind,
    required this.selected,
    this.size = 34,
    this.fillOverride,
    this.taps = 0,
  });

  final CuteIconKind kind;
  final bool selected;
  final double size;

  /// Fill used when selected instead of the icon's own colour (the moon
  /// button sits on gold, so its moon is drawn paler).
  final Color? fillOverride;

  /// Bumped on every tap, so tapping the current tab replays the animation.
  final int taps;

  @override
  State<CuteIcon> createState() => _CuteIconState();
}

class _CuteIconState extends State<CuteIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  @override
  void didUpdateWidget(CuteIcon old) {
    super.didUpdateWidget(old);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final tapped = widget.taps != old.taps || (widget.selected && !old.selected);
    if (widget.selected && tapped && !still) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: widget.selected ? 1.08 : 1,
      duration: const Duration(milliseconds: 250),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _CutePainter(
            widget.kind,
            widget.selected,
            _c.isAnimating ? _c.value : null,
            widget.fillOverride,
            muted: context.sky.muted,
            day: Theme.of(context).brightness == Brightness.light,
          ),
        ),
      ),
    );
  }
}

class _CutePainter extends CustomPainter {
  _CutePainter(this.kind, this.selected, this.t, this.fillOverride, {required this.muted, required this.day});

  /// Unselected line colour for the current time of day.
  final Color muted;

  /// By day the Tonight moon turns into a sun.

  final CuteIconKind kind;
  final bool selected;

  /// Animation progress, or null when resting.
  final double? t;
  final Color? fillOverride;
  final bool day;

  Color get fill => selected ? (fillOverride ?? kind.color) : muted.withValues(alpha: day ? 0.16 : 0.12);
  Color get line => selected ? _ink : muted;

  Paint _fill(Color c) => Paint()..color = c;
  Paint _stroke(double w, [Color? c]) => Paint()
    ..color = c ?? line
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _shape(Canvas c, Path p, {Color? fillColor, double w = 2.2}) {
    c.drawPath(p, _fill(fillColor ?? fill));
    c.drawPath(p, _stroke(w));
  }

  /// Rotates/scales [draw] around [pivot] (in the 32x32 icon space).
  void _around(Canvas c, Offset pivot, void Function() draw,
      {double angle = 0, double sx = 1, double sy = 1, Offset shift = Offset.zero}) {
    c.save();
    c.translate(pivot.dx + shift.dx, pivot.dy + shift.dy);
    c.rotate(angle);
    c.scale(sx, sy);
    c.translate(-pivot.dx, -pivot.dy);
    draw();
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 32);
    switch (kind) {
      case CuteIconKind.tonight:
        day ? _sun(canvas) : _tonight(canvas);
      case CuteIconKind.week:
        _week(canvas);
      case CuteIconKind.moments:
        _moments(canvas);
      case CuteIconKind.coupons:
        _coupons(canvas);
      case CuteIconKind.us:
        _us(canvas);
    }
  }

  double _deg(double d) => d * pi / 180;

  void _tonight(Canvas c) {
    final a = t == null ? 0.0 : keyframe(t!, [(0, 0), (.25, -14), (.55, 10), (.8, -4), (1, 0)]);
    _around(c, const Offset(15, 16), angle: _deg(a), () {
      final moon = Path()
        ..moveTo(24.5, 19.5)
        ..arcToPoint(const Offset(12.2, 6.4), radius: const Radius.circular(10.5), largeArc: true)
        ..arcToPoint(const Offset(24.5, 19.5), radius: const Radius.circular(8.3), clockwise: false)
        ..close();
      _shape(c, moon);
      c.drawPath(Path()..moveTo(11, 17.2)..quadraticBezierTo(12.3, 18.4, 13.6, 17.2), _stroke(1.8));
      c.drawCircle(const Offset(10, 20.3), 1.3, _fill(_blush));
    });
    // The "z" floats up and fades while the moon rocks.
    final zt = t;
    final opacity = zt == null ? 1.0 : keyframe(zt, [(0, 0), (.3, 1), (1, 0)]);
    if (opacity <= 0) return;
    final shift = zt == null ? Offset.zero : Offset(5 * zt, 4 - 14 * zt);
    final z = Path()
      ..moveTo(22, 5.5)
      ..lineTo(25.2, 5.5)
      ..lineTo(22, 8.9)
      ..lineTo(25.2, 8.9);
    _around(c, const Offset(23.6, 7.2), shift: shift, sx: zt == null ? 1 : .6 + .6 * zt, sy: zt == null ? 1 : .6 + .6 * zt, () {
      c.drawPath(z, _stroke(1.6, line.withValues(alpha: line.a * opacity)));
    });
  }

  /// Daytime Tonight icon: a happy sun. Tapping spins its rays and it bounces.
  void _sun(Canvas c) {
    final v = t ?? 0;
    final spin = t == null ? 0.0 : keyframe(v, [(0, 0), (1, 60)]);
    final bounce = t == null ? 1.0 : keyframe(v, [(0, 1), (.25, 1.15), (.5, .95), (.75, 1.05), (1, 1)]);
    const o = Offset(16, 16);
    _around(c, o, angle: _deg(spin), () {
      final ray = _stroke(2.2);
      for (var i = 0; i < 8; i++) {
        final a = i * pi / 4;
        c.drawLine(o + Offset(cos(a), sin(a)) * 10.2, o + Offset(cos(a), sin(a)) * 13.4, ray);
      }
    });
    _around(c, o, sx: bounce, sy: bounce, () {
      _shape(c, Path()..addOval(Rect.fromCircle(center: o, radius: 7.6)));
      final eye = _stroke(1.6);
      c.drawArc(Rect.fromCircle(center: const Offset(13.3, 15.4), radius: 1.2), pi, pi, false, eye);
      c.drawArc(Rect.fromCircle(center: const Offset(18.7, 15.4), radius: 1.2), pi, pi, false, eye);
      c.drawPath(Path()..moveTo(14.3, 18.2)..quadraticBezierTo(16, 19.8, 17.7, 18.2), _stroke(1.6));
      c.drawCircle(const Offset(11.8, 18.2), 1.1, _fill(_blush));
      c.drawCircle(const Offset(20.2, 18.2), 1.1, _fill(_blush));
    });
  }

  void _week(Canvas c) {
    final v = t ?? 0;
    final sx = t == null ? 1.0 : keyframe(v, [(0, 1), (.2, 1.1), (.5, .94), (.75, 1.05), (1, 1)]);
    final sy = t == null ? 1.0 : keyframe(v, [(0, 1), (.2, .88), (.5, 1.06), (.75, .95), (1, 1)]);
    final dy = t == null ? 0.0 : keyframe(v, [(0, 0), (.2, 0), (.5, -6), (.75, 0), (1, 0)]);
    final wink = t == null ? 1.0 : keyframe(v, [(0, 1), (.3, 1), (.45, .1), (.55, .1), (.7, 1), (1, 1)]);
    _around(c, const Offset(16, 27), sx: sx, sy: sy, shift: Offset(0, dy), () {
      _shape(c, Path()..addRRect(RRect.fromLTRBR(5, 7, 27, 27, const Radius.circular(6))));
      c.drawPath(Path()..moveTo(11, 4.5)..lineTo(11, 8.5)..moveTo(21, 4.5)..lineTo(21, 8.5), _stroke(2.2));
      c.drawLine(const Offset(5.5, 13), const Offset(26.5, 13), _stroke(1.8));
      c.drawCircle(const Offset(12.5, 18.5), 1.1, _fill(line));
      _around(c, const Offset(19.5, 18.5), sy: wink, () {
        c.drawCircle(const Offset(19.5, 18.5), 1.1, _fill(line));
      });
      c.drawPath(Path()..moveTo(14, 21.6)..quadraticBezierTo(16, 23.2, 18, 21.6), _stroke(1.7));
      c.drawCircle(const Offset(10.6, 21.2), 1.1, _fill(_blush));
      c.drawCircle(const Offset(21.4, 21.2), 1.1, _fill(_blush));
    });
  }

  void _moments(Canvas c) {
    final body = Path()
      ..moveTo(5, 12)
      ..arcToPoint(const Offset(9, 8), radius: const Radius.circular(4))
      ..lineTo(11.2, 8)
      ..lineTo(12.8, 5.6)
      ..lineTo(19.2, 5.6)
      ..lineTo(20.8, 8)
      ..lineTo(23, 8)
      ..arcToPoint(const Offset(27, 12), radius: const Radius.circular(4))
      ..lineTo(27, 21)
      ..arcToPoint(const Offset(23, 25), radius: const Radius.circular(4))
      ..lineTo(9, 25)
      ..arcToPoint(const Offset(5, 21), radius: const Radius.circular(4))
      ..close();
    _shape(c, body);
    c.drawCircle(const Offset(16, 16.5), 5, _fill(const Color(0xFFFFF4F8)));
    c.drawCircle(const Offset(16, 16.5), 5, _stroke(1.8));
    final beat = t == null ? 1.0 : keyframe(t!, [(0, 1), (.25, 1.35), (.5, .9), (.7, 1.15), (1, 1)]);
    _around(c, const Offset(16, 17), sx: beat, sy: beat, () {
      c.drawPath(heartPath(const Offset(16, 19.2), 1), _fill(_heart));
    });
    c.drawCircle(const Offset(23.3, 11.4), 1, _fill(line));
    if (t != null) {
      final o = keyframe(t!, [(0, 0), (.15, 1), (.6, 0), (1, 0)]);
      final s = keyframe(t!, [(0, .3), (.15, 1.4), (.6, 2), (1, 2)]);
      if (o > 0) {
        _around(c, const Offset(23.3, 6), sx: s, sy: s, () {
          final flash = Colors.white.withValues(alpha: o);
          c.drawCircle(const Offset(23.3, 6), 2.2, _fill(flash));
          c.drawPath(
            Path()
              ..moveTo(23.3, 1.6)
              ..lineTo(23.3, 3.2)
              ..moveTo(23.3, 8.8)
              ..lineTo(23.3, 10.4)
              ..moveTo(18.9, 6)
              ..lineTo(20.5, 6)
              ..moveTo(26.1, 6)
              ..lineTo(27.7, 6),
            _stroke(1.2, flash),
          );
        });
      }
    }
  }

  void _coupons(Canvas c) {
    _shape(c, Path()..addRRect(RRect.fromLTRBR(5.5, 13, 26.5, 26.5, const Radius.circular(4))));
    c.drawLine(const Offset(16, 13), const Offset(16, 26.5), _stroke(2));
    final v = t ?? 0;
    final dy = t == null ? 0.0 : keyframe(v, [(0, 0), (.3, -5), (.6, -2), (1, 0)]);
    final a = t == null ? 0.0 : keyframe(v, [(0, 0), (.3, -10), (.6, 6), (1, 0)]);
    _around(c, const Offset(16, 12), angle: _deg(a), shift: Offset(0, dy), () {
      _shape(c, Path()..addRRect(RRect.fromLTRBR(4, 9.5, 28, 14.5, const Radius.circular(2.5))));
      final bow = Path()
        ..moveTo(16, 9.2)
        ..cubicTo(14.5, 5.4, 10, 5.0, 10.4, 7.6)
        ..cubicTo(10.7, 9.4, 13.8, 9.4, 16, 9.2)
        ..close()
        ..moveTo(16, 9.2)
        ..cubicTo(17.5, 5.4, 22, 5.0, 21.6, 7.6)
        ..cubicTo(21.3, 9.4, 18.2, 9.4, 16, 9.2)
        ..close();
      _shape(c, bow, fillColor: _heart, w: 1.5);
    });
    if (t != null) {
      final o = keyframe(v, [(0, 0), (.4, 1), (1, 0)]);
      final s = keyframe(v, [(0, .2), (.4, 1.2), (1, .6)]);
      if (o > 0) {
        final p = _fill(_spark.withValues(alpha: o));
        c.drawPath(sparklePath(const Offset(6, 6.6), 2.6 * s), p);
        c.drawPath(sparklePath(const Offset(27, 4.9), 1.9 * s), p);
      }
    }
  }

  void _us(Canvas c) {
    final v = t ?? 0;
    final lean = t == null ? 0.0 : keyframe(v, [(0, 0), (.4, 1), (.7, 1), (1, 0)]);
    _around(c, const Offset(11, 25), angle: _deg(8 * lean), shift: Offset(1.5 * lean, 0), () {
      final body = Path()
        ..moveTo(4.5, 25.5)
        ..cubicTo(4.5, 20.5, 7.1, 17.2, 11.1, 17.2)
        ..cubicTo(15.1, 17.2, 17.7, 20.5, 17.7, 25.5)
        ..close();
      _shape(c, body, w: 2.1);
      _shape(c, Path()..addOval(Rect.fromCircle(center: const Offset(11.1, 12), radius: 4.4)), w: 2.1);
    });
    final second = selected ? _rose : fill;
    _around(c, const Offset(20, 25), angle: _deg(-8 * lean), shift: Offset(-1.5 * lean, 0), () {
      final body = Path()
        ..moveTo(14.6, 25.5)
        ..cubicTo(14.6, 21.1, 16.9, 18.3, 20.4, 18.3)
        ..cubicTo(23.9, 18.3, 26.2, 21.1, 26.2, 25.5)
        ..close();
      _shape(c, body, fillColor: second, w: 2.1);
      _shape(c, Path()..addOval(Rect.fromCircle(center: const Offset(20.4, 13.4), radius: 3.9)),
          fillColor: second, w: 2.1);
    });
    final rise = t == null ? 0.0 : keyframe(v, [(0, 0), (.4, -4), (.7, -3), (1, 0)]);
    final grow = t == null ? 1.0 : keyframe(v, [(0, 1), (.4, 1.5), (.7, 1.1), (1, 1)]);
    _around(c, const Offset(16, 6), sx: grow, sy: grow, shift: Offset(0, rise), () {
      c.drawPath(heartPath(const Offset(16, 7.6), 0.72), _fill(_heart));
    });
  }

  @override
  bool shouldRepaint(_CutePainter old) =>
      old.t != t ||
      old.selected != selected ||
      old.kind != kind ||
      old.fillOverride != fillOverride ||
      old.day != day ||
      old.muted != muted;
}

/// A small heart whose bottom tip is at [tip]; [s] = 1 is about 5 units wide.
Path heartPath(Offset tip, double s) {
  Offset p(double x, double y) => tip + Offset(x * s, y * s);
  final a = p(-1.2, -4.1), b = p(0, -3.5), d = p(1.2, -4.1);
  final c1 = p(-2.4, -1.5), c2 = p(-2.6, -3.6);
  final c3 = p(-0.6, -4.3), c4 = p(-0.2, -4.0);
  final c5 = p(0.2, -4.0), c6 = p(0.6, -4.3);
  final c7 = p(2.6, -3.6), c8 = p(2.4, -1.5);
  return Path()
    ..moveTo(tip.dx, tip.dy)
    ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, a.dx, a.dy)
    ..cubicTo(c3.dx, c3.dy, c4.dx, c4.dy, b.dx, b.dy)
    ..cubicTo(c5.dx, c5.dy, c6.dx, c6.dy, d.dx, d.dy)
    ..cubicTo(c7.dx, c7.dy, c8.dx, c8.dy, tip.dx, tip.dy)
    ..close();
}

/// A four-pointed sparkle centred on [o] with radius [r].
Path sparklePath(Offset o, double r) {
  final k = r * 0.3;
  return Path()
    ..moveTo(o.dx, o.dy - r)
    ..lineTo(o.dx + k, o.dy - k)
    ..lineTo(o.dx + r, o.dy)
    ..lineTo(o.dx + k, o.dy + k)
    ..lineTo(o.dx, o.dy + r)
    ..lineTo(o.dx - k, o.dy + k)
    ..lineTo(o.dx - r, o.dy)
    ..lineTo(o.dx - k, o.dy - k)
    ..close();
}
