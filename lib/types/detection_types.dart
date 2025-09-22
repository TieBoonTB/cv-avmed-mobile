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

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  /// Create from map for deserialization
  static DetectionBox fromMap(Map<String, dynamic> map) {
    return DetectionBox(
      x: map['x']?.toDouble() ?? 0.0,
      y: map['y']?.toDouble() ?? 0.0,
      width: map['width']?.toDouble() ?? 0.0,
      height: map['height']?.toDouble() ?? 0.0,
    );
  }

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

  /// Create an error detection result for display in UI
  static DetectionResult createError(String modelName, String errorMessage) {
    return DetectionResult(
      label: '$modelName Error: $errorMessage',
      confidence: 0.0,
      box: const DetectionBox(x: 0.5, y: 0.5, width: 0.1, height: 0.1),
      status: DetectionStatus.failure,
    );
  }

  /// Create a warning detection result for display in UI
  static DetectionResult createWarning(
      String modelName, String warningMessage) {
    return DetectionResult(
      label: '$modelName Warning: $warningMessage',
      confidence: 0.0,
      box: const DetectionBox(x: 0.5, y: 0.5, width: 0.1, height: 0.1),
      status: DetectionStatus.warning,
    );
  }

  /// Check if this detection result represents an error
  bool get isError =>
      status == DetectionStatus.failure || label.contains('Error:');

  /// Check if this detection result represents a warning
  bool get isWarning =>
      status == DetectionStatus.warning || label.contains('Warning:');

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'confidence': confidence,
      'box': box.toMap(),
      'status': status.index,
    };
  }

  /// Create from map for deserialization
  static DetectionResult fromMap(Map<String, dynamic> map) {
    return DetectionResult(
      label: map['label'] ?? '',
      confidence: map['confidence']?.toDouble() ?? 0.0,
      box: DetectionBox.fromMap(Map<String, dynamic>.from(map['box'])),
      status: DetectionStatus.values[map['status'] ?? 0],
    );
  }

  @override
  String toString() =>
      'DetectionResult(label: $label, confidence: $confidence, box: $box)';
}
