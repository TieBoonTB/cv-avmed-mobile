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

    // Check chair is in center area and properly sized
    final chair = chairs.first;
    final centerX = chair.box.x + chair.box.width / 2;
    final centerY = chair.box.y + chair.box.height / 2;

    final isValidPosition = centerX > 0.3 &&
        centerX < 0.7 && // Centered horizontally
        centerY > 0.4 &&
        centerY < 0.8 && // Good vertical position
        chair.confidence > 0.7; // Good confidence (lowered from 0.8)

    print(
        'Chair validation: position($centerX, $centerY), confidence(${chair.confidence}), valid: $isValidPosition');
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
