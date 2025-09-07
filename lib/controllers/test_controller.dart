import 'package:flutter/material.dart';

/// DEPRECATED: This class has been replaced by the new architecture.
/// Use MedicationTestController extending BaseTestController instead.
/// 
/// See:
/// - lib/controllers/base_test_controller.dart
/// - lib/controllers/medication_test_controller.dart
/// - lib/controllers/object_detection_test_controller.dart
/// - ARCHITECTURE.md for detailed documentation
@Deprecated('Use MedicationTestController or ObjectDetectionTestController instead')
class StepConstants {
  static const String pill = 'pill';
  static const String pillOnTongue = 'pill on tongue';
  static const String noPillOnTongue = 'no pill on tongue';
  static const String drinkWater = 'drink water';
  static const String pleaseUseTransparentCup = 'please use transparent cup';
  static const String mouthCovered = 'mouth covered';
  static const String noPillUnderTongue = 'no pill under tongue';
}

/// DEPRECATED: This class has been replaced by the new architecture.
/// Use MedicationTestController extending BaseTestController instead.
@Deprecated('Use MedicationTestController or ObjectDetectionTestController instead')
class TestStep {
  final String label;
  final String targetLabel;
  final String? videoPath;
  final String? subtitlePath;
  final double targetTime;
  final double maxTime;
  final double confidenceThreshold;
  bool isActive;
  bool isDone;
  bool isSuccess;
  
  // Detection progress
  int detectedFrameCount = 0;
  int targetFrameCount = 0;

  TestStep({
    required this.label,
    required this.targetLabel,
    this.videoPath,
    this.subtitlePath,
    required this.targetTime,
    required this.maxTime,
    required this.confidenceThreshold,
    this.isActive = false,
    this.isDone = false,
    this.isSuccess = false,
  }) {
    // Calculate target frame count (assuming 30 FPS)
    targetFrameCount = (targetTime * 30).round();
  }
  
  double get progress => targetFrameCount > 0 ? detectedFrameCount / targetFrameCount : 0.0;
  bool get isTargetReached => detectedFrameCount >= targetFrameCount;
}

/// DEPRECATED: This class has been replaced by the new architecture.
/// Use MedicationTestController extending BaseTestController instead.
/// 
/// The new architecture provides:
/// - Abstract base classes for extensibility
/// - Separate detection services for different models
/// - Better separation of concerns
/// - Easier testing and maintenance
/// 
/// Migration example:
/// ```dart
/// // Old way
/// final controller = TestController(isTrial: true);
/// 
/// // New way
/// final controller = MedicationTestController(
///   isTrial: true,
///   onTestUpdate: () => setState(() {}),
///   onTestComplete: () => print('Done'),
///   onStepComplete: (success) => print('Step: $success'),
/// );
/// await controller.initialize();
/// ```
@Deprecated('Use MedicationTestController or ObjectDetectionTestController instead')
class TestController {
  final bool isTrial;
  final VoidCallback? onTestUpdate;
  final VoidCallback? onTestComplete;
  final Function(bool isSuccess)? onStepComplete;

  TestController({
    required this.isTrial,
    this.onTestUpdate,
    this.onTestComplete,
    this.onStepComplete,
  });

  // Test state
  bool _hasTestStarted = false;
  bool _isTestRunning = false;
  bool _isCompleted = false;
  
  // Test steps with enhanced detection parameters
  final List<TestStep> _testSteps = [
    TestStep(
      label: 'Holding Pill',
      targetLabel: StepConstants.pill,
      videoPath: 'assets/instructions/holding-pill.mp4',
      targetTime: 0.5, // Reduced for faster testing
      maxTime: 3.0, // Reduced for faster testing
      confidenceThreshold: 0.65,
    ),
    TestStep(
      label: 'Pill on Tongue',
      targetLabel: StepConstants.pillOnTongue,
      videoPath: 'assets/instructions/pill-on-tongue.mp4',
      targetTime: 0.5, // Reduced for faster testing
      maxTime: 3.0, // Reduced for faster testing
      confidenceThreshold: 0.7,
    ),
    TestStep(
      label: 'Drink water',
      targetLabel: StepConstants.drinkWater,
      videoPath: 'assets/instructions/drink-water.mp4',
      targetTime: 0.5, // Reduced for faster testing
      maxTime: 3.0, // Reduced for faster testing
      confidenceThreshold: 0.7,
    ),
    TestStep(
      label: 'No Pill on Tongue',
      targetLabel: StepConstants.noPillOnTongue,
      videoPath: 'assets/instructions/no-pill-on-tongue.mp4',
      targetTime: 0.5, // Reduced for faster testing
      maxTime: 3.0, // Reduced for faster testing
      confidenceThreshold: 0.7,
    ),
    TestStep(
      label: 'No Pill under Tongue',
      targetLabel: StepConstants.noPillUnderTongue,
      videoPath: 'assets/instructions/no-pill-under-tongue.mp4',
      targetTime: 0.5, // Reduced for faster testing
      maxTime: 3.0, // Reduced for faster testing
      confidenceThreshold: 0.7,
    ),
  ];

  // Getters
  bool get hasTestStarted => _hasTestStarted;
  bool get isTestRunning => _isTestRunning;
  bool get isCompleted => _isCompleted;
  List<TestStep> get testSteps => _testSteps;

  void startTest() {
    _hasTestStarted = true;
    _isTestRunning = true;
    _testSteps[0].isActive = true;
    
    onTestUpdate?.call();
    _runTestSequence();
  }

  Future<void> _runTestSequence() async {
    for (int i = 0; i < _testSteps.length; i++) {
      if (!_isTestRunning) break;
      
      // Reset previous step
      if (i > 0) {
        _testSteps[i - 1].isActive = false;
      }
      _testSteps[i].isActive = true;
      
      onTestUpdate?.call();
      
      // Run step with timeout and detection logic
      bool isSuccess = await _runStepWithDetection(_testSteps[i]);
      
      if (_isTestRunning) {
        _testSteps[i].isActive = false;
        _testSteps[i].isDone = true;
        _testSteps[i].isSuccess = isSuccess;
        
        onTestUpdate?.call();
        onStepComplete?.call(isSuccess);
      }
    }
    
    if (_isTestRunning) {
      await endTest();
    }
  }

  Future<bool> _runStepWithDetection(TestStep step) async {
    step.detectedFrameCount = 0;
    
    // Start step timer
    final stepStartTime = DateTime.now();
    final maxDuration = Duration(milliseconds: (step.maxTime * 1000).round());
    
    // Simulate detection loop (in real implementation, this would come from camera/ML detection)
    while (_isTestRunning && DateTime.now().difference(stepStartTime) < maxDuration) {
      // Simulate frame detection - faster for testing
      await Future.delayed(const Duration(milliseconds: 100)); // Faster frame rate for testing
      
      // Simulate detection success based on step requirements
      if (_simulateDetection(step)) {
        step.detectedFrameCount++;
        onTestUpdate?.call(); // Update UI with progress
        
        // Check if target is reached
        if (step.isTargetReached) {
          return true;
        }
      }
    }
    
    return false; // Timeout or failed to meet target
  }

  bool _simulateDetection(TestStep step) {
    // MOCK: Always return true to simulate successful detection
    // This ensures all steps pass for testing purposes
    return true;
  }

  // Method to handle real detection results (for future integration)
  void processDetectionResult({
    required String detectedLabel,
    required double confidence,
    required TestStep currentStep,
  }) {
    final isTarget = detectedLabel == currentStep.targetLabel && 
                    confidence >= currentStep.confidenceThreshold;
    
    if (isTarget) {
      currentStep.detectedFrameCount++;
      onTestUpdate?.call();
    }
  }

  Future<void> endTest() async {
    _isTestRunning = false;
    _isCompleted = true;
    
    onTestUpdate?.call();
    onTestComplete?.call();
  }

  void resetTest() {
    _hasTestStarted = false;
    _isTestRunning = false;
    _isCompleted = false;
    
    for (var step in _testSteps) {
      step.isActive = false;
      step.isDone = false;
      step.isSuccess = false;
    }
    
    onTestUpdate?.call();
  }

  void forceStopTest() {
    _isTestRunning = false;
    onTestUpdate?.call();
  }
}
