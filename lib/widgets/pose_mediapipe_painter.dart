import 'package:flutter/material.dart';
import '../types/detection_types.dart';

/// Painter for standard MediaPipe pose landmarks (33 keypoints)
/// Uses official MediaPipe connections and landmark ordering
class MediaPipePainter extends CustomPainter {
  final List<DetectionResult> landmarks;
  final bool showLabels;
  final double minConfidence;

  MediaPipePainter({
    required this.landmarks,
    this.showLabels = false,
    this.minConfidence = 0.3,
  });

  // Official MediaPipe pose connections (33 landmarks)
  // Based on: https://google.github.io/mediapipe/solutions/pose.html
  static const List<List<int>> _mediapipeConnections = [
    // Face
    [0, 1], [1, 2], [2, 3], [3, 7],
    [0, 4], [4, 5], [5, 6], [6, 8],
    [9, 10],
    
    // Arms
    [11, 13], [13, 15], [15, 17], [17, 19], [19, 15], [15, 21],
    [12, 14], [14, 16], [16, 18], [18, 20], [20, 16], [16, 22],
    
    // Body
    [11, 12], [12, 24], [24, 23], [23, 11],
    
    // Legs
    [23, 25], [25, 27], [27, 29], [29, 31],
    [24, 26], [26, 28], [28, 30], [30, 32],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    // Convert landmarks to screen coordinates
    final points = <Offset>[];
    final visiblePoints = <bool>[];
    
    for (int i = 0; i < landmarks.length; i++) {
      final lm = landmarks[i];
      // Convert normalized coordinates (0-1) to screen pixels
      final x = lm.box.x * size.width;
      final y = lm.box.y * size.height;
      points.add(Offset(x, y));
      
      // Check if point should be visible based on confidence
      visiblePoints.add(lm.confidence >= minConfidence);
    }

    // Draw connections first (behind points)
    final connectionPaint = Paint()
      ..color = Colors.blue.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final connection in _mediapipeConnections) {
      final startIdx = connection[0];
      final endIdx = connection[1];

      // Check if indices are valid and points are visible
      if (startIdx < 0 || startIdx >= points.length) continue;
      if (endIdx < 0 || endIdx >= points.length) continue;
      if (!visiblePoints[startIdx] || !visiblePoints[endIdx]) continue;

      canvas.drawLine(points[startIdx], points[endIdx], connectionPaint);
    }

    // Draw landmark points on top of connections
    final outerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final innerPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      if (!visiblePoints[i]) continue;
      
      final point = points[i];
      canvas.drawCircle(point, 4.0, outerPaint);
      canvas.drawCircle(point, 2.0, innerPaint);
    }

    // Draw labels if requested
    if (showLabels) {
      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: 8,
        shadows: [Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 2)],
      );

      for (int i = 0; i < landmarks.length && i < points.length; i++) {
        if (!visiblePoints[i]) continue;
        
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
  bool shouldRepaint(MediaPipePainter oldDelegate) {
    return landmarks != oldDelegate.landmarks ||
           showLabels != oldDelegate.showLabels ||
           minConfidence != oldDelegate.minConfidence;
  }
}