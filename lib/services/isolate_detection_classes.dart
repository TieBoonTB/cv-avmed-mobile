import 'dart:typed_data';

import '../types/detection_types.dart';
import '../config/model_config.dart';
import 'isolate_detection_service.dart';

/// YOLOv5 detection service using isolates
class IsolateYOLOv5DetectionService extends IsolateDetectionService {
  IsolateYOLOv5DetectionService() : super(ModelType.yolov5s);
}

/// AVMED detection service using isolates
class IsolateAVMedDetectionService extends IsolateDetectionService {
  IsolateAVMedDetectionService() : super(ModelType.avmed);
}

/// Chair detection service using isolates (extends YOLOv5 with filtering)
class IsolateChairDetectionService extends IsolateDetectionService {
  IsolateChairDetectionService() : super(ModelType.yolov5s);

  @override
  String get serviceType => 'Isolate-based Chair Detection (YOLOv5 filtered)';

  @override
  Future<List<DetectionResult>> processFrame(
    Uint8List frameData,
    int imageHeight,
    int imageWidth,
  ) async {
    // Get all YOLOv5 detections from the isolate
    final allDetections =
        await super.processFrame(frameData, imageHeight, imageWidth);

    // Filter for chairs only at the service level
    final chairDetections =
        allDetections.where((d) => d.label.toLowerCase() == 'chair').toList();

    print(
        'Chair Detection: Found ${chairDetections.length} chairs out of ${allDetections.length} total detections');

    // Update cached results with filtered detections
    updateDetections(chairDetections);

    return chairDetections;
  }

  /// Detect chairs in the frame
  List<DetectionResult> detectChair(List<DetectionResult> detections) {
    return detections.where((d) => d.label == 'chair').toList();
  }

  /// Validate chair positioning for test setup
  bool validateChairSetup(List<DetectionResult> detections) {
    final chairs = detectChair(detections);

    if (chairs.isEmpty) {
      print('Chair validation failed: No chairs detected');
      return false;
    }

    // Debug: list all candidate chairs found
    print('Chair validation: found ${chairs.length} candidate(s)');
    for (var i = 0; i < chairs.length; i++) {
      final c = chairs[i];
      print(
          '  candidate[$i]: confidence=${c.confidence.toStringAsFixed(3)}, box=${c.box}');
    }

    // Check chair is in center area and properly sized
    final chair = chairs.first;
    final centerX = chair.box.x + chair.box.width / 2;
    final centerY = chair.box.y + chair.box.height / 2;

    // Individual checks for easier debugging
    final bool inHorizontal = centerX > 0.3 && centerX < 0.7;
    final bool inVertical = centerY > 0.4 && centerY < 0.8;
    final bool hasConfidence = chair.confidence > 0.7;

    final isValidPosition = inHorizontal && inVertical && hasConfidence;
    return isValidPosition;
  }
}

/// Pose detection service using isolates
class IsolatePoseDetectionService extends IsolateDetectionService {
  IsolatePoseDetectionService() : super(ModelType.mediapipe);
}

/// MediaPipe pose detection service using isolates
class IsolateMediaPipePoseDetectionService extends IsolateDetectionService {
  IsolateMediaPipePoseDetectionService() : super(ModelType.mediapipe);
}

class IsolateMLKitPoseDetectionService extends IsolateDetectionService {
  IsolateMLKitPoseDetectionService() : super(ModelType.mlkit);
}
