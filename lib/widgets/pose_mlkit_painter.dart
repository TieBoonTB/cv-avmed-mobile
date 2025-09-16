import 'package:flutter/material.dart';
import '../types/detection_types.dart';

/// Painter for ML Kit Pose landmarks (33 keypoints)
/// Mirrors MediaPipe connections but uses a distinct color/style
class MLKitPainter extends CustomPainter {
  final List<DetectionResult> landmarks;
  final bool showLabels;
  final double minConfidence;

  MLKitPainter({
    required this.landmarks,
    this.showLabels = false,
    this.minConfidence = 0.3,
  });

  // Use the same landmark connectivity as MediaPipe
  static const List<List<int>> _connections = [
    [0, 1], [1, 2], [2, 3], [3, 7],
    [0, 4], [4, 5], [5, 6], [6, 8],
    [9, 10],
    [11, 13], [13, 15], [15, 17], [17, 19], [19, 15], [15, 21],
    [12, 14], [14, 16], [16, 18], [18, 20], [20, 16], [16, 22],
    [11, 12], [12, 24], [24, 23], [23, 11],
    [23, 25], [25, 27], [27, 29], [29, 31],
    [24, 26], [26, 28], [28, 30], [30, 32],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final points = <Offset>[];
    final visible = <bool>[];

    for (int i = 0; i < landmarks.length; i++) {
      final lm = landmarks[i];
      final x = lm.box.x * size.width;
      final y = lm.box.y * size.height;
      points.add(Offset(x, y));
      visible.add(lm.confidence >= minConfidence);
    }

    final connectionPaint = Paint()
      ..color = Colors.purple.withOpacity(0.85)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final c in _connections) {
      final a = c[0];
      final b = c[1];
      if (a < 0 || a >= points.length) continue;
      if (b < 0 || b >= points.length) continue;
      if (!visible[a] || !visible[b]) continue;
      canvas.drawLine(points[a], points[b], connectionPaint);
    }

    final outerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final innerPaint = Paint()
      ..color = Colors.purple
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      if (!visible[i]) continue;
      canvas.drawCircle(points[i], 4.0, outerPaint);
      canvas.drawCircle(points[i], 2.0, innerPaint);
    }

    if (showLabels) {
      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: 8,
        shadows: [Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 2)],
      );

      for (int i = 0; i < landmarks.length && i < points.length; i++) {
        if (!visible[i]) continue;
        final landmark = landmarks[i];
        final point = points[i];

        final textPainter = TextPainter(
          text: TextSpan(text: '${i}:${landmark.label}', style: textStyle),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        final textOffset = Offset(point.dx + 5, point.dy - textPainter.height / 2);
        textPainter.paint(canvas, textOffset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant MLKitPainter oldDelegate) {
    return landmarks != oldDelegate.landmarks ||
        showLabels != oldDelegate.showLabels ||
        minConfidence != oldDelegate.minConfidence;
  }
}
