import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Raccoon tail peeking from the screen edge — thick, bushy, with
/// alternating dark/light rings and a fluffy silhouette.
class RaccoonTailPainter extends CustomPainter {
  RaccoonTailPainter({
    required this.glowAlpha,
    required this.glowRadius,
    required this.bloomProgress,
    this.edge = TailEdge.right,
  });

  final double glowAlpha;
  final double glowRadius;
  final double bloomProgress;
  final TailEdge edge;

  // Raccoon tail palette
  static const _dark = Color(0xFF3C2415);    // dark brown ring
  static const _darkMid = Color(0xFF6B3A2A); // mid brown
  static const _light = Color(0xFFE8D5C0);   // cream ring
  static const _lightMid = Color(0xFFD4B896); // warm cream

  @override
  void paint(Canvas canvas, Size size) {
    final isRight = edge == TailEdge.right;
    final w = size.width;
    final h = size.height;
    final cy = h / 2;

    // Tail extends from screen edge inward
    const tailLen = 50.0; // total length
    const baseR = 16.0;   // radius at base (screen edge)
    const tipR = 7.0;     // radius at tip

    final double baseX, tipX;
    if (isRight) {
      baseX = w;
      tipX = w - tailLen;
    } else {
      baseX = 0;
      tipX = tailLen;
    }
    final dir = isRight ? -1.0 : 1.0;

    // --- Build tail body as a filled path ---------------------------------
    final body = Path();
    const segments = 40;
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final x = baseX + (tipX - baseX) * t;
      // Slight S-curve
      final yOff = math.sin(t * math.pi) * 6.0 + math.sin(t * math.pi * 2) * 3.0;
      // Radius tapers
      final r = baseR + (tipR - baseR) * t;
      // Fluffy edge: add small waviness
      final wave = math.sin(t * 16) * 1.5;
      final rr = r + wave;

      if (i == 0) {
        body.moveTo(x, cy - rr);
      } else {
        body.lineTo(x, cy - rr);
      }
      // store for bottom edge
    }
    // Bottom edge (reverse)
    for (var i = segments; i >= 0; i--) {
      final t = i / segments;
      final x = baseX + (tipX - baseX) * t;
      final yOff = math.sin(t * math.pi) * 6.0 + math.sin(t * math.pi * 2) * 3.0;
      final r = baseR + (tipR - baseR) * t;
      final wave = math.sin(t * 16) * 1.5;
      final rr = r + wave;
      body.lineTo(x, cy + rr);
    }
    body.close();

    // --- Glow ---------------------------------------------------------------
    if (glowAlpha > 0.01) {
      canvas.drawPath(
        body,
        Paint()
          ..color = AppTheme.orbGlow.withValues(alpha: glowAlpha * 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius),
      );
    }

    // --- Base fill ----------------------------------------------------------
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: isRight ? Alignment.centerLeft : Alignment.centerRight,
          end: isRight ? Alignment.centerRight : Alignment.centerLeft,
          colors: const [_darkMid, _lightMid],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // --- Raccoon rings (alternating dark bands) ----------------------------
    const ringCount = 5;
    canvas.save();
    canvas.clipPath(body);

    for (var i = 0; i < ringCount; i++) {
      // Rings spaced evenly along the tail
      final t = (i + 0.5) / ringCount;
      final rx = baseX + (tipX - baseX) * t;
      final rAt = baseR + (tipR - baseR) * t;
      final halfH = rAt * 1.6;

      // Dark band
      final bandRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(rx, cy + math.sin(t * math.pi) * 6.0),
          width: tailLen / ringCount * 1.1,
          height: halfH * 2,
        ),
        const Radius.circular(5),
      );

      // Draw dark ring with slight rotation for natural look
      canvas.save();
      canvas.translate(rx, cy + math.sin(t * math.pi) * 6.0);
      canvas.rotate(dir * (t - 0.5) * 0.3);
      canvas.translate(-rx, -(cy + math.sin(t * math.pi) * 6.0));

      final darkPaint = Paint()..color = i.isEven ? _dark : _darkMid;
      canvas.drawRRect(bandRect, darkPaint);

      // Lighter stripe adjacent
      final lightRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(rx + dir * tailLen / ringCount * 0.25,
              cy + math.sin(t * math.pi) * 6.0),
          width: tailLen / ringCount * 0.45,
          height: halfH * 1.7,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        lightRect,
        Paint()..color = _light.withValues(alpha: 0.55),
      );

      canvas.restore();
    }
    canvas.restore();

    // --- Tip highlight ------------------------------------------------------
    canvas.save();
    canvas.clipPath(body);
    canvas.drawCircle(
      Offset(tipX, cy),
      tipR + 2,
      Paint()
        ..color = AppTheme.orbGlow.withValues(alpha: 0.2 + bloomProgress * 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.restore();

    // --- Fine outline -------------------------------------------------------
    canvas.drawPath(
      body,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08 + bloomProgress * 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(RaccoonTailPainter old) =>
      glowAlpha != old.glowAlpha ||
      glowRadius != old.glowRadius ||
      bloomProgress != old.bloomProgress;
}

enum TailEdge { left, right }
