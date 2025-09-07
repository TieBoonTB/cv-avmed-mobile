import '../controllers/base_test_controller.dart';
import '../services/base_detection_service.dart';
import '../services/mock_detection_service.dart';
import '../types/detection_types.dart';

/// Mock test controller using mock detection service
/// This test simulates detection behavior with predefined mock results for testing
class MockTestController extends BaseTestController {
  
  MockTestController({
    required super.isTrial,
    super.onTestUpdate,
    super.onTestComplete,
    super.onStepComplete,
  });

  @override
  BaseDetectionService createDetectionService() {
    return MockDetectionService();
  }

  @override
  List<TestStep> createTestSteps() {
    return [
      TestStep(
        label: 'Mock Step 1',
        targetLabel: StepConstants.pill,
        videoPath: 'assets/instructions/holding-pill.mp4',
        targetTime: 1.0, // Increased from 0.5 to 1.0 seconds
        maxTime: 5.0,    // Increased from 3.0 to 5.0 seconds
        confidenceThreshold: 0.65,
      ),
      TestStep(
        label: 'Mock Step 2',
        targetLabel: StepConstants.person,
        videoPath: 'assets/instructions/pill-on-tongue.mp4',
        targetTime: 1.0, // Increased from 0.5 to 1.0 seconds
        maxTime: 5.0,    // Increased from 3.0 to 5.0 seconds
        confidenceThreshold: 0.7,
      ),
      TestStep(
        label: 'Mock Step 3',
        targetLabel: StepConstants.pill,
        videoPath: 'assets/instructions/drink-water.mp4',
        targetTime: 1.0, // Increased from 0.5 to 1.0 seconds
        maxTime: 5.0,    // Increased from 3.0 to 5.0 seconds
        confidenceThreshold: 0.7,
      ),
    ];
  }

  @override
  bool processDetectionResult(List<DetectionResult> detections, TestStep currentStep) {
    print('Processing ${detections.length} detections for step: ${currentStep.label}');
    for (final detection in detections) {
      print('  Found: ${detection.label} with confidence ${detection.confidence}');
    }
    
    // Look for the target label in the detections
    for (final detection in detections) {
      if (detection.label == currentStep.targetLabel && 
          detection.confidence >= currentStep.confidenceThreshold) {
        print('  ✅ Match found: ${detection.label} (${detection.confidence}) >= ${currentStep.confidenceThreshold}');
        return true;
      }
    }
    print('  ❌ No matching detection found for: ${currentStep.targetLabel}');
    return false;
  }

  @override
  Future<void> onStepStart(TestStep step) async {
    print('Mock test step started: ${step.label}');
    print('Looking for: ${step.targetLabel} with confidence >= ${step.confidenceThreshold}');
  }

  @override
  Future<void> onStepEnd(TestStep step, bool isSuccess) async {
    print('Mock test step completed: ${step.label} - Success: $isSuccess');
    print('  Progress: ${step.detectedFrameCount}/${step.targetFrameCount} detections');
    print('  Target reached: ${step.isTargetReached}');
  }
}
