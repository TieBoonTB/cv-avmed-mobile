import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import '../services/base_detection_service.dart';
import '../types/detection_types.dart';
import '../utils/camera_image_utils.dart';

/// Abstract base class for all test controllers
/// Provides common test management functionality that can be extended
/// for different types of tests using different detection services
abstract class BaseTestController {
  final bool isTrial;
  final VoidCallback? onTestUpdate;
  final VoidCallback? onTestComplete;
  final Function(bool isSuccess)? onStepComplete;
  
  late BaseDetectionService _detectionService;
  
  // Test state
  bool _hasTestStarted = false;
  bool _isTestRunning = false;
  bool _isCompleted = false;
  int _currentStepIndex = 0;
  bool _isDisposed = false; // Add disposal flag

  BaseTestController({
    required this.isTrial,
    this.onTestUpdate,
    this.onTestComplete,
    this.onStepComplete,
  });

  // Abstract methods that must be implemented by subclasses
  
  /// Get the detection service specific to this test type
  BaseDetectionService createDetectionService();
  
  /// Get the list of test steps for this specific test
  List<TestStep> createTestSteps();
  
  /// Process detection results for the current step
  /// Returns true if the detection is valid for the current step
  bool processDetectionResult(List<DetectionResult> detections, TestStep currentStep);
  
  /// Optional: Custom logic when a step starts
  Future<void> onStepStart(TestStep step) async {}
  
  /// Optional: Custom logic when a step completes
  Future<void> onStepEnd(TestStep step, bool isSuccess) async {}

  // Common functionality provided by base class
  
  /// Initialize the test controller and its detection service
  Future<void> initialize() async {
    _detectionService = createDetectionService();
    await _detectionService.initialize();
  }
  
  /// Process a camera image through the detection service
  /// This method should be called whenever a new camera frame is available
  Future<void> processCameraFrame(CameraImage cameraImage) async {
    if (!_detectionService.isInitialized) return;
    
    try {
      // Convert camera image to bytes
      final imageBytes = CameraImageUtils.convertCameraImageToBytes(cameraImage);
      
      if (imageBytes.isNotEmpty) {
        // Process frame through the detection service
        await _detectionService.processFrame(
          imageBytes,
          cameraImage.height,
          cameraImage.width,
        );
      }
    } catch (e) {
      print('Error processing camera frame: $e');
    }
  }
  
  /// Get the current detection service
  BaseDetectionService get detectionService => _detectionService;
  
  /// Test state getters
  bool get hasTestStarted => _hasTestStarted;
  bool get isTestRunning => _isTestRunning;
  bool get isCompleted => _isCompleted;
  int get currentStepIndex => _currentStepIndex;
  
  /// Get all test steps
  List<TestStep> get testSteps => createTestSteps();
  
  /// Get current active step
  TestStep? get currentStep {
    final steps = testSteps;
    if (_currentStepIndex < steps.length) {
      return steps[_currentStepIndex];
    }
    return null;
  }

  /// Start the test sequence
  void startTest() {
    if (_hasTestStarted) return;
    
    _hasTestStarted = true;
    _isTestRunning = true;
    _currentStepIndex = 0;
    
    final steps = testSteps;
    if (steps.isNotEmpty) {
      steps[0].isActive = true;
    }
    
    _safeCallback(onTestUpdate);
    _runTestSequence();
  }

  /// Run the complete test sequence
  Future<void> _runTestSequence() async {
    final steps = testSteps;
    
    for (int i = 0; i < steps.length; i++) {
      if (!_isTestRunning) break;
      
      _currentStepIndex = i;
      final step = steps[i];
      
      // Reset previous step
      if (i > 0) {
        steps[i - 1].isActive = false;
      }
      
      // Activate current step
      step.isActive = true;
      _safeCallback(onTestUpdate);
      
      // Custom step start logic
      await onStepStart(step);
      
      // Run step with detection logic
      bool isSuccess = await _runStepWithDetection(step);
      
      if (_isTestRunning) {
        step.isActive = false;
        step.isDone = true;
        step.isSuccess = isSuccess;
        
        // Custom step end logic
        await onStepEnd(step, isSuccess);
        
        _safeCallback(onTestUpdate);
        _safeStepCallback(onStepComplete, isSuccess);
      }
    }
    
    if (_isTestRunning) {
      await endTest();
    }
  }

  /// Run a single step with detection logic
  Future<bool> _runStepWithDetection(TestStep step) async {
    step.detectedFrameCount = 0;
    
    // Start step timer
    final stepStartTime = DateTime.now();
    final maxDuration = Duration(milliseconds: (step.maxTime * 1000).round());
    
    // Detection loop
    while (_isTestRunning && DateTime.now().difference(stepStartTime) < maxDuration) {
      List<DetectionResult> detections;
      
      if (_detectionService.serviceType.contains('Mock')) {
        // For mock detection service, generate fresh detections each time
        try {
          // Create dummy frame data for mock processing
          final dummyFrameData = Uint8List(100); // Mock frame data
          detections = await _detectionService.processFrame(dummyFrameData, 480, 640);
        } catch (e) {
          print('Error processing mock frame: $e');
          detections = [];
        }
      } else {
        // For real detection services, use cached results from camera frame processing
        // This ensures we don't interfere with the camera frame processing pipeline
        detections = await _detectionService.getCurrentDetections();
        
        // If cache is empty and this is a real detection service, 
        // it might indicate camera frame processing isn't working
        if (detections.isEmpty) {
          print('Warning: No detections in cache for ${_detectionService.serviceType}');
        }
      }
      
      // Process detections using subclass-specific logic
      if (processDetectionResult(detections, step)) {
        step.detectedFrameCount++;
        _safeCallback(onTestUpdate);
        
        // Check if target is reached
        if (step.isTargetReached) {
          return true;
        }
      }
      
      // Wait before next detection check
      await Future.delayed(const Duration(milliseconds: 100)); // Detection Loop Checking: 100ms
    }
    
    return false; // Timeout or failed to meet target
  }

  /// End the test
  Future<void> endTest() async {
    _isTestRunning = false;
    _isCompleted = true;
    
    _safeCallback(onTestUpdate);
    _safeCallback(onTestComplete);
  }

  /// Reset the test to initial state
  void resetTest() {
    _hasTestStarted = false;
    _isTestRunning = false;
    _isCompleted = false;
    _currentStepIndex = 0;
    
    for (var step in testSteps) {
      step.isActive = false;
      step.isDone = false;
      step.isSuccess = false;
      step.detectedFrameCount = 0;
    }
    
    _safeCallback(onTestUpdate);
  }

  /// Force stop the test
  void forceStopTest() {
    _isTestRunning = false;
    _safeCallback(onTestUpdate);
  }

  /// Dispose resources
  void dispose() {
    _isDisposed = true;
    _detectionService.dispose();
  }
  
  /// Safe callback invocation that checks disposal state
  void _safeCallback(VoidCallback? callback) {
    if (!_isDisposed && callback != null) {
      callback();
    }
  }
  
  /// Safe step complete callback invocation
  void _safeStepCallback(Function(bool)? callback, bool isSuccess) {
    if (!_isDisposed && callback != null) {
      callback(isSuccess);
    }
  }
}

/// Test step data structure
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
    // Calculate target frame count based on actual detection rate (10 FPS = 100ms intervals)
    targetFrameCount = (targetTime * 10).round();
  }
  
  double get progress => targetFrameCount > 0 ? detectedFrameCount / targetFrameCount : 0.0;
  bool get isTargetReached => detectedFrameCount >= targetFrameCount;
}

/// Constants for step labels
class StepConstants {
  // AVMED Medication Adherence Labels
  static const String pill = 'pill';
  static const String pillOnTongue = 'pill on tongue';
  static const String noPillOnTongue = 'no pill on tongue';
  static const String drinkWater = 'drink water';
  static const String pleaseUseTransparentCup = 'please use transparent cup';
  static const String mouthCovered = 'mouth covered';
  static const String noPillUnderTongue = 'no pill under tongue';
  
  // AVMED Component Labels  
  static const String mouth = 'mouth';
  static const String hand = 'hand';
  static const String face = 'face';
  static const String tongue = 'tongue';
  static const String water = 'water';
  
  // YOLOv5 object detection labels
  static const String person = 'person';
  static const String bottle = 'bottle';
  static const String cup = 'cup';
  static const String apple = 'apple';
  static const String banana = 'banana';
  static const String book = 'book';
  static const String cellPhone = 'cell phone';
  static const String laptop = 'laptop';
}
