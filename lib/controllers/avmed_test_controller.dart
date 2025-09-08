import '../controllers/base_test_controller.dart';
import '../services/base_detection_service.dart';
import '../services/avmed_detection_service.dart';
import '../types/detection_types.dart';

/// AVMED Test Controller for medication adherence monitoring
/// Implements the medication adherence test pipeline using dual model detection
/// Based on the AVMED pipeline plan for on-device inference
class AVMedTestController extends BaseTestController {
  
  AVMedTestController({
    required super.isTrial,
    super.onTestUpdate,
    super.onTestComplete,
    super.onStepComplete,
  });

  @override
  BaseDetectionService createDetectionService() {
    return AVMedDetectionService();
  }

  @override
  List<TestStep> createTestSteps() {
    return [
      TestStep(
        label: 'Hold the pill',
        targetLabel: StepConstants.pill,
        videoPath: 'assets/instructions/holding-pill.mp4',
        targetTime: 2.0, // Time to hold pill detectably
        maxTime: 10.0,   // Maximum time allowed for step
        confidenceThreshold: 0.7, // AVMED main detection confidence
      ),
      TestStep(
        label: 'Place pill on tongue',
        targetLabel: StepConstants.pillOnTongue,
        videoPath: 'assets/instructions/pill-on-tongue.mp4',
        targetTime: 2.0,
        maxTime: 15.0,
        confidenceThreshold: 0.7,
      ),
      TestStep(
        label: 'Show no pill on tongue',
        targetLabel: StepConstants.noPillOnTongue,
        videoPath: 'assets/instructions/no-pill-on-tongue.mp4',
        targetTime: 2.0,
        maxTime: 10.0,
        confidenceThreshold: 0.7,
      ),
      TestStep(
        label: 'Drink water',
        targetLabel: StepConstants.drinkWater,
        videoPath: 'assets/instructions/drink-water.mp4',
        targetTime: 3.0, // Longer time for drinking action
        maxTime: 15.0,
        confidenceThreshold: 0.65, // Slightly lower for complex action
      ),
      TestStep(
        label: 'Show no pill under tongue',
        targetLabel: StepConstants.noPillUnderTongue,
        videoPath: 'assets/instructions/no-pill-under-tongue.mp4',
        targetTime: 2.0,
        maxTime: 10.0,
        confidenceThreshold: 0.7,
      ),
    ];
  }

  @override
  bool processDetectionResult(List<DetectionResult> detections, TestStep currentStep) {
    // AVMED-specific detection processing logic
    
    final targetLabel = currentStep.targetLabel.toLowerCase();
    final threshold = currentStep.confidenceThreshold;
    
    // Handle different AVMED detection scenarios
    switch (targetLabel) {
      case 'pill':
        return _detectPill(detections, threshold);
      
      case 'pill on tongue':
        return _detectPillOnTongue(detections, threshold);
      
      case 'no pill on tongue':
        return _detectNoPillOnTongue(detections, threshold);
      
      case 'drink water':
        return _detectDrinkingAction(detections, threshold);
      
      case 'no pill under tongue':
        return _detectNoPillUnderTongue(detections, threshold);
      
      default:
        return _detectGenericTarget(detections, targetLabel, threshold);
    }
  }

  /// Detect pill being held
  bool _detectPill(List<DetectionResult> detections, double threshold) {
    // Look for pill detection with sufficient confidence
    for (final detection in detections) {
      if (detection.label.toLowerCase() == 'pill' && 
          detection.confidence >= threshold) {
        return true;
      }
    }
    return false;
  }

  /// Detect pill placement on tongue
  /// Requires both pill and mouth/tongue detection
  bool _detectPillOnTongue(List<DetectionResult> detections, double threshold) {
    bool hasPill = false;
    bool hasMouthOrTongue = false;
    
    for (final detection in detections) {
      final label = detection.label.toLowerCase();
      final confidence = detection.confidence;
      
      if (label == 'pill' && confidence >= threshold) {
        hasPill = true;
      } else if ((label == 'mouth' || label == 'tongue') && confidence >= threshold) {
        hasMouthOrTongue = true;
      }
    }
    
    // Both pill and mouth/tongue should be detected
    return hasPill && hasMouthOrTongue;
  }

  /// Detect absence of pill on tongue
  /// Should detect mouth/tongue but no pill
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
    
    // Should detect mouth/tongue but no pill
    return hasMouthOrTongue && !hasPill;
  }

  /// Detect drinking action
  /// Look for water/cup and mouth interaction
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
    
    // Drinking requires both water/cup and mouth
    return hasWaterOrCup && hasMouth;
  }

  /// Detect no pill under tongue
  /// Similar to no pill on tongue but specifically under tongue
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
    
    // Should detect mouth/tongue but no pill
    return hasMouthOrTongue && !hasPill;
  }

  /// Generic target detection for fallback
  bool _detectGenericTarget(List<DetectionResult> detections, String targetLabel, double threshold) {
    for (final detection in detections) {
      if (detection.label.toLowerCase() == targetLabel && 
          detection.confidence >= threshold) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<void> onStepStart(TestStep step) async {
    print('AVMED Step started: ${step.label}');
    
    // AVMED-specific step initialization
    if (detectionService is AVMedDetectionService) {
      final avmedService = detectionService as AVMedDetectionService;
      final stats = avmedService.getDetectionStats();
      print('Detection stats at step start: $stats');
    }
  }

  @override
  Future<void> onStepEnd(TestStep step, bool isSuccess) async {
    print('AVMED Step completed: ${step.label}, Success: $isSuccess');
    
    // Log detailed step completion information
    if (detectionService is AVMedDetectionService) {
      final avmedService = detectionService as AVMedDetectionService;
      final stats = avmedService.getDetectionStats();
      print('Final detection stats for step: $stats');
    }
    
    // Additional logging for medication adherence compliance
    if (isSuccess) {
      print('✅ Medication adherence step "${step.label}" completed successfully');
    } else {
      print('❌ Medication adherence step "${step.label}" failed - may require assistance');
    }
  }

  /// Get AVMED-specific test results
  Map<String, dynamic> getAVMedTestResults() {
    final results = <String, dynamic>{
      'test_type': 'AVMED Medication Adherence',
      'total_steps': testSteps.length,
      'completed_steps': testSteps.where((step) => step.isDone).length,
      'successful_steps': testSteps.where((step) => step.isSuccess).length,
      'step_details': [],
    };
    
    for (int i = 0; i < testSteps.length; i++) {
      final step = testSteps[i];
      results['step_details'].add({
        'step_number': i + 1,
        'label': step.label,
        'target_label': step.targetLabel,
        'is_completed': step.isDone,
        'is_successful': step.isSuccess,
        'detected_frames': step.detectedFrameCount,
        'target_frames': step.targetFrameCount,
        'confidence_threshold': step.confidenceThreshold,
      });
    }
    
    // Calculate adherence compliance percentage
    final successfulSteps = results['successful_steps'] as int;
    final totalSteps = results['total_steps'] as int;
    results['adherence_compliance'] = totalSteps > 0 ? (successfulSteps / totalSteps) * 100 : 0.0;
    
    return results;
  }
}
