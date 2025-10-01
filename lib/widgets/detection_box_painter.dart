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
    this.minConfidence = 0.5,
    this.flipHorizontally = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // If imageSize is zero, nothing to paint

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
      if (det.confidence < minConfidence) continue;  // Use the actual minConfidence parameter
      final box = det.box;

      // Transform coordinates from camera image space to screen space
      // Account for BoxFit.cover scaling and cropping
      final double imageAspectRatio = imageSize.width / imageSize.height;
      final double canvasAspectRatio = size.width / size.height;
      
      double scaleX, scaleY, offsetX = 0.0, offsetY = 0.0;
      
      if (imageAspectRatio > canvasAspectRatio) {
        // Image is wider - scale by height, crop width
        scaleY = size.height / imageSize.height;
        scaleX = scaleY;
        final scaledImageWidth = imageSize.width * scaleX;
        offsetX = (size.width - scaledImageWidth) / 2.0;
      } else {
        // Image is taller - scale by width, crop height  
        scaleX = size.width / imageSize.width;
        scaleY = scaleX;
        final scaledImageHeight = imageSize.height * scaleY;
        offsetY = (size.height - scaledImageHeight) / 2.0;
      }
      
      // Apply transformation to normalized coordinates
      double dstLeft = (box.x * imageSize.width * scaleX) + offsetX;
      final double dstTop = (box.y * imageSize.height * scaleY) + offsetY;
      final double dstW = box.width * imageSize.width * scaleX;
      final double dstH = box.height * imageSize.height * scaleY;

      if (flipHorizontally) {
        // Mirror horizontally
        dstLeft = size.width - (box.x + box.width) * size.width;
      }
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
