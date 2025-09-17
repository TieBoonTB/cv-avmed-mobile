import 'package:flutter/material.dart';
import '../types/detection_types.dart';

/// Paints detection bounding boxes returned as normalized boxes (0..1)
/// onto the widget canvas. It assumes the source image (camera preview)
/// was displayed using BoxFit.cover with the provided [imageSize].
class DetectionBoxPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final Size imageSize;
  final double minConfidence;
  final bool flipHorizontally;

  DetectionBoxPainter({
    required this.detections,
    required this.imageSize,
    this.minConfidence = 0.3,
    this.flipHorizontally = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // If imageSize is zero, nothing to paint
    if (imageSize.width <= 0 || imageSize.height <= 0) return;

    // Compute BoxFit.cover transform: scale and offset to map source -> destination
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;
    final double scale = scaleX > scaleY ? scaleX : scaleY; // max

    final double scaledW = imageSize.width * scale;
    final double scaledH = imageSize.height * scale;
    final double offsetX = (size.width - scaledW) / 2.0;
    final double offsetY = (size.height - scaledH) / 2.0;

    final Paint boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.greenAccent;

    final Paint bgPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black.withOpacity(0.4);

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final det in detections) {
      if (det.isError || det.isWarning) continue;
      if (det.confidence < minConfidence) continue;

      final box = det.box;

      // box.x/y/width/height are normalized relative to the source image
      double srcLeft = box.x * imageSize.width;
      final double srcTop = box.y * imageSize.height;
      final double srcW = box.width * imageSize.width;
      final double srcH = box.height * imageSize.height;

      if (flipHorizontally) {
        // Mirror horizontally around vertical axis of the source image
        srcLeft = imageSize.width - (box.x + box.width) * imageSize.width;
      }

      // Map to destination (canvas) using scale + offset computed above
      final double dstLeft = srcLeft * scale + offsetX;
      final double dstTop = srcTop * scale + offsetY;
      final double dstW = srcW * scale;
      final double dstH = srcH * scale;

      final rect = Rect.fromLTWH(dstLeft, dstTop, dstW, dstH);

      // Draw background for label
      const double padding = 4.0;
      final label =
          '${det.label} ${(det.confidence * 100).toStringAsFixed(0)}%';
      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      );
      textPainter.layout(minWidth: 0, maxWidth: size.width);

      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.top - textPainter.height - padding * 2 >= 0
            ? rect.top - textPainter.height - padding * 2
            : rect.top,
        textPainter.width + padding * 2,
        textPainter.height + padding * 2,
      );

      canvas.drawRect(labelRect, bgPaint);
      textPainter.paint(
          canvas, Offset(labelRect.left + padding, labelRect.top + padding));

      // Draw the bounding box
      canvas.drawRect(rect, boxPaint);
    }
  }

  @override
  bool shouldRepaint(covariant DetectionBoxPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.imageSize != imageSize;
  }
}
