// PRODUCTION-READY AR-Anchored Scan Painter
// 
// Uses device rotation (gyro heading) to project 3D world-space points
// back onto the screen. Points stay "anchored" in the real world — when
// you move the phone, they appear to stay in place like real AR.
//
// Features:
// - AR-like persistence (points anchored in world space)
// - Catmull-Rom smooth curves (butter-smooth path)
// - 3-layer neon glow blue line
// - Live distance labels with unit conversion
// - Correct coordinate alignment (no inverted axes)
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/scan_point_model.dart';
import '../utils/app_colors.dart';

class ScanPainter extends CustomPainter {
  final ScanPoint? startPoint;
  final ScanPoint? endPoint;
  final List<ScanPoint> autoPoints;
  final String distanceUnit;

  // Current device rotation from gyroscope (radians)
  final double deviceRotationY; // Yaw — left/right heading
  final double deviceRotationX; // Pitch — up/down tilt (NEW)

  // Visual config
  static const double manualPinRadius = 12.0;
  static const double autoPinRadius = 3.5;
  static const double lineWidth = 5.0;
  static const double glowWidth = 14.0;
  static const double pixelsPerMeter = 200.0;

  ScanPainter({
    this.startPoint,
    this.endPoint,
    required this.autoPoints,
    this.distanceUnit = 'm',
    this.deviceRotationY = 0.0,
    this.deviceRotationX = 0.0, // NEW: pitch rotation
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (startPoint == null) return;

    final allPoints = <ScanPoint>[startPoint!];
    allPoints.addAll(autoPoints);
    if (endPoint != null) allPoints.add(endPoint!);

    if (allPoints.length < 2) {
      _drawManualPin(canvas, size, startPoint!, isStart: true);
      return;
    }

    _drawSmoothPath(canvas, size, allPoints);

    for (final point in autoPoints) {
      _drawAutoPoint(canvas, size, point);
    }

    _drawManualPin(canvas, size, startPoint!, isStart: true);
    if (endPoint != null) {
      _drawManualPin(canvas, size, endPoint!, isStart: false);
    }
  }

  /// Draw smooth path with 3-layer neon glow + distance labels
  void _drawSmoothPath(Canvas canvas, Size size, List<ScanPoint> points) {
    if (points.length < 2) return;

    final screenPoints = points.map((p) => _worldToScreen(p, size)).toList();

    // Build Catmull-Rom smooth path
    final path = Path();
    path.moveTo(screenPoints[0].dx, screenPoints[0].dy);

    if (screenPoints.length == 2) {
      path.lineTo(screenPoints[1].dx, screenPoints[1].dy);
    } else {
      for (int i = 0; i < screenPoints.length - 1; i++) {
        final p0 = i > 0 ? screenPoints[i - 1] : screenPoints[i];
        final p1 = screenPoints[i];
        final p2 = screenPoints[i + 1];
        final p3 = i + 2 < screenPoints.length ? screenPoints[i + 2] : p2;

        final cp1 = Offset(
          p1.dx + (p2.dx - p0.dx) / 6.0,
          p1.dy + (p2.dy - p0.dy) / 6.0,
        );
        final cp2 = Offset(
          p2.dx - (p3.dx - p1.dx) / 6.0,
          p2.dy - (p3.dy - p1.dy) / 6.0,
        );

        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      }
    }

    // === LAYER 1: Wide soft glow ===
    canvas.drawPath(path, Paint()
      ..color = AppColors.accentBlue.withValues(alpha: 0.12)
      ..strokeWidth = glowWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    // === LAYER 2: Main thick blue line ===
    canvas.drawPath(path, Paint()
      ..color = AppColors.accentBlue
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);

    // === LAYER 3: Thin white center highlight ===
    canvas.drawPath(path, Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);

    // Distance labels
    _drawDistanceLabels(canvas, points, screenPoints);
  }

  /// Draw live distance labels along the path
  void _drawDistanceLabels(Canvas canvas, List<ScanPoint> points, List<Offset> screenPoints) {
    double cumDist = 0.0;
    double lastLabel = 0.0;
    const labelEvery = 0.3; // Every 30cm

    for (int i = 1; i < points.length; i++) {
      cumDist += points[i - 1].distanceTo(points[i]);

      if (cumDist - lastLabel >= labelEvery) {
        lastLabel = cumDist;
        final pos = screenPoints[i];

        final val = _convertDist(cumDist);
        final unit = distanceUnit == 'ft' ? 'ft' : distanceUnit == 'in' ? 'in' : 'm';
        final label = '${val.toStringAsFixed(2)}$unit';

        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();

        // Background pill
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(pos.dx, pos.dy - 14),
              width: tp.width + 8, height: 14,
            ),
            const Radius.circular(4),
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.7),
        );

        tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - 21));
      }
    }
  }

  double _convertDist(double meters) {
    switch (distanceUnit) {
      case 'ft': return meters * 3.28084;
      case 'in': return meters * 39.3701;
      default: return meters;
    }
  }

  void _drawAutoPoint(Canvas canvas, Size size, ScanPoint point) {
    final sp = _worldToScreen(point, size);
    canvas.drawCircle(sp, autoPinRadius + 1.5, Paint()
      ..color = Colors.yellow.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(sp, autoPinRadius, Paint()
      ..color = Colors.yellow.withValues(alpha: 0.8));
  }

  void _drawManualPin(Canvas canvas, Size size, ScanPoint point, {required bool isStart}) {
    final sp = _worldToScreen(point, size);

    // Glow
    canvas.drawCircle(sp, manualPinRadius + 6, Paint()
      ..color = Colors.red.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    // White ring
    canvas.drawCircle(sp, manualPinRadius, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);
    // Red fill
    canvas.drawCircle(sp, manualPinRadius - 2, Paint()..color = Colors.red);
    // Highlight
    canvas.drawCircle(
      Offset(sp.dx - 2, sp.dy - 2),
      manualPinRadius * 0.3,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );

    // Label
    final tp = TextPainter(
      text: TextSpan(
        text: isStart ? 'START' : 'END',
        style: const TextStyle(
          color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(sp.dx - tp.width / 2, sp.dy + manualPinRadius + 10));
  }

  /// World → Screen projection with FULL 3D AR-like persistence.
  ///
  /// FIXED: Now handles BOTH yaw (left-right) AND pitch (up-down) rotations
  /// for stable line rendering in world space.
  ///
  /// Key insight: Apply inverse rotation matrix to keep points anchored
  /// in world space as device rotates in any direction.
  ///
  /// Coordinate system:
  /// - X positive = screen RIGHT (physical right movement)
  /// - Y positive = UP (physical up movement)
  /// - Z positive = screen UP (physical forward movement)
  Offset _worldToScreen(ScanPoint point, Size size) {
    if (startPoint == null) return Offset(size.width / 2, size.height / 2);

    // Delta from start point in world space
    final worldDx = point.x - startPoint!.x;
    final worldDy = point.y - startPoint!.y; // Vertical (up/down)
    final worldDz = point.z - startPoint!.z;

    // Apply INVERSE rotation to compensate for device rotation
    // This makes points appear stable in world space

    // Step 1: Rotate around Y axis (yaw - left/right)
    final cosYaw = math.cos(-deviceRotationY);
    final sinYaw = math.sin(-deviceRotationY);
    final rotatedX1 = worldDx * cosYaw - worldDz * sinYaw;
    final rotatedZ1 = worldDx * sinYaw + worldDz * cosYaw;
    final rotatedY1 = worldDy; // Y unchanged by yaw rotation

    // Step 2: Rotate around X axis (pitch - up/down)
    final cosPitch = math.cos(-deviceRotationX);
    final sinPitch = math.sin(-deviceRotationX);
    final rotatedY2 = rotatedY1 * cosPitch - rotatedZ1 * sinPitch;
    final rotatedZ2 = rotatedY1 * sinPitch + rotatedZ1 * cosPitch;
    final rotatedX2 = rotatedX1; // X unchanged by pitch rotation

    // Project to screen: center of screen is the start point
    // X maps to horizontal screen position
    // Z maps to vertical screen position (forward = up on screen)
    // Y affects vertical position (up = up on screen)
    final screenX = size.width / 2 + rotatedX2 * pixelsPerMeter;
    final screenY = size.height / 2 - (rotatedZ2 + rotatedY2 * 0.5) * pixelsPerMeter;

    return Offset(
      screenX.clamp(-100.0, size.width + 100.0),
      screenY.clamp(-100.0, size.height + 100.0),
    );
  }

  @override
  bool shouldRepaint(ScanPainter oldDelegate) {
    return startPoint != oldDelegate.startPoint ||
        endPoint != oldDelegate.endPoint ||
        autoPoints.length != oldDelegate.autoPoints.length ||
        distanceUnit != oldDelegate.distanceUnit ||
        (deviceRotationY - oldDelegate.deviceRotationY).abs() > 0.01 ||
        (deviceRotationX - oldDelegate.deviceRotationX).abs() > 0.01; // NEW: pitch check
  }
}
