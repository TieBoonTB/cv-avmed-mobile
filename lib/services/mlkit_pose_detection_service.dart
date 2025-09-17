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
    for (final detection in detections) {
      if ([
        'left_hip',
        'right_hip',
        'left_knee',
        'right_knee',
        'left_shoulder',
        'right_shoulder',
        'left_ankle',
        'right_ankle'
      ].contains(detection.label)) {
        landmarks[detection.label] = detection.box;
      }
    }

    return landmarks;
  }

  /// Check if person is properly positioned for test
  bool validatePersonPosition(List<DetectionResult> detections) {
    final landmarks = extractLandmarks(detections);

    // Ensure key landmarks are detected for chair stand test
    final requiredLandmarks = [
      'left_hip',
      'right_hip',
      'left_knee',
      'right_knee'
    ];
    final missingLandmarks = <String>[];

    for (final landmark in requiredLandmarks) {
      if (!landmarks.containsKey(landmark)) {
        missingLandmarks.add(landmark);
      }
    }

    if (missingLandmarks.isNotEmpty) {
      print(
          'Person validation failed: Missing landmarks: ${missingLandmarks.join(', ')}');
      return false;
    }

    // Additional validation: check if person is facing the camera
    final hasShoulders = landmarks.containsKey('left_shoulder') &&
        landmarks.containsKey('right_shoulder');

    print(
        'Person validation: Found ${landmarks.length} landmarks, has shoulders: $hasShoulders');
    return hasShoulders;
  }

  /// Calculate hip angle from MediaPipe landmarks
  double? calculateHipAngle(Map<String, DetectionBox> landmarks) {
    final leftHip = landmarks['left_hip'];
    final rightHip = landmarks['right_hip'];
    final leftKnee = landmarks['left_knee'];
    final rightKnee = landmarks['right_knee'];
    final leftShoulder = landmarks['left_shoulder'];
    final rightShoulder = landmarks['right_shoulder'];

    if (leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftShoulder == null ||
        rightShoulder == null) {
      return null;
    }

    // Calculate average positions for more stable measurements
    final avgHipY = (leftHip.y + rightHip.y) / 2;
    final avgKneeY = (leftKnee.y + rightKnee.y) / 2;
    final avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2;

    // Calculate hip angle based on relative positions
    // When sitting: hip is above knee, angle is smaller
    // When standing: hip and knee are more aligned, angle is larger
    final hipKneeDistance = (avgKneeY - avgHipY).abs();
    final shoulderHipDistance = (avgHipY - avgShoulderY).abs();

    if (shoulderHipDistance == 0) return null;

    final ratio = hipKneeDistance / shoulderHipDistance;

    // Map ratio to realistic hip angle (90-180 degrees)
    // This is a simplified calculation - in practice, you'd use proper vector math
    final angle = 90.0 + (ratio * 90.0).clamp(0.0, 90.0);

    return angle;
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }
}
