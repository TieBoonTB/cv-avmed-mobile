import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../services/base_detection_service.dart';
import '../types/detection_types.dart';
import '../utils/camera_image_utils.dart';

abstract class BaseTestController {
  Map<String, BaseDetectionService> _detectionServices = {};
  Map<String, List<DetectionResult>> _lastDetections = {};
  
  bool _isProcessing = false;
  bool _isDisposed = false;

  // Test steps and running state
  List<TestStep>? _testSteps;
  bool _isTestRunning = false;
  bool _isTestComplete = false;
  int _currentStepIndex = 0;
  // Preferred interval (milliseconds) that callers should use when scheduling
  double _frameProcessingIntervalMs = 500.0;
  
  // Callbacks for ui functions
  final VoidCallback? onTestUpdate;
  final VoidCallback? onTestComplete;
  final Function(bool isSuccess)? onStepComplete;

  /// Optional transient message intended for UI display. Subclasses or
  /// test logic may call [pushDisplayMessage] to set this and notify the UI
  String? displayMessage;

  // api
  Set<String> get availableServiceKeys => _detectionServices.keys.toSet();
  Map<String, BaseDetectionService> get detectionServices => _detectionServices;
  Map<String, List<DetectionResult>> get lastDetections => _lastDetections;
  bool get isDisposed => _isDisposed;
  bool get isProcessing => _isProcessing;
  bool get isTestRunning => _isTestRunning;
  bool get isTestComplete => _isTestComplete;
  int get currentStepIndex => _currentStepIndex;
  /// Preferred frame processing interval in milliseconds. External code
  /// (for example a Timer) should use this value when scheduling calls to
  /// `processCurrentFrame`.
  double get frameProcessingIntervalMs => _frameProcessingIntervalMs;
  set frameProcessingIntervalMs(double ms) {
    if (ms <= 0) return;
    _frameProcessingIntervalMs = ms;
  }


  /// Abstract method that must be implemented by subclasses
  /// Returns a map of service names to detection services
  /// Example: {'pose': MLKitPoseService(), 'objects': YoloService()}
  Map<String, BaseDetectionService> createDetectionServices();

  /// Abstract method to create the list of TestSteps for this test
  List<TestStep> createTestSteps();

  BaseTestController({
    this.onTestUpdate,
    this.onTestComplete,
    this.onStepComplete,
  });

  /// Initialize the test controller and its detection services
  Future<void> initialize() async {
    if (_isDisposed) return;
    
    // Get detection services from subclass
    _detectionServices = createDetectionServices();

    // Initialize all detection services
    for (final entry in _detectionServices.entries) {
      final serviceKey = entry.key;
      final service = entry.value;
      
      await service.initialize();
      
      // Initialize empty detection results for this service
      _lastDetections[serviceKey] = [];
    }
  }

  /// Process a camera frame through all detection services
  /// Updates _lastDetections with results from each service
  Future<void> processCurrentFrame(CameraImage cameraImage, {bool isFrontCamera = false}) async {
    if (_isDisposed) return;

    // If a processing job is already running, skip this frame to avoid backlog
    if (_isProcessing) return;

    _isProcessing = true;
    // Check if any services are initialized
    if (_detectionServices.values.every((service) => !service.isInitialized)) {
      _isProcessing = false;
      return;
    }

    try {
      // Convert camera image to bytes
      final imageBytes = CameraImageUtils.convertCameraImageToBytes(
        cameraImage,
        isFrontCamera: isFrontCamera,
      );

      if (imageBytes.isNotEmpty) {
        // Process frame through all detection services
        for (final entry in _detectionServices.entries) {
          final serviceKey = entry.key;
          final service = entry.value;

          if (service.isInitialized) {
            // Process the frame
            await service.processFrame(
              imageBytes,
              cameraImage.height,
              cameraImage.width,
            );

            // Update cached detections for this service
            _lastDetections[serviceKey] = await service.getCurrentDetections();
          }
        }
      }
    } catch (e) {
      print('Error processing camera frame: $e');
    } finally {
      _isProcessing = false;
    }

    // After processing the frame, if a test is running let subclasses handle the step logic
    if (_isTestRunning) {
      try {
        await processTestStep();
      } catch (e) {
        print('Error in processTestStep: $e');
      }
    }
  }

  /// Subclasses should override this to implement step evaluation logic.
  Future<void> processTestStep() async {
    // Default implementation: check across all detection services whether the
    // current step's targetLabel is present with sufficient confidence.
    final step = currentStep;
    if (step == null) return;

    // Only process active steps
    if (!step.isActive) return;

    final target = step.targetLabel;
    if (target == null || target.isEmpty) {
      // Nothing to check for this step
      return;
    }

    final detections = getAllDetections();

    bool found = false;
    for (final entry in detections.entries) {
      for (final d in entry.value) {
        if (d.label == target && d.confidence >= step.confidenceThreshold) {
          found = true;
          break;
        }
      }
      if (found) break;
    }

    // Delegate handling of the detection outcome to a protected helper.
    processStepDetectionResult(step, found);
  }

  /// Handle the outcome of detection for a step. Called with 
  /// [found]==true when a successful detection was observed. 
  /// This updates detection counters, notifies callbacks and advances/completes steps when their
  /// criteria are met. 
  @protected
  void processStepDetectionResult(TestStep step, bool found) {
    if (found) {
      step.incrementDetections();
      safeCallback(onTestUpdate);
    }

    // Advance or complete step based on results
    if (step.isTargetReached) {
      step.complete(success: true);
      safeStepCallback(onStepComplete, true);
      safeCallback(onTestUpdate);
      _advanceToNextStep();
    } else if (step.isTimedOut) {
      step.complete(success: false);
      safeStepCallback(onStepComplete, false);
      safeCallback(onTestUpdate);
      _advanceToNextStep();
    }
  }

  /// Get detections from a specific service
  List<DetectionResult> getDetections(String serviceKey) {
    return _lastDetections[serviceKey] ?? [];
  }

  /// Get all detection results from all services
  Map<String, List<DetectionResult>> getAllDetections() {
    return Map.unmodifiable(_lastDetections);
  }

  /// Clear all cached detection results. This will reset the internal `_lastDetections` map
  void clearDetections() {
    if (_isDisposed) return;
    _lastDetections.clear();
    for (final key in _detectionServices.keys) {
      _lastDetections[key] = [];
    }
    safeCallback(onTestUpdate);
  }

  /// Test steps managed by this controller (created on first access)
  List<TestStep> get testSteps {
    _testSteps ??= createTestSteps();
    return _testSteps!;
  }

  /// Current active TestStep or null if index out of range
  TestStep? get currentStep {
    final steps = testSteps;
    if (_currentStepIndex >= 0 && _currentStepIndex < steps.length) {
      return steps[_currentStepIndex];
    }
    return null;
  }

  /// Start the test sequence. Marks the first step active.
  void startTest() {
    if (_isTestRunning) return;
    _testSteps ??= createTestSteps();
    _isTestRunning = true;
    _isTestComplete = false;
    _currentStepIndex = 0;
    if (_testSteps!.isNotEmpty) {
      _testSteps![0].start();
    }
    safeCallback(onTestUpdate);
  }

  /// Returns time remaining for the current step as a percentage (0-100).
  /// Returns -1.0 if the current step is not timed or not started.
  double getCurrentStepTimeRemainingPercent() {
    final step = currentStep;
    if (step == null) return -1.0;
    return step.timeRemainingPercent();
  }

  /// Stop the test sequence
  void stopTest() {
    _isTestRunning = false;
    final cs = currentStep;
    if (cs != null) {
      cs.isActive = false;
    }
    _currentStepIndex = 0;
    safeCallback(onTestUpdate);
  }

  /// Advance to the next step in the sequence. If there are no more steps,
  /// the test will be stopped.
  void _advanceToNextStep() {
    final steps = testSteps;
    // Mark current as inactive (should already be set by caller)
    if (_currentStepIndex < steps.length) {
      steps[_currentStepIndex].isActive = false;
    }

    _currentStepIndex++;
    if (_currentStepIndex >= steps.length) {
      // No more steps; stop the test
      _isTestRunning = false;
      _isTestComplete = true;
      safeCallback(onTestComplete);
      return;
    }

    // Start the next step
    steps[_currentStepIndex].start();
  }

  /// Safe callback invocation that checks disposal state. 
  @protected
  void safeCallback(VoidCallback? callback) {
    if (!_isDisposed && callback != null) {
      callback();
    }
  }

  /// Safe step complete callback invocation.
  @protected
  void safeStepCallback(Function(bool)? callback, bool isSuccess) {
    if (!_isDisposed && callback != null) {
      callback(isSuccess);
    }
  }

  /// Set a transient display message and notify UI via [onTestUpdate].
  /// The message remains in [displayMessage] until cleared.
  void pushDisplayMessage(String message) {
    if (_isDisposed) return;
    displayMessage = message;
    safeCallback(onTestUpdate);
  }

  /// Clear any transient display message and notify UI.
  void popDisplayMessage() {
    if (_isDisposed) return;
    displayMessage = null;
    safeCallback(onTestUpdate);
  }

  /// Dispose resources and cleanup
  void dispose() {
    _isDisposed = true;
    _isProcessing = false;

    // Dispose all detection services
    for (final service in _detectionServices.values) {
      service.dispose();
    }

    // Clear all data structures
    _detectionServices.clear();
    _lastDetections.clear();
  }
}

/// Data class representing a single test step
class TestStep {
  /// Name/identifier of this test step
  final String label;
  /// Target label the step is looking for in detections
  final String? targetLabel;
  /// Text instruction shown to the user for this step
  final String? instruction;
  /// Path to instructional video for this step
  final String? videoPath;
  /// Path to subtitle file for the instructional video
  final String? subtitlePath;
  /// Maximum time allowed for this step in seconds
  /// -1 means the step is not timed
  final double maxTime;
  /// Time when this step was started (set when step becomes active)
  DateTime? startTime;
  /// Confidence threshold required to consider a detection successful
  /// Defaults to 0 (any detection counts)
  final double confidenceThreshold;

  /// Whether this step is currently active/running
  bool isActive = false;
  /// Whether this step has been completed successfully
  bool isSuccess = false;
  
  /// Number of successful detections recorded for this step
  int detectionsCount = 0;
  /// Number of detections required to complete this step
  late int detectionsRequired;

  TestStep({
    required this.label,
    required this.targetLabel,
    this.instruction,
    this.videoPath,
    this.subtitlePath,
    this.maxTime = -1,
    this.confidenceThreshold = 0.0,
    this.detectionsRequired = 0,
    double targetTimeSeconds = 0,
    required double frameProcessingIntervalMs,
  }) {
    // Compute default detectionsRequired if not set by caller.
    if (detectionsRequired == 0) {
      detectionsRequired = targetTimeSeconds > 0
          ? (targetTimeSeconds * 1000 / frameProcessingIntervalMs).round()
          : 1; // If no target time specified, require at least 1 detection
    }
  }

  /// Get the current progress as a percentage (0.0 to 1.0)
  double get progress => detectionsRequired > 0 
      ? (detectionsCount / detectionsRequired).clamp(0.0, 1.0)
      : (detectionsCount > 0 ? 1.0 : 0.0);

  bool get isTargetReached => detectionsCount >= detectionsRequired;

  /// Check if this step has timed out (if it's timed)
  bool get isTimedOut {
    if (maxTime <= 0 || startTime == null) return false;
    return DateTime.now().difference(startTime!).inMilliseconds > (maxTime * 1000);
  }

  /// Get elapsed time since step started in seconds
  double get elapsedTime {
    if (startTime == null) return 0.0;
    return DateTime.now().difference(startTime!).inMilliseconds / 1000.0;
  }

  /// Return remaining time for this step as a percentage (0.0 - 100.0).
  /// If the step is not timed (maxTime <= 0) or hasn't started, returns -1.0.
  double timeRemainingPercent() {
    if (maxTime <= 0 || startTime == null) return -1.0;
    final remaining = maxTime - elapsedTime;
    if (remaining <= 0) return 0.0;
    return (remaining / maxTime) * 100.0;
  }

  /// Start this step (sets startTime)
  void start() {
    startTime = DateTime.now();
    isActive = true;
  }

  /// Complete this step with success/failure
  void complete({required bool success}) {
    isActive = false;
    isSuccess = success;
  }

  /// Reset this step to initial state
  void reset() {
    isActive = false;
    isSuccess = false;
    detectionsCount = 0;
    startTime = null;
  }

  /// Increment detection count
  void incrementDetections() {
    detectionsCount++;
  }
}