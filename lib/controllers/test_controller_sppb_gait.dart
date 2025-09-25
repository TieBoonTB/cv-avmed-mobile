import 'package:flutter/foundation.dart';
import 'base_test_controller.dart';
import '../services/mlkit_pose_detection_service.dart';
import '../services/base_detection_service.dart';
import '../types/detection_types.dart';

/// Gait Speed Test Controller for SPPB gait component (using new base controller)
class TestControllerSPPBGait extends BaseTestController {
  TestControllerSPPBGait({
    VoidCallback? onTestUpdate,
    VoidCallback? onTestComplete,
    Function(bool)? onStepComplete,
  }) : super(
          onTestUpdate: onTestUpdate,
          onTestComplete: onTestComplete,
          onStepComplete: onStepComplete,
        ) {
    frameProcessingIntervalMs = 500.0;
  }

  @override
  Map<String, BaseDetectionService> createDetectionServices() {
    return {
      'pose': MLKitPoseDetectionService(),
    };
  }

  // Convenience getter for pose detections
  List<DetectionResult> get poseDetections => getDetections('pose');

  @override
  List<TestStep> createTestSteps() {
    final intervalMs = frameProcessingIntervalMs;
    return [
      TestStep(
        label: 'Setup Walking Path',
        targetLabel: 'gait_setup',
        targetTimeSeconds: 5.0,
        maxTime: 10.0,
        confidenceThreshold: 0.8,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Normal Pace Walk',
        targetLabel: 'gait_normal',
        targetTimeSeconds: 15.0,
        maxTime: 30.0,
        confidenceThreshold: 0.7,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Fast Pace Walk',
        targetLabel: 'gait_fast',
        targetTimeSeconds: 10.0,
        maxTime: 20.0,
        confidenceThreshold: 0.7,
        frameProcessingIntervalMs: intervalMs,
      ),
    ];
  }

  @override
  Future<void> processTestStep() async {
    final step = currentStep;
    if (step == null || !step.isActive) return;

    final detections = getDetections('pose');
    bool found = false;

    for (final d in detections) {
      if (d.label.toLowerCase().contains('person') &&
          d.confidence >= step.confidenceThreshold) {
        found = true;
        break;
      }
    }

    processStepDetectionResult(step, found);
  }
}
