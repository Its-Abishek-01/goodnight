import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'cute_icons.dart';

/// One tab in the bar. [badge] shows a small count when above zero.
class MoonNavItem {
  const MoonNavItem(this.kind, this.label, {this.badge = 0});

  final CuteIconKind kind;
  final String label;
  final int badge;
}

/// Bottom bar with Tonight as a raised golden moon in the middle and the
/// other tabs split either side.
class MoonNavBar extends StatelessWidget {
  const MoonNavBar({
    super.key,
    required this.selected,
    required this.left,
    required this.right,
    required this.taps,
    required this.onSelect,
  });

  final CuteIconKind selected;
  final List<MoonNavItem> left;
  final List<MoonNavItem> right;

  /// Tap counters per tab, so a repeated tap replays the icon animation.
  final Map<CuteIconKind, int> taps;
  final ValueChanged<CuteIconKind> onSelect;

  static const _barHeight = 70.0;
  static const _moon = 68.0;

  void _tap(CuteIconKind k) {
    HapticFeedback.selectionClick();
    onSelect(k);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final moonOn = selected == CuteIconKind.tonight;
    return SizedBox(
      height: _barHeight + bottom + _moon / 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _barHeight + bottom,
            child: Container(
              padding: EdgeInsets.only(bottom: bottom),
              decoration: BoxDecoration(
                color: GnColors.skyBottom.withValues(alpha: 0.96),
                border: const Border(top: BorderSide(color: GnColors.outline, width: 0.6)),
              ),
              child: Row(
                children: [
                  for (final i in left) Expanded(child: _tab(context, i)),
                  const SizedBox(width: _moon + 20),
                  for (final i in right) Expanded(child: _tab(context, i)),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Semantics(
                button: true,
                selected: moonOn,
                label: 'Tonight',
                child: GestureDetector(
                  onTap: () => _tap(CuteIconKind.tonight),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _moon,
                    height: _moon,
                    decoration: BoxDecoration(
                      color: moonOn ? GnColors.moon : GnColors.surfaceHigh,
                      shape: BoxShape.circle,
                      border: Border.all(color: GnColors.skyBottom, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: GnColors.moon.withValues(alpha: moonOn ? 0.45 : 0.12),
                          blurRadius: moonOn ? 22 : 10,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: CuteIcon(
                      kind: CuteIconKind.tonight,
                      selected: moonOn,
                      size: 40,
                      taps: taps[CuteIconKind.tonight] ?? 0,
                      fillOverride: const Color(0xFFFFF1C9),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, MoonNavItem item) {
    final on = item.kind == selected;
    return Semantics(
      button: true,
      selected: on,
      label: item.label,
      child: InkResponse(
        onTap: () => _tap(item.kind),
        radius: 34,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CuteIcon(kind: item.kind, selected: on, taps: taps[item.kind] ?? 0),
                if (item.badge > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0628F),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: GnColors.skyBottom, width: 1.5),
                      ),
                      child: Text(
                        '${item.badge}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                fontSize: 11,
                color: on ? item.kind.color : GnColors.muted,
                fontWeight: on ? FontWeight.w700 : FontWeight.w400,
              ),
              child: Text(item.label, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}
