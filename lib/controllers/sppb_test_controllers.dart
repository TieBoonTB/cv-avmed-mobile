import '../controllers/base_test_controller.dart';
import '../services/base_detection_service.dart';
import '../services/sppb_detection_services.dart';
import '../types/detection_types.dart';

/// Chair Stand Test Controller implementing SPPB protocol
class ChairStandTestController extends BaseTestController {
  // Detection services
  late final ChairDetectionService _chairService;
  late final PoseDetectionService _poseService;
  late final SPPBAnalysisService _analysisService;

  // Test state
  SPPBTestPhase _currentPhase = SPPBTestPhase.setup;
  SPPBTestMetrics? _currentMetrics;
  
  // Test parameters
  static const int targetRepetitions = 5;
  static const double maxTestTime = 60.0; // seconds
  static const int setupValidationFrames = 30; // ~1 second
  
  int _setupValidationCount = 0;
  DateTime? _testStartTime;

  ChairStandTestController({
    required super.isTrial,
    super.onTestUpdate,
    super.onTestComplete,
    super.onStepComplete,
  }) {
    _chairService = ChairDetectionService();
    _poseService = PoseDetectionService();
    _analysisService = SPPBAnalysisService();
  }

  @override
  Future<void> initialize() async {
    // Initialize the base detection service (chair service as primary)
    await super.initialize();
    
    // Initialize additional services
    await _poseService.initialize();
    await _analysisService.initialize();
    
    print('SPPB Controller: All services initialized');
  }

  @override
  BaseDetectionService createDetectionService() {
    // Return the chair detection service as the primary detection service
    return _chairService;
  }

  @override
  List<TestStep> createTestSteps() {
    return [
      TestStep(
        label: 'Setup Validation',
        targetLabel: 'setup',
        targetTime: 3.0,
        maxTime: 10.0,
        confidenceThreshold: 0.8,
      ),
      TestStep(
        label: 'Chair Detection',
        targetLabel: 'chair',
        targetTime: 2.0,
        maxTime: 10.0,
        confidenceThreshold: 0.7,
      ),
      TestStep(
        label: 'Person Detection',
        targetLabel: 'person',
        targetTime: 2.0,
        maxTime: 10.0,
        confidenceThreshold: 0.8,
      ),
      TestStep(
        label: 'Chair Stand Test',
        targetLabel: 'chair_stand',
        targetTime: maxTestTime,
        maxTime: maxTestTime,
        confidenceThreshold: 0.6,
      ),
      TestStep(
        label: 'Results Analysis',
        targetLabel: 'results',
        targetTime: 2.0,
        maxTime: 5.0,
        confidenceThreshold: 1.0,
      ),
    ];
  }

  @override
  bool processDetectionResult(List<DetectionResult> detections, TestStep currentStep) {
    // Log the detection process for debugging
    print('SPPB Processing ${detections.length} detections for step: ${currentStep.label}');
    print('Current phase: $_currentPhase');
    
    switch (_currentPhase) {
      case SPPBTestPhase.setup:
        return _validateSetupPhase(detections, currentStep);
      case SPPBTestPhase.detectChair:
        return _validateChairDetection(detections);
      case SPPBTestPhase.detectPerson:
        return _validatePersonDetection(detections);
      case SPPBTestPhase.chairStandTest:
        return _processChairStandDetection(detections);
      case SPPBTestPhase.results:
        return _validateResultsPhase(detections, currentStep);
    }
  }

  /// Validate setup phase - should detect environment is ready
  bool _validateSetupPhase(List<DetectionResult> detections, TestStep currentStep) {
    // For setup, we just need some valid detections to show camera is working
    // But we should be more strict than just returning true
    print('  Setup phase: Found ${detections.length} detections');
    return detections.isNotEmpty; // At least some detections needed
  }

  bool _validateChairDetection(List<DetectionResult> detections) {
    print('  Chair detection: Looking for chairs in ${detections.length} detections');
    final result = _chairService.validateChairSetup(detections);
    print('  Chair detection result: $result');
    return result;
  }

  bool _validatePersonDetection(List<DetectionResult> detections) {
    print('  Person detection: Looking for person pose in ${detections.length} detections');
    final result = _poseService.validatePersonPosition(detections);
    print('  Person detection result: $result');
    return result;
  }

  bool _processChairStandDetection(List<DetectionResult> detections) {
    print('  Chair stand test: Processing ${detections.length} detections');
    final landmarks = _poseService.extractLandmarks(detections);
    
    if (landmarks.isNotEmpty) {
      print('  Found ${landmarks.length} landmarks, analyzing movement...');
      _analysisService.analyzeMovement(
        landmarks: landmarks,
        timestamp: DateTime.now(),
      );
      
      _currentMetrics = _analysisService.getTestMetrics();
      print('  Completed repetitions: ${_currentMetrics?.completedRepetitions ?? 0}');
      
      // Check for test completion or timeout
      if (_currentMetrics != null && _testStartTime != null) {
        final elapsed = DateTime.now().difference(_testStartTime!).inSeconds;
        if (_currentMetrics!.completedRepetitions >= targetRepetitions || elapsed >= maxTestTime) {
          print('  Test should complete: reps=${_currentMetrics!.completedRepetitions}, elapsed=${elapsed}s');
        }
      }
      
      return true;
    }
    
    print('  No landmarks detected');
    return false;
  }

  /// Validate results phase - should have valid test results
  bool _validateResultsPhase(List<DetectionResult> detections, TestStep currentStep) {
    // Results phase should validate that we have meaningful test results
    print('  Results phase: Metrics available: ${_currentMetrics != null}');
    return _currentMetrics != null && _currentMetrics!.completedRepetitions > 0;
  }

  int get currentPhaseIndex {
    switch (_currentPhase) {
      case SPPBTestPhase.setup:
        return 0;
      case SPPBTestPhase.detectChair:
        return 1;
      case SPPBTestPhase.detectPerson:
        return 2;
      case SPPBTestPhase.chairStandTest:
        return 3;
      case SPPBTestPhase.results:
        return 4;
    }
  }

  double get testProgress {
    switch (_currentPhase) {
      case SPPBTestPhase.setup:
        return _setupValidationCount / setupValidationFrames;
      case SPPBTestPhase.detectChair:
        return 0.2;
      case SPPBTestPhase.detectPerson:
        return 0.4;
      case SPPBTestPhase.chairStandTest:
        final metrics = _currentMetrics;
        if (metrics == null) return 0.6;
        return 0.6 + (0.3 * (metrics.completedRepetitions / targetRepetitions));
      case SPPBTestPhase.results:
        return 1.0;
    }
  }

  String get currentStepInstructions {
    switch (_currentPhase) {
      case SPPBTestPhase.setup:
        return 'Setting up test environment...';
      case SPPBTestPhase.detectChair:
        return 'Please position yourself in front of a chair. The chair should be clearly visible in the camera.';
      case SPPBTestPhase.detectPerson:
        return 'Sit down in the chair. Make sure your full body is visible in the camera.';
      case SPPBTestPhase.chairStandTest:
        final metrics = _currentMetrics;
        final completed = metrics?.completedRepetitions ?? 0;
        return 'Stand up and sit down 5 times as quickly as possible. Completed: $completed/5';
      case SPPBTestPhase.results:
        return 'Test completed! Analyzing your performance...';
    }
  }





  /// Get final test results
  SPPBTestResults getTestResults() {
    if (_currentMetrics == null) {
      return SPPBTestResults.failed();
    }

    final score = _currentMetrics!.calculateSPPBScore();
    final isSuccessful = _currentMetrics!.completedRepetitions >= targetRepetitions;

    return SPPBTestResults(
      isSuccessful: isSuccessful,
      completedRepetitions: _currentMetrics!.completedRepetitions,
      totalTime: _currentMetrics!.totalTestTime,
      averageRepetitionTime: _currentMetrics!.averageRepetitionTime,
      sppbScore: score,
      movementSmoothness: _currentMetrics!.movementSmoothness,
      repetitionTimes: _currentMetrics!.repetitionTimes,
    );
  }

  /// Initialize the SPPB test state
  Future<void> initializeTest() async {
    _currentPhase = SPPBTestPhase.setup;
    _setupValidationCount = 0;
    _testStartTime = null;
    _currentMetrics = null;
    
    // Reset analysis service
    _analysisService.resetMetrics();
    
    print('SPPB Test initialized');
  }

  @override
  Future<void> onStepStart(TestStep step) async {
    await super.onStepStart(step);
    
    // Synchronize internal phase with test steps
    switch (step.label) {
      case 'Setup Validation':
        await initializeTest();
        _currentPhase = SPPBTestPhase.setup;
      case 'Chair Detection':
        _currentPhase = SPPBTestPhase.detectChair;
      case 'Person Detection':
        _currentPhase = SPPBTestPhase.detectPerson;
      case 'Chair Stand Test':
        _currentPhase = SPPBTestPhase.chairStandTest;
        _testStartTime = DateTime.now();
      case 'Results Analysis':
        _currentPhase = SPPBTestPhase.results;
    }
    
    print('SPPB Step started: ${step.label}, Phase: $_currentPhase');
  }

  @override
  Future<void> onStepEnd(TestStep step, bool isSuccess) async {
    await super.onStepEnd(step, isSuccess);
    print('SPPB Step completed: ${step.label} - Success: $isSuccess');
  }

  Future<void> stopTest() async {
    _currentPhase = SPPBTestPhase.results;
    onTestUpdate?.call();
  }

  @override
  void dispose() {
    // Dispose all services manually since we use multiple services
    try {
      _chairService.dispose();
    } catch (e) {
      print('Error disposing chair service: $e');
    }
    
    try {
      _poseService.dispose();
    } catch (e) {
      print('Error disposing pose service: $e');
    }
    
    try {
      _analysisService.dispose();
    } catch (e) {
      print('Error disposing analysis service: $e');
    }
    
    // Call parent dispose to handle the main detection service
    super.dispose();
  }
}

/// Balance Test Controller for SPPB balance component
class BalanceTestController extends BaseTestController {
  final PoseDetectionService _poseService = PoseDetectionService();
  
  BalanceTestController({
    required super.isTrial,
    super.onTestUpdate,
    super.onTestComplete,
    super.onStepComplete,
  });

  @override
  BaseDetectionService createDetectionService() {
    return _poseService;
  }

  @override
  List<TestStep> createTestSteps() {
    return [
      TestStep(
        label: 'Side-by-side Stand',
        targetLabel: 'balance_side_by_side',
        targetTime: 10.0,
        maxTime: 15.0,
        confidenceThreshold: 0.8,
      ),
      TestStep(
        label: 'Semi-tandem Stand',
        targetLabel: 'balance_semi_tandem',
        targetTime: 10.0,
        maxTime: 15.0,
        confidenceThreshold: 0.8,
      ),
      TestStep(
        label: 'Tandem Stand',
        targetLabel: 'balance_tandem',
        targetTime: 10.0,
        maxTime: 15.0,
        confidenceThreshold: 0.8,
      ),
    ];
  }

  @override
  bool processDetectionResult(List<DetectionResult> detections, TestStep currentStep) {
    // TODO: Implement balance-specific detection logic
    return true;
  }
}

/// Gait Speed Test Controller for SPPB gait component
class GaitTestController extends BaseTestController {
  final PoseDetectionService _poseService = PoseDetectionService();
  
  GaitTestController({
    required super.isTrial,
    super.onTestUpdate,
    super.onTestComplete,
    super.onStepComplete,
  });

  @override
  BaseDetectionService createDetectionService() {
    return _poseService;
  }

  @override
  List<TestStep> createTestSteps() {
    return [
      TestStep(
        label: 'Setup Walking Path',
        targetLabel: 'gait_setup',
        targetTime: 5.0,
        maxTime: 10.0,
        confidenceThreshold: 0.8,
      ),
      TestStep(
        label: 'Normal Pace Walk',
        targetLabel: 'gait_normal',
        targetTime: 15.0,
        maxTime: 30.0,
        confidenceThreshold: 0.7,
      ),
      TestStep(
        label: 'Fast Pace Walk',
        targetLabel: 'gait_fast',
        targetTime: 10.0,
        maxTime: 20.0,
        confidenceThreshold: 0.7,
      ),
    ];
  }

  @override
  bool processDetectionResult(List<DetectionResult> detections, TestStep currentStep) {
    // TODO: Implement gait-specific detection logic
    return true;
  }
}

/// Test phases for SPPB Chair Stand Test
enum SPPBTestPhase {
  setup,
  detectChair,
  detectPerson,
  chairStandTest,
  results,
}

/// Test results class for SPPB Chair Stand Test
class SPPBTestResults {
  final bool isSuccessful;
  final int completedRepetitions;
  final double totalTime;
  final double averageRepetitionTime;
  final int sppbScore;
  final double movementSmoothness;
  final List<double> repetitionTimes;

  SPPBTestResults({
    required this.isSuccessful,
    required this.completedRepetitions,
    required this.totalTime,
    required this.averageRepetitionTime,
    required this.sppbScore,
    required this.movementSmoothness,
    required this.repetitionTimes,
  });

  factory SPPBTestResults.failed() {
    return SPPBTestResults(
      isSuccessful: false,
      completedRepetitions: 0,
      totalTime: 0.0,
      averageRepetitionTime: 0.0,
      sppbScore: 0,
      movementSmoothness: 0.0,
      repetitionTimes: [],
    );
  }

  /// Get performance grade based on SPPB score
  String get performanceGrade {
    switch (sppbScore) {
      case 4:
        return 'Excellent';
      case 3:
        return 'Good';
      case 2:
        return 'Fair';
      case 1:
        return 'Poor';
      default:
        return 'Unable to Complete';
    }
  }
}
