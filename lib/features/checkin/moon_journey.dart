import 'dart:ui' show PathMetric;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../pairing/partner_color.dart';
import 'night_log.dart';

/// Where someone is in tonight's journey: awake at the foot of the arc,
/// asleep up by the moon, or back down in the morning.
enum JourneyStage { awake, asleep, up }

JourneyStage stageOf(PlayerNight p) {
  if (p.wokeAt != null) return JourneyStage.up;
  if (p.checkedInAt != null) return JourneyStage.asleep;
  return JourneyStage.awake;
}

/// Position along the arc (0 = left foot, 1 = right foot). You climb from
/// the left, your partner from the right, and you meet beside the moon.
double journeyT(JourneyStage stage, {required bool isMe}) {
  final climb = stage == JourneyStage.asleep ? 0.30 : 0.0;
  return isMe ? 0.06 + climb : 0.94 - climb;
}

String journeyCaption(JourneyStage me, JourneyStage partner, String partnerName) {
  final p = partnerName.isEmpty ? 'Your partner' : partnerName;
  if (me == JourneyStage.up && partner == JourneyStage.up) return 'Good morning, you two.';
  if (me == JourneyStage.asleep && partner == JourneyStage.asleep) {
    return 'You both reached the moon. Sleep well.';
  }
  if (partner == JourneyStage.asleep) return '$p is on the moon. Join them.';
  if (me == JourneyStage.asleep) return "You're on the moon. Waiting for $p.";
  if (partner == JourneyStage.up) return '$p is up already.';
  if (me == JourneyStage.up) return '$p is still asleep. Let them rest.';
  return 'Head for the moon together tonight.';
}

String _status(BuildContext context, PlayerNight p) {
  String t(DateTime d) => TimeOfDay.fromDateTime(d).format(context);
  return switch (stageOf(p)) {
    JourneyStage.up => 'up ${t(p.wokeAt!)}',
    JourneyStage.asleep => 'asleep ${t(p.checkedInAt!)}',
    JourneyStage.awake => 'awake',
  };
}

/// The two of you climbing a dotted arc to the moon as you check in.
class MoonJourney extends StatelessWidget {
  const MoonJourney({
    super.key,
    required this.me,
    required this.partner,
    required this.myName,
    required this.partnerName,
    required this.myColor,
    required this.partnerColor,
    this.myPhoto,
    this.partnerPhoto,
  });

  final PlayerNight me;
  final PlayerNight partner;
  final String myName;
  final String partnerName;
  final PartnerColor myColor;
  final PartnerColor partnerColor;
  final Uint8List? myPhoto;
  final Uint8List? partnerPhoto;

  static const _height = 230.0;
  static const _avatar = 46.0;

  @override
  Widget build(BuildContext context) {
    final myStage = stageOf(me);
    final theirStage = stageOf(partner);
    final together = myStage == JourneyStage.asleep && theirStage == JourneyStage.asleep;
    return Column(
      children: [
        SizedBox(
          height: _height,
          child: LayoutBuilder(builder: (context, box) {
            final size = Size(box.maxWidth, _height);
            final arc = _arc(size);
            Widget climber(PlayerNight p, String name, PartnerColor color, Uint8List? photo, bool isMe) {
              final stage = stageOf(p);
              return TweenAnimationBuilder<double>(
                tween: Tween(end: journeyT(stage, isMe: isMe)),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeInOutCubic,
                builder: (context, t, child) {
                  final at = _pointAt(arc, t);
                  return Positioned(
                    left: at.dx - 50,
                    top: at.dy - _avatar / 2,
                    width: 100,
                    child: child!,
                  );
                },
                child: Column(
                  children: [
                    PartnerAvatar(
                      name: name,
                      color: color,
                      photo: photo,
                      size: _avatar,
                      badge: switch (stage) {
                        JourneyStage.asleep => Icons.bedtime,
                        JourneyStage.up => Icons.wb_sunny,
                        JourneyStage.awake => null,
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isMe ? 'You' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      _status(context, p),
                      style: const TextStyle(color: GnColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              );
            }

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: together ? 1 : 0),
                    duration: const Duration(milliseconds: 1600),
                    curve: Curves.easeOut,
                    builder: (context, glow, _) =>
                        CustomPaint(painter: _ArcPainter(arc, _moonCenter(size), glow)),
                  ),
                ),
                climber(me, myName, myColor, myPhoto, true),
                climber(partner, partnerName, partnerColor, partnerPhoto, false),
              ],
            );
          }),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Text(
            journeyCaption(myStage, theirStage, partnerName),
            key: ValueKey('$myStage$theirStage'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: GnColors.muted, fontSize: 14),
          ),
        ),
      ],
    );
  }

  static Path _arc(Size s) => Path()
    ..moveTo(s.width * 0.10, s.height * 0.80)
    ..quadraticBezierTo(s.width * 0.5, -s.height * 0.32, s.width * 0.90, s.height * 0.80);

  static Offset _moonCenter(Size s) => Offset(s.width * 0.5, s.height * 0.20);

  static Offset _pointAt(Path arc, double t) {
    final PathMetric m = arc.computeMetrics().first;
    return m.getTangentForOffset(m.length * t.clamp(0.0, 1.0))!.position;
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.arc, this.moon, this.glow);

  final Path arc;
  final Offset moon;

  /// 0..1, how brightly the moon glows (full when you are both asleep).
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final dots = Paint()
      ..color = GnColors.outline
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final m in arc.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 12) {
        canvas.drawCircle(m.getTangentForOffset(d)!.position, 1.4, dots);
      }
    }

    const r = 30.0;
    final halo = 46.0 + 22.0 * glow;
    canvas.drawCircle(
      moon,
      halo,
      Paint()
        ..shader = RadialGradient(colors: [
          GnColors.moon.withValues(alpha: 0.18 + 0.27 * glow),
          GnColors.moon.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: moon, radius: halo)),
    );
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: moon, radius: r)),
      Path()..addOval(Rect.fromCircle(center: moon + const Offset(12, -9), radius: r * 0.9)),
    );
    canvas.drawPath(crescent, Paint()..color = GnColors.moon);
    final star = Paint()..color = GnColors.moon.withValues(alpha: 0.9);
    _sparkle(canvas, moon + const Offset(16, -2), 6, star);
    _sparkle(canvas, moon + const Offset(26, 10), 4, star);
  }

  void _sparkle(Canvas c, Offset o, double s, Paint p) {
    final k = s * 0.28;
    c.drawPath(
      Path()
        ..moveTo(o.dx, o.dy - s)
        ..lineTo(o.dx + k, o.dy - k)
        ..lineTo(o.dx + s, o.dy)
        ..lineTo(o.dx + k, o.dy + k)
        ..lineTo(o.dx, o.dy + s)
        ..lineTo(o.dx - k, o.dy + k)
        ..lineTo(o.dx - s, o.dy)
        ..lineTo(o.dx - k, o.dy - k)
        ..close(),
      p,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.glow != glow || old.moon != moon;
}
