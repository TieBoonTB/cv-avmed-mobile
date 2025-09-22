import 'package:camera/camera.dart';
import '../utils/camera_image_utils.dart';
import '../services/isolate_detection_classes.dart';
import '../services/mlkit_pose_detection_service.dart';
import '../controllers/base_test_controller.dart';
import '../services/base_detection_service.dart';
import '../services/sppb_detection_services.dart';
import '../types/detection_types.dart';

/// Chair Stand Test Controller implementing SPPB protocol
class ChairStandTestController extends BaseTestController {
  // Test state
  SPPBTestPhase _currentPhase = SPPBTestPhase.setup;
  SPPBTestMetrics? _currentMetrics;
  // Guards for repetition detection reaction
  int _lastSeenRepCount = 0;
  DateTime? _lastRepReactionTime;

  // Test parameters
  static const int targetRepetitions = 3;
  static const double maxTestTime = 60.0; // seconds
  static const int setupValidationFrames = 30; // ~1 second

  int _setupValidationCount = 0;
  DateTime? _testStartTime;

  ChairStandTestController({
    required super.isTrial,
    super.onTestUpdate,
    super.onTestComplete,
    super.onStepComplete,
  });

  @override
  Map<String, BaseDetectionService> createDetectionServices() {
    return {
      'objects':
          IsolateYOLOv5DetectionService(), // Use YOLOv5 for both chair and person detection
      'pose': MLKitPoseDetectionService(),
      'analysis': SPPBAnalysisService(),
    };
  }

  /// Convenience getters for specific detection types and services
  @override
  List<DetectionResult> get objectDetections => getDetections('objects');
  @override
  List<DetectionResult> get poseDetections => getDetections('pose');
  @override
  List<DetectionResult> get analysisDetections => getDetections('analysis');

  /// Convenience getters for typed detection services
  IsolateYOLOv5DetectionService get yoloService =>
      detectionServices['objects'] as IsolateYOLOv5DetectionService;
  MLKitPoseDetectionService get poseService =>
      detectionServices['pose'] as MLKitPoseDetectionService;
  SPPBAnalysisService get analysisService =>
      detectionServices['analysis'] as SPPBAnalysisService;

  @override
  Future<void> processCameraFrame(CameraImage cameraImage,
      {bool isFrontCamera = false}) async {
    // Route frames to the appropriate model/service based on the current phase
    try {
      print('SPPB: processCameraFrame called for phase $_currentPhase');

      switch (_currentPhase) {
        case SPPBTestPhase.setup:
        case SPPBTestPhase.detectChair:
          // Use YOLOv5 for chair detection phases
          final objectResults = await _runObjectDetectionOnFrame(cameraImage,
              isFrontCamera: isFrontCamera);
          // Update the service detections
          yoloService.updateDetections(objectResults);
          break;
        case SPPBTestPhase.detectPerson:
          // Use YOLOv5 for person detection phase
          final personResults = await _runObjectDetectionOnFrame(cameraImage,
              isFrontCamera: isFrontCamera);
          // Update the service detections
          yoloService.updateDetections(personResults);
          break;
        case SPPBTestPhase.chairStandTest:
          // Use pose detector for stand test phase
          final poseResults = await _runPoseDetectionOnFrame(cameraImage,
              isFrontCamera: isFrontCamera);
          // Update the service detections
          poseService.updateDetections(poseResults);
          break;
        case SPPBTestPhase.results:
          // Do not process frames in results phase; keep last detections
          break;
      }
    } catch (e) {
      print('SPPB: Error routing camera frame: $e');
    }
  }

  // Override getDetections to get fresh data from services
  @override
  List<DetectionResult> getDetections(String serviceType) {
    final service = detectionServices[serviceType];
    if (service != null && service.isInitialized) {
      // Get fresh detections directly from the service instead of cache
      return service.lastDetections;
    }
    return [];
  }

  // Helper: run pose detection and return results
  Future<List<DetectionResult>> _runPoseDetectionOnFrame(
      CameraImage cameraImage,
      {bool isFrontCamera = false}) async {
    try {
      print('SPPB: running pose detection');
      final bytes = CameraImageUtils.convertCameraImageToBytes(cameraImage,
          isFrontCamera: isFrontCamera);
      if (bytes.isEmpty) return [];

      final res = await poseService.processFrame(
          bytes, cameraImage.height, cameraImage.width);
      print('SPPB: pose detection -> ${res.length} results');
      return res;
    } catch (e) {
      print('SPPB: pose detection error: $e');
      return [];
    }
  }

  // Helper: run YOLOv5 object detection and return results
  Future<List<DetectionResult>> _runObjectDetectionOnFrame(
      CameraImage cameraImage,
      {bool isFrontCamera = false}) async {
    try {
      print('SPPB: running YOLOv5 object detection');
      final bytes = CameraImageUtils.convertCameraImageToBytes(cameraImage,
          isFrontCamera: isFrontCamera);
      if (bytes.isEmpty) return [];

      final res = await yoloService.processFrame(
          bytes, cameraImage.height, cameraImage.width);
      print('SPPB: YOLOv5 detection -> ${res.length} results');
      return res;
    } catch (e) {
      print('SPPB: YOLOv5 detection error: $e');
      return [];
    }
  }

  /// Clear all detection caches - useful when starting a new step
  void clearDetectionCache() {
    print('SPPB: Clearing detection cache');
    yoloService.updateDetections([]);
    poseService.updateDetections([]);
    analysisService.updateDetections([]);
    analysisService.resetMetrics(); // Also reset analysis metrics
  }

  @override
  Future<void> initialize() async {
    // Initialize the base detection service (chair service as primary)
    await super.initialize();

    // Additional services are initialized automatically by BaseTestController
    print('SPPB Controller: All services initialized');
  }

  @override
  List<TestStep> createTestSteps() {
    return [
      TestStep(
        label: 'Setup Validation',
        instruction: "Point your camera at any item to test object detection.",
        targetLabel: 'setup',
        targetTime: 3.0,
        maxTime: 10.0,
        confidenceThreshold: 0.8,
      ),
      TestStep(
        label: 'Chair Detection',
        instruction: "Point your camera at a chair to test chair detection.",
        targetLabel: 'chair',
        targetTime: 2.0,
        maxTime: 10.0,
        confidenceThreshold: 0.7,
      ),
      TestStep(
        label: 'Person Detection',
        instruction: "Point your camera at yourself to test pose detection.",
        targetLabel: 'person',
        targetTime: 2.0,
        maxTime: 15.0,
        confidenceThreshold: 0.5,
      ),
      TestStep(
        label: 'Chair Stand Test',
        instruction:
            "Slowly sit and stand in front of the camera, ensuring as much of your body is as visibile as possible.",
        targetLabel: 'chair_stand',
        targetTime: maxTestTime * 0.5,
        maxTime: maxTestTime,
        confidenceThreshold: 0.6,
      ),
      TestStep(
        label: 'Results Analysis',
        instruction: "Please wait as the results are analyzed.",
        targetLabel: 'results',
        targetTime: 2.0,
        maxTime: 5.0,
        confidenceThreshold: 1.0,
      ),
    ];
  }

  @override
  bool processDetectionResults(
      Map<String, List<DetectionResult>> detections, TestStep currentStep) {
    // Log the detection process for debugging
    print(
        'SPPB Processing ${detections.length} detections for step: ${currentStep.label}');
    print('Current phase: $_currentPhase');

    switch (_currentPhase) {
      case SPPBTestPhase.setup:
        return _validateSetupPhase(objectDetections, currentStep);
      case SPPBTestPhase.detectChair:
        return _validateChairDetection(objectDetections);
      case SPPBTestPhase.detectPerson:
        return _validatePersonDetection(objectDetections);
      case SPPBTestPhase.chairStandTest:
        return _validateChairStandDetection(poseDetections);
      case SPPBTestPhase.results:
        return _validateResultsPhase(analysisDetections, currentStep);
    }
  }

  /// Validate setup phase - should detect environment is ready
  bool _validateSetupPhase(
      List<DetectionResult> detections, TestStep currentStep) {
    // For setup, we just need some valid detections to show camera is working
    // But we should be more strict than just returning true
    print('  Setup phase: Found ${detections.length} detections');
    return detections.isNotEmpty; // At least some detections needed
  }

  bool _validateChairDetection(List<DetectionResult> detections) {
    print(
        '  Chair detection: Looking for chairs in ${detections.length} detections');
    final result = validateChairSetup(detections);
    print('  Chair detection result: $result');
    return result;
  }

  bool _validatePersonDetection(List<DetectionResult> detections) {
    print(
        '  Person detection: Looking for person pose in ${detections.length} detections');
    final result = validatePersonPosition(detections);
    print('  Person detection result: $result');
    return result;
  }

  bool _validateChairStandDetection(List<DetectionResult> detections) {
    print('  Chair stand test: Processing ${detections.length} detections');
    yoloService.updateDetections([]);
    final landmarks = poseService.extractLandmarks(detections);

    if (landmarks.isNotEmpty) {
      print('  Found ${landmarks.length} landmarks, analyzing movement...');
      analysisService.analyzeMovement(
        landmarks: landmarks,
        timestamp: DateTime.now(),
      );

      _currentMetrics = analysisService.getTestMetrics();
      print(
          '  Completed repetitions: ${_currentMetrics?.completedRepetitions ?? 0}');

      // Quick: check analysis detections for a repetition message
      // Accept common variants: 'repetition detected', 'repetition_detected'
      final latestAnalysisDetections = analysisDetections;
      final repetitionMsg = latestAnalysisDetections.firstWhere(
          (d) =>
              d.label.toLowerCase().contains('repetition') &&
              d.label.toLowerCase().contains('detect'),
          orElse: () => DetectionResult(
              label: '',
              confidence: 0.0,
              box: const DetectionBox(x: 0, y: 0, width: 0, height: 0)));

      if (repetitionMsg.label.isNotEmpty) {
        final now = DateTime.now();
        // Debounce: avoid reacting more than once within 700 ms
        if (_lastRepReactionTime == null ||
            now.difference(_lastRepReactionTime!).inMilliseconds > 500) {
          _lastRepReactionTime = now;
          _lastSeenRepCount =
              _currentMetrics?.completedRepetitions ?? _lastSeenRepCount + 1;
          // Trigger the step-complete visual/audio reaction
          onStepComplete?.call(true);
        }
      }
      // Check for test completion or timeout
      if (_currentMetrics != null && _testStartTime != null) {
        if (_currentMetrics!.completedRepetitions >= targetRepetitions) {
          currentStep?.detectedFrameCount = currentStep!.targetFrameCount;
        }
      }

      return true;
    }

    print('  No landmarks detected');
    return false;
  }

  /// Validate results phase - should have valid test results
  bool _validateResultsPhase(
      List<DetectionResult> detections, TestStep currentStep) {
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

  /// Get final test results
  SPPBTestResults getTestResults() {
    if (_currentMetrics == null) {
      return SPPBTestResults.failed();
    }

    final score = _currentMetrics!.calculateSPPBScore();
    final isSuccessful =
        _currentMetrics!.completedRepetitions >= targetRepetitions;

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

    // Clear detection cache and reset analysis service
    clearDetectionCache();
    analysisService.resetMetrics();

    print('SPPB Test initialized');
  }

  @override
  Future<void> onStepStart(TestStep step) async {
    await super.onStepStart(step);

    // Clear previous detection cache when starting a new step
    clearDetectionCache();

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

  /// Validate chair positioning for test setup
  /// Replaces the functionality previously in IsolateChairDetectionService
  bool validateChairSetup(List<DetectionResult> detections) {
    final chairs =
        detections.where((d) => d.label.toLowerCase() == 'chair').toList();

    if (chairs.isEmpty) {
      print('Chair validation failed: No chairs detected');
      return false;
    }

    // Debug: list all candidate chairs found
    print('Chair validation: found ${chairs.length} candidate(s)');
    for (var i = 0; i < chairs.length; i++) {
      final c = chairs[i];
      print(
          '  candidate[$i]: confidence=${c.confidence.toStringAsFixed(3)}, box=${c.box}');
    }

    // Check chair is in center area and properly sized
    final chair = chairs.first;
    final centerX = chair.box.x + chair.box.width / 2;
    final centerY = chair.box.y + chair.box.height / 2;

    // Individual checks for easier debugging
    final bool inHorizontal = centerX > 0.3 && centerX < 0.7;
    final bool inVertical = centerY > 0.4 && centerY < 0.8;
    final bool hasConfidence = chair.confidence > 0.7;

    final isValidPosition = inHorizontal && inVertical && hasConfidence;
    return isValidPosition;
  }

  /// Validate person positioning for person detection phase
  /// Filters YOLOv5 results for person detection with position validation
  bool validatePersonPosition(List<DetectionResult> detections) {
    final persons =
        detections.where((d) => d.label.toLowerCase() == 'person').toList();

    if (persons.isEmpty) {
      print('Person validation failed: No persons detected');
      return false;
    }

    // Debug: list all candidate persons found
    print('Person validation: found ${persons.length} candidate(s)');
    for (var i = 0; i < persons.length; i++) {
      final p = persons[i];
      print(
          '  candidate[$i]: confidence=${p.confidence.toStringAsFixed(3)}, box=${p.box}');
    }

    // Check person is reasonably positioned and has good confidence
    final person = persons.first;
    final centerX = person.box.x + person.box.width / 2;
    final centerY = person.box.y + person.box.height / 2;

    // Person should be reasonably centered and have good confidence
    final bool inHorizontal = centerX > 0.2 && centerX < 0.8;
    final bool inVertical = centerY > 0.2 && centerY < 0.9;
    final bool hasConfidence = person.confidence > 0.5;

    final isValidPosition = inHorizontal && inVertical && hasConfidence;
    return isValidPosition;
  }

  Future<void> stopTest() async {
    _currentPhase = SPPBTestPhase.results;
    onTestUpdate?.call();
  }

  @override
  void resetTest() {
    super.resetTest();

    // Clear detection cache when resetting test
    clearDetectionCache();

    // Reset SPPB specific state
    _currentPhase = SPPBTestPhase.setup;
    _setupValidationCount = 0;
    _testStartTime = null;
    _currentMetrics = null;

    print('SPPB Test reset');
  }
}

/// Balance Test Controller for SPPB balance component
class BalanceTestController extends BaseTestController {
  BalanceTestController({
    required super.isTrial,
    super.onTestUpdate,
    super.onTestComplete,
    super.onStepComplete,
  });

  @override
  Map<String, BaseDetectionService> createDetectionServices() {
    return {
      'pose': PoseDetectionService(),
    };
  }

  @override
  bool processDetectionResults(
      Map<String, List<DetectionResult>> detectionsByService,
      TestStep currentStep) {
    final poseDetections = detectionsByService['pose'] ?? [];

    // Balance test specific processing
    for (final detection in poseDetections) {
      if (detection.label.toLowerCase().contains('person') &&
          detection.confidence >= currentStep.confidenceThreshold) {
        return true;
      }
    }
    return false;
  }

  // Convenience getter for pose detections
  List<DetectionResult> get poseDetections => getDetections('pose');

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
}

/// Gait Speed Test Controller for SPPB gait component
class GaitTestController extends BaseTestController {
  GaitTestController({
    required super.isTrial,
    super.onTestUpdate,
    super.onTestComplete,
    super.onStepComplete,
  });

  @override
  Map<String, BaseDetectionService> createDetectionServices() {
    return {
      'pose': PoseDetectionService(),
    };
  }

  @override
  bool processDetectionResults(
      Map<String, List<DetectionResult>> detectionsByService,
      TestStep currentStep) {
    final poseDetections = detectionsByService['pose'] ?? [];

    // Gait test specific processing
    for (final detection in poseDetections) {
      if (detection.label.toLowerCase().contains('person') &&
          detection.confidence >= currentStep.confidenceThreshold) {
        return true;
      }
    }
    return false;
  }

  // Convenience getter for pose detections
  List<DetectionResult> get poseDetections => getDetections('pose');

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
