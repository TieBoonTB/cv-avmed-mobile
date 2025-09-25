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
      'avmed': IsolateAVMedDetectionService(),
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
        maxTime: 10.0,
        confidenceThreshold: 0.7,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Place pill on tongue',
        targetLabel: StepConstants.pillOnTongue,
        videoPath: 'assets/instructions/pill-on-tongue.mp4',
        targetTimeSeconds: 2.0,
        maxTime: 15.0,
        confidenceThreshold: 0.7,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Show no pill on tongue',
        targetLabel: StepConstants.noPillOnTongue,
        videoPath: 'assets/instructions/no-pill-on-tongue.mp4',
        targetTimeSeconds: 2.0,
        maxTime: 10.0,
        confidenceThreshold: 0.7,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Drink water',
        targetLabel: StepConstants.drinkWater,
        videoPath: 'assets/instructions/drink-water.mp4',
        targetTimeSeconds: 3.0,
        maxTime: 15.0,
        confidenceThreshold: 0.65,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Show no pill under tongue',
        targetLabel: StepConstants.noPillUnderTongue,
        videoPath: 'assets/instructions/no-pill-under-tongue.mp4',
        targetTimeSeconds: 2.0,
        maxTime: 10.0,
        confidenceThreshold: 0.7,
        frameProcessingIntervalMs: intervalMs,
      ),
    ];
  }

  /// Override the test-step processing to use AVMED detection outputs
  @override
  Future<void> processTestStep() async {
    final step = currentStep;
    if (step == null) return;
    if (!step.isActive) return;

    // Get avmed detections
    final detections = getDetections('avmed');

    final targetLabel = (step.targetLabel ?? '').toLowerCase();
    final threshold = step.confidenceThreshold;

    bool found = false;
    switch (targetLabel) {
      case 'pill':
        found = _detectPill(detections, threshold);
        break;
      case 'pill on tongue':
        found = _detectPillOnTongue(detections, threshold);
        break;
      case 'no pill on tongue':
        found = _detectNoPillOnTongue(detections, threshold);
        break;
      case 'drink water':
        found = _detectDrinkingAction(detections, threshold);
        break;
      case 'no pill under tongue':
        found = _detectNoPillUnderTongue(detections, threshold);
        break;
      default:
        found = _detectGenericTarget(detections, targetLabel, threshold);
    }

    // Use the base helper to update counters / advance steps
    processStepDetectionResult(step, found);
  }

  // --- AVMED detection helper implementations ---
  bool _detectPill(List<DetectionResult> detections, double threshold) {
    for (final detection in detections) {
      if (detection.label.toLowerCase() == 'pill' &&
          detection.confidence >= threshold) {
        return true;
      }
    }
    return false;
  }

  bool _detectPillOnTongue(List<DetectionResult> detections, double threshold) {
    bool hasPill = false;
    bool hasMouthOrTongue = false;

    for (final detection in detections) {
      final label = detection.label.toLowerCase();
      final confidence = detection.confidence;

      if (label == 'pill' && confidence >= threshold) {
        hasPill = true;
      } else if ((label == 'mouth' || label == 'tongue') &&
          confidence >= threshold) {
        hasMouthOrTongue = true;
      }
    }

    return hasPill && hasMouthOrTongue;
  }

  bool _detectNoPillOnTongue(List<DetectionResult> detections, double threshold) {
    bool hasMouthOrTongue = false;
    bool hasPill = false;

    for (final detection in detections) {
      final label = detection.label.toLowerCase();
      final confidence = detection.confidence;

      if ((label == 'mouth' || label == 'tongue') && confidence >= threshold) {
        hasMouthOrTongue = true;
      } else if (label == 'pill' && confidence >= threshold) {
        hasPill = true;
      }
    }

    return hasMouthOrTongue && !hasPill;
  }

  bool _detectDrinkingAction(List<DetectionResult> detections, double threshold) {
    bool hasWaterOrCup = false;
    bool hasMouth = false;

    for (final detection in detections) {
      final label = detection.label.toLowerCase();
      final confidence = detection.confidence;

      if ((label == 'water' || label == 'cup') && confidence >= threshold) {
        hasWaterOrCup = true;
      } else if (label == 'mouth' && confidence >= threshold) {
        hasMouth = true;
      }
    }

    return hasWaterOrCup && hasMouth;
  }

  bool _detectNoPillUnderTongue(List<DetectionResult> detections, double threshold) {
    bool hasMouthOrTongue = false;
    bool hasPill = false;

    for (final detection in detections) {
      final label = detection.label.toLowerCase();
      final confidence = detection.confidence;

      if ((label == 'mouth' || label == 'tongue') && confidence >= threshold) {
        hasMouthOrTongue = true;
      } else if (label == 'pill' && confidence >= threshold) {
        hasPill = true;
      }
    }

    return hasMouthOrTongue && !hasPill;
  }

  bool _detectGenericTarget(
      List<DetectionResult> detections, String targetLabel, double threshold) {
    for (final detection in detections) {
      if (detection.label.toLowerCase() == targetLabel &&
          detection.confidence >= threshold) {
        return true;
      }
    }
    return false;
  }

  /// Return a simple summary of AVMED test results
  Map<String, dynamic> getAVMedTestResults() {
    final results = <String, dynamic>{
      'test_type': 'AVMED Medication Adherence',
      'total_steps': testSteps.length,
      'successful_steps': testSteps.where((s) => s.isSuccess).length,
      'step_details': <Map<String, dynamic>>[],
    };

    for (var i = 0; i < testSteps.length; i++) {
      final step = testSteps[i];
      results['step_details'].add({
        'step_number': i + 1,
        'label': step.label,
        'target_label': step.targetLabel,
        'is_completed': step.startTime != null && !step.isActive,
        'is_successful': step.isSuccess,
        'detected_frames': step.detectionsCount,
        'target_frames': step.detectionsRequired,
        'confidence_threshold': step.confidenceThreshold,
      });
    }

    final successful = results['successful_steps'] as int;
    final total = results['total_steps'] as int;
    results['adherence_compliance'] = total > 0 ? (successful / total) * 100 : 0.0;

    return results;
  }
}
