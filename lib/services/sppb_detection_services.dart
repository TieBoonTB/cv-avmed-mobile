import '../services/base_detection_service.dart';
import '../models/base_model.dart';
import '../models/mediapipe_pose_model.dart';
import '../types/detection_types.dart';
import 'dart:typed_data';

/// Pose detection service using MediaPipe pose_landmark_full model
class PoseDetectionService extends BaseDetectionService {
  final MediaPipePoseModel _model = MediaPipePoseModel();

  @override
  String get serviceType => 'Pose Detection Service (MediaPipe)';

  @override
  BaseModel? get currentModel => _model;

  @override
  Future<void> initialize() async {
    try {
      print('Initializing Pose Detection Service...');
      await _model.initialize();
      setInitialized(true);
      print('Pose Detection Service initialized successfully');
    } catch (e) {
      print('Error initializing Pose Detection Service: $e');
      setInitialized(false);
      rethrow;
    }
  }

  @override
  Future<List<DetectionResult>> processFrame(
      Uint8List frameData, int imageHeight, int imageWidth) async {
    if (!isInitialized) {
      throw StateError(
          'Pose Detection Service not initialized. Call initialize() first.');
    }

    try {
      final results =
          await _model.processFrame(frameData, imageHeight, imageWidth);
      print('Pose Detection: Found ${results.length} landmarks');
      updateDetections(results);
      return results;
    } catch (e) {
      print('Error processing frame in Pose Detection Service: $e');
      return [DetectionResult.createError('Pose Detection', e.toString())];
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

/// Clinical analysis service for SPPB assessment
class SPPBAnalysisService extends BaseDetectionService {
  // Movement tracking state
  List<double> _hipAngleHistory = [];
  List<String> _movementPhaseHistory = [];
  int _completedRepetitions = 0;
  DateTime? _testStartTime;
  DateTime? _currentRepStartTime;

  // Clinical metrics
  List<double> _repetitionTimes = [];
  double _totalTestTime = 0.0;
  double _movementSmoothness = 0.0;

  @override
  String get serviceType => 'SPPB Clinical Analysis Service';

  @override
  BaseModel? get currentModel => null; // Analysis service doesn't use a model

  @override
  Future<void> initialize() async {
    try {
      print('Initializing SPPB Analysis Service...');
      resetMetrics();
      setInitialized(true);
      print('SPPB Analysis Service initialized successfully');
    } catch (e) {
      print('Error initializing SPPB Analysis Service: $e');
      setInitialized(false);
      rethrow;
    }
  }

  @override
  Future<List<DetectionResult>> processFrame(
      Uint8List frameData, int imageHeight, int imageWidth) async {
    if (!isInitialized) {
      throw StateError(
          'SPPB Analysis Service not initialized. Call initialize() first.');
    }

    // This service doesn't process frames directly, it analyzes pose data
    // Return empty list as it's a data analysis service, not a detection service
    return [];
  }

  /// Analyze movement patterns from pose landmarks
  SPPBAnalysisResult analyzeMovement({
    required Map<String, DetectionBox> landmarks,
    required DateTime timestamp,
  }) {
    if (!landmarks.containsKey('left_hip') ||
        !landmarks.containsKey('right_hip') ||
        !landmarks.containsKey('left_knee') ||
        !landmarks.containsKey('right_knee')) {
      return SPPBAnalysisResult.invalid();
    }

    // Calculate hip angle using MediaPipe landmarks
    final hipAngle = _calculateHipAngleFromLandmarks(landmarks);
    if (hipAngle == null) {
      return SPPBAnalysisResult.invalid();
    }

    // Append hip angle to history
    _hipAngleHistory.add(hipAngle);

    // Determine movement phase based on angle changes
    final previousAngle = _hipAngleHistory.length > 1
        ? _hipAngleHistory[_hipAngleHistory.length - 2]
        : hipAngle;
    final movementPhase = _analyzeMovementPhase(
      hipAngle: hipAngle,
      previousHipAngle: previousAngle,
    );

    _movementPhaseHistory.add(movementPhase);

    // DEBUG: print angle and phase for tuning
    print(
        'SPPB DEBUG: hipAngle=${hipAngle.toStringAsFixed(1)}, previous=${previousAngle.toStringAsFixed(1)}, phase=$movementPhase');

    // Detect completed repetitions
    _detectRepetitions(movementPhase, timestamp);

    // Calculate clinical metrics
    _updateClinicalMetrics(timestamp);

    return SPPBAnalysisResult(
      hipAngle: hipAngle,
      movementPhase: movementPhase,
      completedRepetitions: _completedRepetitions,
      totalTestTime: _totalTestTime,
      repetitionTimes: List.from(_repetitionTimes),
      movementSmoothness: _movementSmoothness,
      isValidPosition: true,
    );
  }

  double? _calculateHipAngleFromLandmarks(Map<String, DetectionBox> landmarks) {
    final leftHip = landmarks['left_hip'];
    final rightHip = landmarks['right_hip'];
    final leftKnee = landmarks['left_knee'];
    final rightKnee = landmarks['right_knee'];
    final leftShoulder = landmarks['left_shoulder'];
    final rightShoulder = landmarks['right_shoulder'];

    if (leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null) {
      return null;
    }

    // Calculate average positions for more stable measurements
    final avgHipY = (leftHip.y + rightHip.y) / 2;
    final avgKneeY = (leftKnee.y + rightKnee.y) / 2;

    // Use shoulder position if available for better angle calculation
    double avgShoulderY = avgHipY - 0.2; // Default if shoulders not detected
    if (leftShoulder != null && rightShoulder != null) {
      avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    }

    // Calculate hip angle based on relative positions
    // When sitting: hip is above knee, smaller angle
    // When standing: hip and knee are more aligned, larger angle
    final hipKneeDistance = (avgKneeY - avgHipY).abs();
    final shoulderHipDistance = (avgHipY - avgShoulderY).abs();

    if (shoulderHipDistance == 0) return null;

    final ratio = hipKneeDistance / shoulderHipDistance;

    // Map ratio to realistic hip angle (90-180 degrees)
    final angle = 90.0 + (ratio * 90.0).clamp(0.0, 90.0);

    return angle;
  }

  /// Analyze movement phase based on hip angle changes
  String _analyzeMovementPhase({
    required double hipAngle,
    required double previousHipAngle,
  }) {
    // TUNABLE THRESHOLDS (lowered for easier dev detection)
    const double sitToStandThreshold = 125.0; // lowered from 135
    const double standToSitThreshold = 110.0; // slightly raised from 105
    const double angleChangeThreshold = 3.0; // lowered from 5.0

    final angleChange = hipAngle - previousHipAngle;

    if (hipAngle > sitToStandThreshold) {
      if (angleChange > angleChangeThreshold) {
        return 'sit_to_stand';
      } else {
        return 'standing';
      }
    } else if (hipAngle < standToSitThreshold) {
      if (angleChange < -angleChangeThreshold) {
        return 'stand_to_sit';
      } else {
        return 'sitting';
      }
    } else {
      // In transition zone
      if (angleChange > angleChangeThreshold) {
        return 'sit_to_stand';
      } else if (angleChange < -angleChangeThreshold) {
        return 'stand_to_sit';
      } else {
        return 'transitioning';
      }
    }
  }

  void _detectRepetitions(String currentPhase, DateTime timestamp) {
    // Need some movement history - lowered for dev so shorter sequences count
    if (_movementPhaseHistory.length < 6) return; // Need some history

    // Look for sit->stand->sit pattern
    final recentPhases =
        _movementPhaseHistory.skip(_movementPhaseHistory.length - 10).toList();

    // DEBUG: print recent phases before pattern check
    print(
        'SPPB DEBUG: recentPhases=${recentPhases.join(', ')} currentPhase=$currentPhase historyLen=${_movementPhaseHistory.length}');

    if (recentPhases.contains('sitting') &&
        recentPhases.contains('sit_to_stand') &&
        recentPhases.contains('standing') &&
        recentPhases.contains('stand_to_sit') &&
        currentPhase == 'sitting') {
      _completedRepetitions++;

      // Record repetition time
      double? repTime;
      if (_currentRepStartTime != null) {
        repTime =
            timestamp.difference(_currentRepStartTime!).inMilliseconds / 1000.0;
        _repetitionTimes.add(repTime);
      }

      _currentRepStartTime = timestamp;

      // DEBUG: log repetition event
      print(
          'SPPB DEBUG: counted repetition #${_completedRepetitions} at $timestamp repTime=${repTime ?? 'n/a'}');

      // Clear recent history to avoid double counting
      _movementPhaseHistory.clear();
    }
  }

  void _updateClinicalMetrics(DateTime timestamp) {
    _testStartTime ??= timestamp;
    _totalTestTime =
        timestamp.difference(_testStartTime!).inMilliseconds / 1000.0;

    // Calculate movement smoothness based on hip angle variance
    if (_hipAngleHistory.length > 10) {
      final recentAngles =
          _hipAngleHistory.skip(_hipAngleHistory.length - 10).toList();
      final mean = recentAngles.reduce((a, b) => a + b) / recentAngles.length;
      final variance = recentAngles
              .map((angle) => (angle - mean) * (angle - mean))
              .reduce((a, b) => a + b) /
          recentAngles.length;
      _movementSmoothness =
          1.0 - (variance / 1000.0).clamp(0.0, 1.0); // Normalize to 0-1
    }
  }

  /// Get current test performance metrics
  SPPBTestMetrics getTestMetrics() {
    return SPPBTestMetrics(
      completedRepetitions: _completedRepetitions,
      totalTestTime: _totalTestTime,
      averageRepetitionTime: _repetitionTimes.isNotEmpty
          ? _repetitionTimes.reduce((a, b) => a + b) / _repetitionTimes.length
          : 0.0,
      movementSmoothness: _movementSmoothness,
      repetitionTimes: List.from(_repetitionTimes),
    );
  }

  /// Reset all tracking metrics
  void resetMetrics() {
    _hipAngleHistory.clear();
    _movementPhaseHistory.clear();
    _completedRepetitions = 0;
    _testStartTime = null;
    _currentRepStartTime = null;
    _repetitionTimes.clear();
    _totalTestTime = 0.0;
    _movementSmoothness = 0.0;
  }

  @override
  void dispose() {
    resetMetrics();
    super.dispose();
  }
}

/// Result class for SPPB analysis
class SPPBAnalysisResult {
  final double hipAngle;
  final String movementPhase;
  final int completedRepetitions;
  final double totalTestTime;
  final List<double> repetitionTimes;
  final double movementSmoothness;
  final bool isValidPosition;

  SPPBAnalysisResult({
    required this.hipAngle,
    required this.movementPhase,
    required this.completedRepetitions,
    required this.totalTestTime,
    required this.repetitionTimes,
    required this.movementSmoothness,
    required this.isValidPosition,
  });

  factory SPPBAnalysisResult.invalid() {
    return SPPBAnalysisResult(
      hipAngle: 0.0,
      movementPhase: 'invalid',
      completedRepetitions: 0,
      totalTestTime: 0.0,
      repetitionTimes: [],
      movementSmoothness: 0.0,
      isValidPosition: false,
    );
  }
}

/// Test performance metrics
class SPPBTestMetrics {
  final int completedRepetitions;
  final double totalTestTime;
  final double averageRepetitionTime;
  final double movementSmoothness;
  final List<double> repetitionTimes;

  SPPBTestMetrics({
    required this.completedRepetitions,
    required this.totalTestTime,
    required this.averageRepetitionTime,
    required this.movementSmoothness,
    required this.repetitionTimes,
  });

  /// Calculate SPPB score based on performance
  int calculateSPPBScore() {
    if (completedRepetitions < 1) return 0;

    // SPPB scoring for chair stand test (simplified)
    if (totalTestTime <= 11.19) return 4; // Excellent
    if (totalTestTime <= 13.69) return 3; // Good
    if (totalTestTime <= 16.69) return 2; // Fair
    if (totalTestTime <= 60.0) return 1; // Poor
    return 0; // Unable to complete
  }
}
