import 'dart:async';
import 'dart:typed_data';

enum DetectionStatus {
  success,
  failure,
  warning,
}

enum DetectedObjectType {
  face,
  object,
}

class DetectionBox {
  final double x;
  final double y;
  final double width;
  final double height;

  DetectionBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class DetectionResult {
  final String label;
  final double confidence;
  final DetectionBox box;

  DetectionResult({
    required this.label,
    required this.confidence,
    required this.box,
  });
}

class DetectedObject {
  final DetectedObjectType type;
  final DetectionStatus status;
  final String label;
  final double? confidence;
  final DetectionBox box;

  DetectedObject({
    required this.type,
    required this.status,
    required this.label,
    this.confidence,
    required this.box,
  });
}

class DetectedFace extends DetectedObject {
  final bool isNearEdge;

  DetectedFace({
    required super.status,
    required super.label,
    super.confidence,
    required super.box,
    required this.isNearEdge,
  }) : super(
          type: DetectedObjectType.face,
        );
}

class DetectionService {
  static const int framesPerSecond = 30;
  static const double faceNearEdgeThreshold = 50.0;
  
  final StreamController<List<DetectionResult>> _detectionController = 
      StreamController<List<DetectionResult>>.broadcast();

  Stream<List<DetectionResult>> get detectionStream => _detectionController.stream;

  // Simulate processing a frame (in real implementation, this would call ML model)
  Future<List<DetectionResult>> processFrame(Uint8List frameData) async {
    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 50));
    
    // Simulate detection results - MOCK: Always return successful detections
    final results = <DetectionResult>[];
    
    // Always add successful detections for testing
    results.add(DetectionResult(
      label: 'pill',
      confidence: 0.85,
      box: DetectionBox(x: 0.3, y: 0.4, width: 0.1, height: 0.1),
    ));
    
    results.add(DetectionResult(
      label: 'pill on tongue',
      confidence: 0.80,
      box: DetectionBox(x: 0.4, y: 0.5, width: 0.08, height: 0.08),
    ));
    
    results.add(DetectionResult(
      label: 'drink water',
      confidence: 0.75,
      box: DetectionBox(x: 0.35, y: 0.3, width: 0.12, height: 0.15),
    ));
    
    results.add(DetectionResult(
      label: 'no pill on tongue',
      confidence: 0.82,
      box: DetectionBox(x: 0.45, y: 0.55, width: 0.1, height: 0.1),
    ));
    
    results.add(DetectionResult(
      label: 'no pill under tongue',
      confidence: 0.78,
      box: DetectionBox(x: 0.42, y: 0.52, width: 0.09, height: 0.09),
    ));
    
    results.add(DetectionResult(
      label: 'person',
      confidence: 0.95,
      box: DetectionBox(x: 0.2, y: 0.1, width: 0.6, height: 0.8),
    ));
    
    _detectionController.add(results);
    return results;
  }

  DetectedFace processDetectedFace({
    required double confidence,
    required DetectionBox box,
    required double videoWidth,
    required double videoHeight,
  }) {
    final isNearEdge = isFaceNearEdge(box, videoWidth, videoHeight);

    return DetectedFace(
      status: isNearEdge ? DetectionStatus.warning : DetectionStatus.success,
      label: isNearEdge ? 'Face Near Edge' : 'Face',
      confidence: confidence,
      box: box,
      isNearEdge: isNearEdge,
    );
  }

  DetectedObject processDetectedBox({
    required String label,
    required double confidence,
    required DetectionBox box,
    required String targetLabel,
    required double confidenceThreshold,
  }) {
    final isTarget = label == targetLabel && confidence >= confidenceThreshold;

    return DetectedObject(
      type: DetectedObjectType.object,
      status: isTarget ? DetectionStatus.success : DetectionStatus.failure,
      label: label,
      confidence: confidence,
      box: box,
    );
  }

  bool isFaceNearEdge(DetectionBox box, double videoWidth, double videoHeight) {
    final x1 = box.x * videoWidth;
    final y1 = box.y * videoHeight;
    final x2 = x1 + box.width * videoWidth;
    final y2 = y1 + box.height * videoHeight;

    return x1 < faceNearEdgeThreshold ||
           x2 > videoWidth - faceNearEdgeThreshold ||
           y1 < faceNearEdgeThreshold ||
           y2 > videoHeight - faceNearEdgeThreshold;
  }

  void dispose() {
    _detectionController.close();
  }
}
