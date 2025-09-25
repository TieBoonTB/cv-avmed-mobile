import 'package:flutter/foundation.dart';
import 'base_test_controller.dart';
import '../services/mlkit_pose_detection_service.dart';
import '../services/base_detection_service.dart';
import '../types/detection_types.dart';

/// Balance Test Controller for SPPB balance component (uses new base controller)
class TestControllerSPPBBalance extends BaseTestController {
  TestControllerSPPBBalance({
    VoidCallback? onTestUpdate,
    VoidCallback? onTestComplete,
    Function(bool)? onStepComplete,
  }) : super(
          onTestUpdate: onTestUpdate,
          onTestComplete: onTestComplete,
          onStepComplete: onStepComplete,
        ) {
    // Suggest a frame processing interval
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
        label: 'Side-by-side Stand',
        targetLabel: 'balance_side_by_side',
        targetTimeSeconds: 10.0,
        maxTime: 15.0,
        confidenceThreshold: 0.8,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Semi-tandem Stand',
        targetLabel: 'balance_semi_tandem',
        targetTimeSeconds: 10.0,
        maxTime: 15.0,
        confidenceThreshold: 0.8,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Tandem Stand',
        targetLabel: 'balance_tandem',
        targetTimeSeconds: 10.0,
        maxTime: 15.0,
        confidenceThreshold: 0.8,
        frameProcessingIntervalMs: intervalMs,
      ),
    ];
  }

  /// Override step processing to look for a person in pose detections
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

    // Use the base helper to update counters and advance steps
    processStepDetectionResult(step, found);
  }
}
