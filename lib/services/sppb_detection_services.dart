import '../services/base_detection_service.dart';
import '../models/base_model.dart';
import '../types/detection_types.dart';
import 'dart:typed_data';

/// Clinical analysis service for SPPB assessment
class SPPBAnalysisService extends BaseDetectionService {
  // Movement tracking state
  List<double> _hipAngleHistory = [];
  List<String> _movementPhaseHistory = [];
  // Arm crossing state
  bool get armsCrossed => _armsCrossed;
  int _completedRepetitions = 0;
  DateTime? _testStartTime;
  DateTime? _currentRepStartTime;

  // Clinical metrics
  List<double> _repetitionTimes = [];
  double _totalTestTime = 0.0;
  double _movementSmoothness = 0.0;

  @override
  String get serviceType => 'SPPB Clinical Analysis Service';
  bool _armsCrossed = false;

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
    print('SPPB DEBUG: hipAngle=${hipAngle.toStringAsFixed(1)}, previous=${previousAngle.toStringAsFixed(1)}, phase=$movementPhase');

  // Update arms crossed state for external users
  _armsCrossed = _detectArmsCrossed(landmarks: landmarks);
  // Detect completed repetitions (returns whether a new repetition was counted)
  final bool repDetected = _detectRepetitions(movementPhase, timestamp);

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
      repDetected: repDetected,
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

  bool _detectArmsCrossed({
    required Map<String, DetectionBox> landmarks,
  }) {
    final leftShoulder = landmarks['left_shoulder'];
    final rightShoulder = landmarks['right_shoulder'];
    final leftElbow = landmarks['left_elbow'];
    final rightElbow = landmarks['right_elbow'];
    final leftWrist = landmarks['left_wrist'];
    final rightWrist = landmarks['right_wrist'];

    // Minimum confidence and in-frame check
    bool isValidLandmark(DetectionBox? b) {
      if (b == null) return false;
      // Consider landmark valid only if confidence > 0 and coordinates are inside [0,1]
      return b.confidence > 0.0 && b.x >= 0.0 && b.x <= 1.0 && b.y >= 0.0 && b.y <= 1.0;
    }

    // Need the core landmarks to make a reliable decision
    if (!isValidLandmark(leftShoulder) ||
        !isValidLandmark(rightShoulder) ||
        !isValidLandmark(leftElbow) ||
        !isValidLandmark(rightElbow) ||
        !isValidLandmark(leftWrist) ||
        !isValidLandmark(rightWrist)) {
      // If any core landmark is missing or off-screen, don't claim arms crossed
      return false;
    }

    // Horizontal positions (x). Assume image coordinate system where x increases to the right.
    final lsx = leftShoulder!.x;
    final rsx = rightShoulder!.x;
    final lex = leftElbow!.x;
    final rex = rightElbow!.x;
    final lwx = leftWrist!.x;
    final rwx = rightWrist!.x;

    // Tolerance: fraction of shoulder distance to allow for jitter
    final shoulderDist = (rsx - lsx).abs();
    final tol = (shoulderDist * 0.15).clamp(0.02, 0.1);

    // Common crossed-arms patterns:
    // - Left arm crosses over to the right: left wrist (or elbow) is to the right of the right shoulder
    final leftCrossesRight = (lwx > rsx + tol) || (lex > rsx + tol);

    // - Right arm crosses over to the left: right wrist (or elbow) is to the left of the left shoulder
    final rightCrossesLeft = (rwx < lsx - tol) || (rex < lsx - tol);

    // Another robust check: wrists are swapped horizontally (left wrist right of right wrist)
    final wristsSwapped = lwx > rwx + tol && lex > rex + tol;

    // If both arms clearly cross midline in opposite directions, that's a strong indicator.
    if ((leftCrossesRight && rightCrossesLeft) || wristsSwapped) {
      return true;
    }

    // Less strict: one arm crosses over the midline and the other is near center
    final midline = (lsx + rsx) / 2.0;
    final leftWristPastMid = lwx > midline + tol;
    final rightWristPastMid = rwx < midline - tol;
    if (leftWristPastMid && (rwx < rsx + shoulderDist * 0.2)) return true;
    if (rightWristPastMid && (lwx > lsx - shoulderDist * 0.2)) return true;

    return false;
  }


  /// Analyze movement phase based on hip angle changes
  String _analyzeMovementPhase({
    required double hipAngle,
    required double previousHipAngle,
  }) {
  // Lower sitToStand so a smaller hip angle counts as standing.
  const double sitToStandThreshold = 125.0;
  // Raise standToSit slightly so the algorithm detects sitting earlier.
  const double standToSitThreshold = 120.0;
  // Reduce required angle change to make transitions more sensitive.
  const double angleChangeThreshold = 2.0;

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

  bool _detectRepetitions(String currentPhase, DateTime timestamp) {
    // Need some movement history - lowered for dev so shorter sequences count
    if (_movementPhaseHistory.length < 6) return false; // Need some history

    // Look for sit->stand->sit pattern
    final skipCount = (_movementPhaseHistory.length - 10).clamp(0, _movementPhaseHistory.length);
    final recentPhases = _movementPhaseHistory.skip(skipCount).toList();

    if (recentPhases.contains('sitting') &&
        recentPhases.contains('sit_to_stand') &&
        recentPhases.contains('standing') &&
        recentPhases.contains('stand_to_sit') &&
        currentPhase == 'sitting') {
      _completedRepetitions++;

      // Record repetition time
      double? repTime;
      if (_currentRepStartTime != null) {
        repTime = timestamp.difference(_currentRepStartTime!).inMilliseconds / 1000.0;
        _repetitionTimes.add(repTime);
      }

      _currentRepStartTime = timestamp;

      // DEBUG: log repetition event
      print('SPPB DEBUG: counted repetition #${_completedRepetitions} at $timestamp repTime=${repTime ?? 'n/a'}');

      // Clear recent history to avoid double counting
      _movementPhaseHistory.clear();

      // Return true so caller (analyzeMovement) can publish an explicit
      return true;
    }

    return false;
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
    _armsCrossed = false;
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
  // Whether a repetition was detected during the last analysis call
  final bool repDetected;

  SPPBAnalysisResult({
    required this.hipAngle,
    required this.movementPhase,
    required this.completedRepetitions,
    required this.totalTestTime,
    required this.repetitionTimes,
    required this.movementSmoothness,
    required this.isValidPosition,
    required this.repDetected,
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
      repDetected: false,
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

