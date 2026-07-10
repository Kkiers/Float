import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Menu item definition
// ---------------------------------------------------------------------------

class OrbMenuItem {
  final IconData icon;
  final String label;
  final Color color;

  const OrbMenuItem(this.icon, this.label, this.color);
}

const List<OrbMenuItem> orbMenuItems = [
  OrbMenuItem(Icons.mic, '语音', Color(0xFFEF5350)),            // top
  OrbMenuItem(Icons.edit_note, '文字', Color(0xFF66BB6A)),      // right
  OrbMenuItem(Icons.content_paste, '剪贴板', Color(0xFF42A5F5)),  // bottom
  OrbMenuItem(Icons.crop, '截图', Color(0xFFFFA726)),           // left
];

// ---------------------------------------------------------------------------
// Radial menu widget
// ---------------------------------------------------------------------------

class OrbRadialMenu extends StatelessWidget {
  const OrbRadialMenu({
    super.key,
    required this.bloomProgress,
    required this.highlightedSector,
    required this.orbCenter,
    this.onTapIcon,
  });

  /// 0 → 1 bloom progress.
  final double bloomProgress;

  /// -1 = none, 0-3 = highlighted sector.
  final int highlightedSector;

  /// Centre of the orb in local coords.
  final Offset orbCenter;

  /// Called when user taps a specific icon (for tap-to-select).
  final void Function(int sector)? onTapIcon;

  /// Radius of the icon ring, in logical pixels.
  double get _radius => 82.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(orbMenuItems.length, (i) {
        final targetAngle = _targetAngle(i);
        final isHighlighted = i == highlightedSector;

        // Rotation animation: all icons start from 180° (straight left) and sweep outward
        final startAngle = pi; // 180° — straight left
        final angleDelta = targetAngle - startAngle;
        // Normalize to shortest path
        final shortest = _shortestAngleDelta(angleDelta);
        final currentAngle = pi + shortest * _easeOutBack(bloomProgress);

        final distance = _radius * bloomProgress;
        final dx = cos(currentAngle) * distance;
        final dy = sin(currentAngle) * distance;

        final iconSize = 30.0 + (isHighlighted ? 6.0 : 0.0);

        return Positioned(
          left: orbCenter.dx - iconSize / 2 + dx,
          top: orbCenter.dy - iconSize / 2 + dy,
          child: GestureDetector(
            onTap: onTapIcon != null ? () => onTapIcon!(i) : null,
            child: _RadialIcon(
              item: orbMenuItems[i],
              isHighlighted: isHighlighted,
              bloomProgress: bloomProgress,
              size: iconSize,
            ),
          ),
        );
      }),
    );
  }

  /// Target angle for each sector — half-circle fanning out LEFT from the orb:
  /// 0 = top-left (🎤), 1 = upper-left (📝), 2 = lower-left (📋), 3 = bottom-left (📷)
  static double _targetAngle(int index) {
    // Left-facing half-circle spanning ~140° from 110° to 250°
    const targets = [250 * pi / 180, 205 * pi / 180, 155 * pi / 180, 110 * pi / 180];
    return targets[index];
  }

  /// Normalize delta to shortest path within [-π, π].
  static double _shortestAngleDelta(double delta) {
    var d = delta % (2 * pi);
    if (d > pi) d -= 2 * pi;
    if (d < -pi) d += 2 * pi;
    return d;
  }

  /// Custom easing: slow start, overshoot, settle — for the "sweep" feel.
  static double _easeOutBack(double t) {
    const c1 = 1.2;
    final t1 = t - 1;
    return t1 * t1 * ((c1 + 1) * t1 + c1) + 1;
  }

  /// Detect which sector [localOffset] (relative to [center]) falls into.
  /// Only the LEFT half-circle (away from screen edge) is active.
  /// Returns -1 in dead zone, 0-3 for a valid sector.
  static int detectSector(Offset localOffset, Offset center) {
    final delta = localOffset - center;
    final distance = delta.distance;

    if (distance < 24) return -1;
    if (distance > 115) return -1;

    final angle = atan2(delta.dy, delta.dx);
    final deg = angle * 180 / pi; // -180..180

    // Half-circle on left side: from -145° to 145°
    // Sector 0 🎤: -145° .. -95°
    // Sector 1 📝: -95° .. -15°
    // Sector 2 📋: 15° .. 95°
    // Sector 3 📷: 95° .. 145°
    if (deg >= -145 && deg < -95) return 0;
    if (deg >= -95 && deg < -15) return 1;
    if (deg >= 15 && deg < 95) return 2;
    if (deg >= 95 && deg < 145) return 3;
    return -1; // outside the half-circle (right side = screen edge)
  }
}

// ---------------------------------------------------------------------------
// Single radial icon
// ---------------------------------------------------------------------------

class _RadialIcon extends StatelessWidget {
  const _RadialIcon({
    required this.item,
    required this.isHighlighted,
    required this.bloomProgress,
    required this.size,
  });

  final OrbMenuItem item;
  final bool isHighlighted;
  final double bloomProgress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final opacity = bloomProgress.clamp(0.0, 1.0);
    final scale = isHighlighted ? 1.2 : 1.0;

    return Transform.scale(
      scale: scale * opacity,
      child: Opacity(
        opacity: opacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isHighlighted
                    ? item.color.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                  color: isHighlighted
                      ? item.color.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.1),
                  width: isHighlighted ? 1.5 : 0.8,
                ),
                boxShadow: isHighlighted
                    ? [
                        BoxShadow(
                          color: item.color.withValues(alpha: 0.25),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                item.icon,
                color: isHighlighted
                    ? item.color
                    : AppTheme.orbTextOnGlass.withValues(alpha: 0.7),
                size: size * 0.55,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                color: isHighlighted
                    ? item.color
                    : AppTheme.orbTextOnGlass.withValues(alpha: 0.45),
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
