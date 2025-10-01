import 'package:flutter/material.dart';
import '../types/detection_types.dart';

/// Paints detection bounding boxes returned as normalized boxes (0..1)
/// onto the widget canvas. Transforms coordinates from full camera image
/// to BoxFit.cover display coordinates.
class DetectionBoxPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final Size imageSize;
  final double minConfidence;

  DetectionBoxPainter({
    required this.detections,
    required this.imageSize,
    this.minConfidence = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width <= 0 || imageSize.height <= 0) return;

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

      // Use the original detection box directly since coordinates are correct
      DetectionBox boxToTransform = det.box;

      // Transform coordinates from full camera image to BoxFit.cover display
      final transformedBox = _transformBoxForBoxFitCover(boxToTransform, imageSize, size);
      
      // Skip detections that are completely outside the visible area
      if (transformedBox.x + transformedBox.width < 0 || transformedBox.x > 1.0 ||
          transformedBox.y + transformedBox.height < 0 || transformedBox.y > 1.0) {
        continue;
      }

      // Map transformed normalized coordinates to canvas coordinates
      final double dstLeft = transformedBox.x * size.width;
      final double dstTop = transformedBox.y * size.height;
      final double dstW = transformedBox.width * size.width;
      final double dstH = transformedBox.height * size.height;
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

  /// Transform detection box coordinates from full camera image to BoxFit.cover display
  DetectionBox _transformBoxForBoxFitCover(DetectionBox box, Size imageSize, Size canvasSize) {
    final imageWidth = imageSize.width;
    final imageHeight = imageSize.height;
    final canvasWidth = canvasSize.width;
    final canvasHeight = canvasSize.height;
    
    final imageAspectRatio = imageWidth / imageHeight;
    final canvasAspectRatio = canvasWidth / canvasHeight;
    
    // Convert normalized coordinates to image pixel coordinates
    final double imgX = box.x * imageWidth;
    final double imgY = box.y * imageHeight;
    final double imgW = box.width * imageWidth;
    final double imgH = box.height * imageHeight;
    
    double visibleX, visibleY, visibleWidth, visibleHeight;
    
    if (imageAspectRatio > canvasAspectRatio) {
      // Image is wider than canvas - crop sides (center crop horizontally)
      visibleHeight = imageHeight;
      visibleWidth = imageHeight * canvasAspectRatio;
      visibleX = (imageWidth - visibleWidth) / 2.0;
      visibleY = 0.0;
    } else {
      // Image is taller than canvas - crop top/bottom (center crop vertically)
      visibleWidth = imageWidth;
      visibleHeight = imageWidth / canvasAspectRatio;
      visibleX = 0.0;
      visibleY = (imageHeight - visibleHeight) / 2.0;
    }
    
    // Transform coordinates to visible area coordinate system
    final double newX = (imgX - visibleX) / visibleWidth;
    final double newY = (imgY - visibleY) / visibleHeight;
    final double newW = imgW / visibleWidth;
    final double newH = imgH / visibleHeight;
    
    return DetectionBox(
      x: newX.clamp(-1.0, 2.0), // Allow some overflow for partial visibility
      y: newY.clamp(-1.0, 2.0),
      width: newW.clamp(0.0, 3.0),
      height: newH.clamp(0.0, 3.0),
    );
  }

  @override
  bool shouldRepaint(covariant DetectionBoxPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.imageSize != imageSize;
  }
}
