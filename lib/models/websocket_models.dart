import 'package:uuid/uuid.dart';

/// WebSocket message types
enum MessageType {
  init,
  frame,
  detection,
  end,
  error,
  heartbeat,
}

/// Extension to convert MessageType to/from string
extension MessageTypeExtension on MessageType {
  String get value {
    switch (this) {
      case MessageType.init:
        return 'init';
      case MessageType.frame:
        return 'frame';
      case MessageType.detection:
        return 'detection';
      case MessageType.end:
        return 'end';
      case MessageType.error:
        return 'error';
      case MessageType.heartbeat:
        return 'heartbeat';
    }
  }

  static MessageType fromString(String value) {
    switch (value) {
      case 'init':
        return MessageType.init;
      case 'frame':
        return MessageType.frame;
      case 'detection':
        return MessageType.detection;
      case 'end':
        return MessageType.end;
      case 'error':
        return MessageType.error;
      case 'heartbeat':
        return MessageType.heartbeat;
      default:
        throw ArgumentError('Unknown message type: $value');
    }
  }
}

/// Session configuration for AVMED WebSocket service
class SessionConfig {
  final String? sessionId;
  final String patientCode;
  final bool shouldRecord;
  final int frameWidth;
  final int frameHeight;
  final int framesPerSecond;

  SessionConfig({
    String? sessionId,
    required this.patientCode,
    this.shouldRecord = false,
    this.frameWidth = 1280,
    this.frameHeight = 720,
    this.framesPerSecond = 30,
  }) : sessionId = sessionId ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'params': {
          'shouldRecord': shouldRecord,
          'width': frameWidth,
          'height': frameHeight,
          'framesPerSecond': framesPerSecond,
        },
        'sessionId': sessionId,
        'patientCode': patientCode,
      };

  factory SessionConfig.fromJson(Map<String, dynamic> json) {
    final params = json['params'] as Map<String, dynamic>? ?? {};
    return SessionConfig(
      sessionId: json['sessionId'] as String?,
      patientCode: json['patientCode'] as String? ?? '',
      shouldRecord: params['shouldRecord'] as bool? ?? false,
      frameWidth: (params['width'] as num?)?.toInt() ?? 1280,
      frameHeight: (params['height'] as num?)?.toInt() ?? 720,
      framesPerSecond: (params['framesPerSecond'] as num?)?.toInt() ?? 30,
    );
  }

  @override
  String toString() => 'SessionConfig(id: $sessionId, patient: $patientCode, record: $shouldRecord, ${frameWidth}x$frameHeight@${framesPerSecond}fps)';
}

/// WebSocket message wrapper
class WebSocketMessage {
  final MessageType type;
  final Map<String, dynamic>? payload;

  WebSocketMessage({
    required this.type,
    this.payload,
  });

  Map<String, dynamic> toJson() => {
        'type': type.value,
        if (payload != null) 'payload': payload,
      };

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: MessageTypeExtension.fromString(json['type'] as String),
      payload: json['payload'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() => 'WebSocketMessage(type: ${type.value}, payload: $payload)';
}

/// Normalized bounding box coordinates (0.0 - 1.0)
class NormalizedBoundingBox {
  final double x;      // Left edge (0.0 - 1.0)
  final double y;      // Top edge (0.0 - 1.0)
  final double width;  // Width (0.0 - 1.0)
  final double height; // Height (0.0 - 1.0)

  const NormalizedBoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory NormalizedBoundingBox.fromJson(Map<String, dynamic> json) {
    return NormalizedBoundingBox(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  @override
  String toString() => 'NormalizedBoundingBox(x: $x, y: $y, w: $width, h: $height)';
}

/// Object detection result from server
class ObjectDetection {
  final String label;
  final double confidence;
  final NormalizedBoundingBox box;

  const ObjectDetection({
    required this.label,
    required this.confidence,
    required this.box,
  });

  factory ObjectDetection.fromJson(Map<String, dynamic> json) {
    // Handle label that might be String, int, or double
    String label;
    final labelValue = json['label'];
    if (labelValue is String) {
      label = labelValue;
    } else if (labelValue is num) {
      label = labelValue.toString();
    } else {
      label = 'unknown';
    }
    
    return ObjectDetection(
      label: label,
      confidence: (json['confidence'] as num).toDouble(),
      box: NormalizedBoundingBox.fromJson(json['box'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'confidence': confidence,
        'box': box.toJson(),
      };

  @override
  String toString() => 'ObjectDetection(label: $label, confidence: $confidence, box: $box)';
}

/// Face detection result from server
class FaceDetection {
  final String label;
  final double confidence;
  final NormalizedBoundingBox box;

  const FaceDetection({
    required this.label,
    required this.confidence,
    required this.box,
  });

  factory FaceDetection.fromJson(Map<String, dynamic> json) {
    // Handle label that might be String, int, or double
    String label;
    final labelValue = json['label'];
    if (labelValue is String) {
      label = labelValue;
    } else if (labelValue is num) {
      label = labelValue.toString();
    } else {
      label = 'face';
    }
    
    return FaceDetection(
      label: label,
      confidence: (json['confidence'] as num).toDouble(),
      box: NormalizedBoundingBox.fromJson(json['box'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'confidence': confidence,
        'box': box.toJson(),
      };

  @override
  String toString() => 'FaceDetection(label: $label, confidence: $confidence, box: $box)';
}

/// Detection response data from server
class DetectionResponseData {
  final List<ObjectDetection> boxes;
  final List<FaceDetection> faces;

  const DetectionResponseData({
    required this.boxes,
    required this.faces,
  });

  factory DetectionResponseData.fromJson(Map<String, dynamic> json) {
    final boxesJson = json['boxes'] as List? ?? [];
    final facesJson = json['faces'] as List? ?? [];

    return DetectionResponseData(
      boxes: boxesJson
          .map((box) => ObjectDetection.fromJson(box as Map<String, dynamic>))
          .toList(),
      faces: facesJson
          .map((face) => FaceDetection.fromJson(face as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'boxes': boxes.map((box) => box.toJson()).toList(),
        'faces': faces.map((face) => face.toJson()).toList(),
      };

  @override
  String toString() => 'DetectionResponseData(boxes: ${boxes.length}, faces: ${faces.length})';
}

/// AVMED detection labels enum
enum AVMedLabel {
  pill('pill'),
  pillOnTongue('pill on tongue'),
  noPillOnTongue('no pill on tongue'),
  drinkWater('drink water'),
  noPillUnderTongue('no pill under tongue'),
  pleaseUseTransparentCup('please use transparent cup'),
  mouthCovered('mouth covered'),
  face('face'),
  mouth('mouth'),
  tongue('tongue'),
  hand('hand'),
  water('water'),
  cup('cup'),
  person('person');

  const AVMedLabel(this.value);
  final String value;

  static AVMedLabel? fromString(String value) {
    for (final label in AVMedLabel.values) {
      if (label.value.toLowerCase() == value.toLowerCase()) {
        return label;
      }
    }
    return null;
  }

  bool isTargetStep() {
    switch (this) {
      case AVMedLabel.pill:
      case AVMedLabel.pillOnTongue:
      case AVMedLabel.noPillOnTongue:
      case AVMedLabel.drinkWater:
      case AVMedLabel.noPillUnderTongue:
        return true;
      default:
        return false;
    }
  }
}

/// Error response from server
class ErrorResponse {
  final String error;
  final String? details;

  const ErrorResponse({
    required this.error,
    this.details,
  });

  factory ErrorResponse.fromJson(Map<String, dynamic> json) {
    return ErrorResponse(
      error: json['error'] as String,
      details: json['details'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'error': error,
        if (details != null) 'details': details,
      };

  @override
  String toString() => 'ErrorResponse(error: $error, details: $details)';
}