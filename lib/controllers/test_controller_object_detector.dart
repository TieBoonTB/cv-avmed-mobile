import 'package:flutter/foundation.dart';
import 'base_test_controller.dart';
import '../services/isolate_detection_classes.dart';
import '../services/base_detection_service.dart';

/// Simple object detection test controller using YOLOv5 (isolate)
/// The default step processing in the base class will look for the
/// step.targetLabel in the detections and increment detections.
class TestControllerObjectDetector extends BaseTestController {
  TestControllerObjectDetector({
    VoidCallback? onTestUpdate,
    VoidCallback? onTestComplete,
    Function(bool)? onStepComplete,
  }) : super(
          onTestUpdate: onTestUpdate,
          onTestComplete: onTestComplete,
          onStepComplete: onStepComplete,
        ) {
    // Set preferred frame processing interval (ms)
    frameProcessingIntervalMs = 500.0;
  }

  @override
  Map<String, BaseDetectionService> createDetectionServices() {
    return {
      'objects': IsolateYOLOv5DetectionService(),
    };
  }

  @override
  List<TestStep> createTestSteps() {
    // Use the controller's preferred frame interval when creating steps
    final intervalMs = frameProcessingIntervalMs;

    return [
      TestStep(
        label: 'person',
        targetLabel: 'person',
        instruction: 'Show a person in frame',
        frameProcessingIntervalMs: intervalMs,
        targetTimeSeconds: 2,
        maxTime: 10
      ),
      TestStep(
        label: 'bottle',
        targetLabel: 'bottle',
        instruction: 'Show a bottle in frame',
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'cup',
        targetLabel: 'cup',
        instruction: 'Show a cup in frame',
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'cell phone',
        targetLabel: 'cell phone',
        instruction: 'Show a cell phone in frame',
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'laptop',
        targetLabel: 'laptop',
        instruction: 'Show a laptop in frame',
        frameProcessingIntervalMs: intervalMs,
      ),
    ];
  }
}
