import 'package:flutter/material.dart';
import '../types/detection_types.dart';

/// Painter for Qualcomm/MediaPipe pose landmarks with visibility-based filtering
class PoseQualcommPainter extends CustomPainter {
  final List<DetectionResult> landmarks;
  final bool showLabels;
  final double minConfidence;

  PoseQualcommPainter({
    required this.landmarks,
    this.showLabels = true, // Temporarily enabled for debugging
    this.minConfidence = 0.015, // Very low threshold for side poses
  });

  // Pose landmark connections as provided
  static const List<List<int>> _poseConnections = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 7],
    [0, 4],
    [4, 5],
    [5, 6],
    [6, 8],
    [9, 10],
    [11, 13],
    [13, 15],
    [15, 17],
    [17, 19],
    [19, 15],
    [15, 21],
    [12, 14],
    [14, 16],
    [16, 18],
    [18, 20],
    [20, 16],
    [16, 22],
    [11, 12],
    [12, 24],
    [24, 23],
    [23, 11],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    // Reduce logging frequency - only log every 30th frame
    final shouldLog = (DateTime.now().millisecondsSinceEpoch ~/ 100) % 30 == 0;
    
    if (shouldLog) {
      print('[PAINTER] Drawing ${landmarks.length} landmarks, size: ${size.width}x${size.height}, minConf: $minConfidence');
    }

    // Convert landmarks to screen coordinates
    final points = <Offset>[];
    for (int i = 0; i < landmarks.length; i++) {
      final lm = landmarks[i];
      // Convert normalized coordinates (0-1) to screen pixels
      final x = lm.box.x * size.width;
      final y = lm.box.y * size.height;
      points.add(Offset(x, y));

      // Debug first few landmarks occasionally
      if (shouldLog && i < 3) {
        print('[PAINTER] Landmark $i (${lm.label}): norm=(${lm.box.x.toStringAsFixed(3)}, ${lm.box.y.toStringAsFixed(3)}), conf=${lm.confidence.toStringAsFixed(3)}');
      }
    }

    // Draw connections first (so they appear behind points)
    int connectionsDrawn = 0;
    final connectionPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.9)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final connection in _poseConnections) {
      final startIdx = connection[0];
      final endIdx = connection[1];

      // Check if indices are valid
      if (startIdx < 0 || startIdx >= points.length) continue;
      if (endIdx < 0 || endIdx >= points.length) continue;

      // Draw the connection unconditionally (model visibility is not used)
      canvas.drawLine(points[startIdx], points[endIdx], connectionPaint);
      connectionsDrawn++;
    }

    if (shouldLog) print('[PAINTER] Drew $connectionsDrawn connections');

    // Draw landmark points on top of connections (fixed styling, ignore confidence)
    int pointsDrawn = 0;
    final outerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final innerPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      canvas.drawCircle(point, 3.5, outerPaint);
      canvas.drawCircle(point, 1.6, innerPaint);
      pointsDrawn++;
    }

    if (shouldLog) print('[PAINTER] Drew $pointsDrawn landmark points');

    // Draw labels if requested
    if (showLabels) {
      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: 8,
        shadows: [Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 2)],
      );

      for (int i = 0; i < landmarks.length && i < points.length; i++) {
        final landmark = landmarks[i];
        final point = points[i];

        final textPainter = TextPainter(
          text: TextSpan(text: '${i}:${landmark.label}', style: textStyle),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        
        // Position text slightly offset from point
        final textOffset = Offset(
          point.dx + 5,
          point.dy - textPainter.height / 2,
        );
        
        textPainter.paint(canvas, textOffset);
      }
    }
  }

  @override
  bool shouldRepaint(PoseQualcommPainter oldDelegate) {
    return landmarks != oldDelegate.landmarks ||
           showLabels != oldDelegate.showLabels ||
           minConfidence != oldDelegate.minConfidence;
  }
}
