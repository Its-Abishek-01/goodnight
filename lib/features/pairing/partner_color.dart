import 'dart:typed_data';

import 'package:flutter/material.dart';

/// The colour each person picks for themselves. Stored on the pair as
/// `colors.{uid}` with the enum name, so both phones show the same colours.
enum PartnerColor {
  sky('Sky', Color(0xFF7FB2F0), Color(0xFF0C2A55)),
  rose('Rose', Color(0xFFF4A6C6), Color(0xFF5A1534)),
  lavender('Lavender', Color(0xFFC3B1F7), Color(0xFF2E2266)),
  mint('Mint', Color(0xFF8FDCC2), Color(0xFF0B4033)),
  peach('Peach', Color(0xFFFFBE98), Color(0xFF5C2A0E)),
  coral('Coral', Color(0xFFFF8F8F), Color(0xFF5C1414));

  const PartnerColor(this.label, this.color, this.onColor);

  final String label;
  final Color color;

  /// Readable text and icon colour on top of [color].
  final Color onColor;

  static PartnerColor? tryParse(String? key) {
    for (final c in values) {
      if (c.name == key) return c;
    }
    return null;
  }
}

/// A row of colour dots. [taken] marks the partner's colour so the two of
/// you can tell each other apart (it can still be picked).
class PartnerColorPicker extends StatelessWidget {
  const PartnerColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.taken,
  });

  final PartnerColor selected;
  final PartnerColor? taken;
  final ValueChanged<PartnerColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final c in PartnerColor.values)
          Semantics(
            button: true,
            selected: c == selected,
            label: c.label,
            child: GestureDetector(
              onTap: () => onChanged(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c == selected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: c == selected
                      ? [BoxShadow(color: c.color.withValues(alpha: 0.6), blurRadius: 14)]
                      : null,
                ),
                child: c == selected
                    ? Icon(Icons.check, color: c.onColor, size: 22)
                    : c == taken
                        ? Icon(Icons.favorite, color: c.onColor.withValues(alpha: 0.7), size: 16)
                        : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// A round avatar: the person's photo, or their initial, ringed in their
/// colour.
class PartnerAvatar extends StatelessWidget {
  const PartnerAvatar({
    super.key,
    required this.name,
    required this.color,
    this.size = 44,
    this.badge,
    this.photo,
  });

  final String name;
  final PartnerColor color;
  final double size;
  final Uint8List? photo;

  /// Small icon in the corner, for example a moon when asleep.
  final IconData? badge;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: photo == null ? Colors.white.withValues(alpha: 0.85) : color.color,
                width: photo == null ? 2 : size * 0.06 + 1,
              ),
              boxShadow: [BoxShadow(color: color.color.withValues(alpha: 0.45), blurRadius: 12)],
              image: photo == null
                  ? null
                  : DecorationImage(image: MemoryImage(photo!), fit: BoxFit.cover),
            ),
            alignment: Alignment.center,
            child: photo != null ? null : Text(
              initial,
              style: TextStyle(
                color: color.onColor,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.42,
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Color(0xFF1A1645), shape: BoxShape.circle),
                child: Icon(badge, size: size * 0.3, color: const Color(0xFFFDE29B)),
              ),
            ),
        ],
      ),
    );
  }
}
