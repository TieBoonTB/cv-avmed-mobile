/// Data structures for object detection operations
/// Status of a detection operation
enum DetectionStatus {
  success,
  failure,
  warning,
}

/// Type of detected object
enum DetectedObjectType {
  face,
  object,
}

/// Bounding box for detected objects
class DetectionBox {
  final double x;
  final double y;
  final double width;
  final double height;

  const DetectionBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  @override
  String toString() => 'DetectionBox(x: $x, y: $y, w: $width, h: $height)';
}

/// Result of object detection
class DetectionResult {
  final String label;
  final double confidence;
  final DetectionBox box;
  final DetectionStatus status;

  const DetectionResult({
    required this.label,
    required this.confidence,
    required this.box,
    this.status = DetectionStatus.success,
  });

  @override
  String toString() => 'DetectionResult(label: $label, confidence: $confidence, box: $box)';
}
