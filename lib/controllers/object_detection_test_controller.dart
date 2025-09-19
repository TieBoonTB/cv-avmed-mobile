import '../controllers/base_test_controller.dart';
import '../services/base_detection_service.dart';
import '../services/isolate_detection_classes.dart';
import '../types/detection_types.dart';

/// Object detection test controller using YOLOv5
/// This test detects common objects and moves through different object types
class ObjectDetectionTestController extends BaseTestController {
  ObjectDetectionTestController({
    required super.isTrial,
    super.onTestUpdate,
    super.onTestComplete,
    super.onStepComplete,
  });

  @override
  Map<String, BaseDetectionService> createDetectionServices() {
    return {
      'objects': IsolateYOLOv5DetectionService(),
    };
  }

  @override
  List<TestStep> createTestSteps() {
    return [
      TestStep(
        label: 'Show a Bottle',
        targetLabel: StepConstants.bottle,
        targetTime: 3,
        maxTime: 10.0,
        confidenceThreshold: 0.6,
      ),
      TestStep(
        label: 'Show a Cup',
        targetLabel: StepConstants.cup,
        targetTime: 3,
        maxTime: 10.0,
        confidenceThreshold: 0.6,
      ),
      TestStep(
        label: 'Show a Book',
        targetLabel: StepConstants.book,
        targetTime: 3,
        maxTime: 10.0,
        confidenceThreshold: 0.6,
      ),
      TestStep(
        label: 'Show a Cell Phone',
        targetLabel: StepConstants.cellPhone,
        targetTime: 3,
        maxTime: 10.0,
        confidenceThreshold: 0.6,
      ),
    ];
  }

  @override
  String? get currentStepInstructions {
    return currentStep?.label;
  }

  @override
  bool processDetectionResults(
      Map<String, List<DetectionResult>> detectionsByService,
      TestStep currentStep) {
    // Get object detections
    final detections = detectionsByService['objects'] ?? [];

    // Look for the target label in the detections
    for (final detection in detections) {
      if (detection.label == currentStep.targetLabel &&
          detection.confidence >= currentStep.confidenceThreshold) {
        print(
            'Detected ${detection.label} with confidence ${detection.confidence.toStringAsFixed(2)}');
        return true;
      }
    }
    return false;
  }

  @override
  Future<void> onStepStart(TestStep step) async {
    print('Object detection step started: ${step.label}');
    print(
        'Looking for: ${step.targetLabel} with confidence >= ${step.confidenceThreshold}');
    print('Point the camera at a ${step.targetLabel} object');
  }

  @override
  Future<void> onStepEnd(TestStep step, bool isSuccess) async {
    if (isSuccess) {
      print('Successfully detected ${step.targetLabel}!');
    } else {
      print('Failed to detect ${step.targetLabel} within time limit');
    }
  }

  /// Get isolate-based YOLOv5 detection service for advanced operations
  IsolateYOLOv5DetectionService get yoloService =>
      detectionServices['objects'] as IsolateYOLOv5DetectionService;

  /// Get all current detections with their confidence scores
  List<DetectionResult> getAllDetections() {
    return getDetections('objects');
  }

  /// Get detections filtered by confidence
  List<DetectionResult> getHighConfidenceDetections(
      {double minConfidence = 0.5}) {
    return getDetections('objects')
        .where((detection) => detection.confidence >= minConfidence)
        .toList();
  }
}
