import 'package:flutter/foundation.dart';
import 'base_test_controller.dart';
import '../services/isolate_detection_classes.dart';
import '../services/base_detection_service.dart';
import '../types/detection_types.dart';
import "../utils/step_constants.dart";

/// AVMED Test Controller using the new BaseTestControllerNew API
/// Implements the medication adherence test pipeline using the isolate AVMED model
class TestControllerAVMed extends BaseTestController {
  TestControllerAVMed({
    VoidCallback? onTestUpdate,
    VoidCallback? onTestComplete,
    Function(bool)? onStepComplete,
  }) : super(
          onTestUpdate: onTestUpdate,
          onTestComplete: onTestComplete,
          onStepComplete: onStepComplete,
        ) {
    // Recommend a processing interval (ms) for callers
    frameProcessingIntervalMs = 500.0;
  }

  @override
  Map<String, BaseDetectionService> createDetectionServices() {
    return {
      'objects': IsolateAVMedDetectionService(),
    };
  }

  @override
  List<TestStep> createTestSteps() {
    final intervalMs = frameProcessingIntervalMs;

    return [
      TestStep(
        label: 'Hold the pill',
        targetLabel: StepConstants.pill,
        videoPath: 'assets/instructions/holding-pill.mp4',
        targetTimeSeconds: 2.0,
        maxTime: 15.0,
        confidenceThreshold: 0.5,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Place pill on tongue',
        targetLabel: StepConstants.pillOnTongue,
        videoPath: 'assets/instructions/pill-on-tongue.mp4',
        targetTimeSeconds: 2.0,
        maxTime: 15.0,
        confidenceThreshold: 0.5,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Show no pill on tongue',
        targetLabel: StepConstants.noPillOnTongue,
        videoPath: 'assets/instructions/no-pill-on-tongue.mp4',
        targetTimeSeconds: 2.0,
        maxTime: 10.0,
        confidenceThreshold: 0.5,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Drink water',
        targetLabel: StepConstants.drinkWater,
        videoPath: 'assets/instructions/drink-water.mp4',
        targetTimeSeconds: 3.0,
        maxTime: 15.0,
        confidenceThreshold: 0.5,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Show no pill under tongue',
        targetLabel: StepConstants.noPillUnderTongue,
        videoPath: 'assets/instructions/no-pill-under-tongue.mp4',
        targetTimeSeconds: 2.0,
        maxTime: 10.0,
        confidenceThreshold: 0.5,
        frameProcessingIntervalMs: intervalMs,
      ),
    ];
  }

}
