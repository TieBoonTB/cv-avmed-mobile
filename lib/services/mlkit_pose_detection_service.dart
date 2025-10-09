import 'dart:typed_data';
import '../services/base_detection_service.dart';
import '../models/mlkit_pose_model.dart';
import '../models/base_model.dart';
import '../types/detection_types.dart';

/// ML Kit Pose Detection Service
class MLKitPoseDetectionService extends BaseDetectionService {
  final MLKitPoseModel _model = MLKitPoseModel();

  @override
  String get serviceType => 'Pose Detection Service (ML Kit)';

  @override
  BaseModel? get currentModel => _model;

  @override
  Future<void> initialize() async {
    try {
      print('Initializing MLKit Pose Detection Service...');
      await _model.initialize();
      setInitialized(true);
      print('MLKit Pose Detection Service initialized successfully');
    } catch (e) {
      print('Error initializing MLKit Pose Detection Service: $e');
      setInitialized(false);
      rethrow;
    }
  }

  @override
  Future<List<DetectionResult>> processFrame(
      Uint8List frameData, int imageHeight, int imageWidth) async {
    if (!isInitialized) {
      throw StateError(
          'MLKit Pose Detection Service not initialized. Call initialize() first.');
    }

    try {
      final results =
          await _model.processFrame(frameData, imageHeight, imageWidth);
      print('MLKit Pose Detection: Found ${results.length} landmarks');
      updateDetections(results);
      return results;
    } catch (e) {
      print('Error processing frame in MLKit Pose Detection Service: $e');
      return [
        DetectionResult.createError('MLKit Pose Detection', e.toString())
      ];
    }
  }

  /// Extract key body landmarks from detection results
  Map<String, DetectionBox> extractLandmarks(List<DetectionResult> detections) {
    final landmarks = <String, DetectionBox>{};

    // MediaPipe pose model provides 33 landmarks, we focus on key ones for chair stand test
    // Keep every detection so callers can access all available landmarks
    for (final detection in detections) {
      landmarks[detection.label] = detection.box;
    }

    return landmarks;
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }
}
