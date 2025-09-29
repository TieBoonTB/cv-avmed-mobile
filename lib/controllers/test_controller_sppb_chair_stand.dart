import 'package:camera/src/camera_image.dart';
import 'package:flutter/foundation.dart';
import 'package:namer_app/types/detection_types.dart';
import 'package:namer_app/utils/camera_image_utils.dart';
import 'base_test_controller.dart';
import '../services/isolate_detection_classes.dart';
import '../services/mlkit_pose_detection_service.dart';
import '../services/sppb_detection_services.dart';
import '../services/base_detection_service.dart';

/// Simple object detection test controller using YOLOv5 (isolate)
/// The default step processing in the base class will look for the
/// step.targetLabel in the detections and increment detections.
class TestControllerSPPBChairStand extends BaseTestController {
  TestControllerSPPBChairStand({
    VoidCallback? onTestUpdate,
    VoidCallback? onTestComplete,
    Function(bool)? onStepComplete,
  }) : super(
          onTestUpdate: onTestUpdate,
          onTestComplete: onTestComplete,
          onStepComplete: onStepComplete,
        ) {
    // Set preferred frame processing interval (ms)
    frameProcessingIntervalMs = 500.0;
  }

  // For Chair Stand Analysis
  SPPBTestMetrics? _currentMetrics;
  // Test parameters
  static const int targetRepetitions = 3;
  static const double maxTestTime = 60.0; // seconds
  DateTime? lastRepDetectionTime;

  /// Convenience getters for typed detection services
  IsolateYOLOv5DetectionService get yoloService => detectionServices['objects'] as IsolateYOLOv5DetectionService;
  MLKitPoseDetectionService get poseService => detectionServices['pose'] as MLKitPoseDetectionService;
  SPPBAnalysisService get analysisService => detectionServices['analysis'] as SPPBAnalysisService;

  @override
  Map<String, BaseDetectionService> createDetectionServices() {
    return {
      'objects':
          IsolateYOLOv5DetectionService(), // Use YOLOv5 for both chair and person detection
      'pose': MLKitPoseDetectionService(),
      'analysis': SPPBAnalysisService(),
    };
  }

  @override
  List<TestStep> createTestSteps() {
    // Use the controller's preferred frame interval when creating steps
    final intervalMs = frameProcessingIntervalMs;

    return [
      TestStep(
        label: 'Setup Validation',
        instruction: "Point your camera at any item to test object detection.",
        targetLabel: '',
        frameProcessingIntervalMs: intervalMs
      ),
      TestStep(
        label: 'Chair Detection',
        instruction: "Point your camera at a chair to test chair detection.",
        targetLabel: 'chair',
        frameProcessingIntervalMs: intervalMs
      ),
      TestStep(
        label: 'Person Detection',
        instruction: "Point your camera at yourself to test pose detection.",
        targetLabel: 'person',
        frameProcessingIntervalMs: intervalMs
      ),
      TestStep(
        label: 'Chair Stand Test',
        instruction: "Slowly sit and stand in front of the camera, ensuring as much of your body is as visible as possible.",
        targetLabel: 'chair_stand',
        frameProcessingIntervalMs: intervalMs,
        maxTime: 120,
        detectionsRequired: targetRepetitions, 
      ),
      TestStep(
        label: 'Results Analysis',
        instruction: "Please wait as the results are analyzed.",
        targetLabel: 'results',
        frameProcessingIntervalMs: intervalMs,
        detectionsRequired: 5,
      ),
    ];
  }

  @override
  Future<void> processCurrentFrame(CameraImage cameraImage, {bool isFrontCamera = false}) async {
    String? label = currentStep?.label;
    if (label == null) {
      return;
    }

    clearDetections();
    
    // Choose which model to use based on current step
    if (label == "Setup Validation" || label == "Chair Detection") {
      List<DetectionResult> detections = await _runObjectDetection(cameraImage, isFrontCamera: isFrontCamera);
      lastDetections['objects'] = detections;
    }
    else if (label == "Person Detection" || label == "Chair Stand Test") {
      List<DetectionResult> detections = await _runPoseDetection(cameraImage, isFrontCamera: isFrontCamera);
      lastDetections["pose"] = detections;
    }
    else if (label == "Results Analysis") {

    }
    
    // After processing the frame, if a test is running let subclasses handle the step logic
    if (isTestRunning) {
      try {
        await processTestStep();
      } catch (e) {
        print('Error in processTestStep: $e');
      }
    }
  }

  // Use YoloV5 model for object detection
  Future<List<DetectionResult>> _runObjectDetection(
    CameraImage cameraImage, 
    {bool isFrontCamera = false}) async {
    try {
      final bytes = CameraImageUtils.convertCameraImageToBytes(
        cameraImage,
        isFrontCamera: isFrontCamera);

        if (bytes.isEmpty) return [];

        final response = await yoloService.processFrame(
          bytes, 
          cameraImage.height, 
          cameraImage.width);

        return response;
    }
    catch (e) {
      print("TestControllerSPPBChairStand: YoloV5 Detection Error: $e");
      return [];
    }
  }

  // User MLkit pose model
  Future<List<DetectionResult>> _runPoseDetection(
    CameraImage cameraImage,
    {bool isFrontCamera = false}) async {
      try {
        final bytes = CameraImageUtils.convertCameraImageToBytes(
          cameraImage,
          isFrontCamera: isFrontCamera);

        if (bytes.isEmpty) return [];

        List<DetectionResult> response = await poseService.processFrame(
          bytes, 
          cameraImage.height, 
          cameraImage.width);
        
        return response;
      }
      catch (e) {
        print("TestControllerSPPBChairStand - Pose Detection Error $e");
        return [];
      }
  }

  /// Subclasses should override this to implement step evaluation logic.
  @override
  Future<void> processTestStep() async {
    String? label = currentStep?.label;
    final step = currentStep;
    if (step == null) return;
    if (label == null) return;

    bool found = false;
    if (label == "Setup Validation") {
      List<DetectionResult>detections = lastDetections["objects"] ?? [];
      found = detections.isNotEmpty;
    }
    else if (label == "Chair Detection") {
      List<DetectionResult> detections = lastDetections["objects"] ?? [];
      found = _validateChairDetection(detections);
    }
    else if (label == "Person Detection") {
      List<DetectionResult> detections = lastDetections["pose"] ?? [];
      found = _validatePersonDetection(detections);
    }
    else if (label == "Chair Stand Test") {
      List<DetectionResult> detections = lastDetections["pose"] ?? [];
      found = _validateChairStandDetection(detections, step);
    }
    else if (label == "Results Analysis") {
      // analysis doesn't actually do anything so we just send true
      found = true;
    }
    
    processStepDetectionResult(step, found);
  }

  bool _validateChairDetection(List<DetectionResult> detections) {
    final chairs = detections.where((d) => d.label.toLowerCase() == 'chair').toList();
    return true;

    if (chairs.isEmpty) {
      return false;
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

  bool _validatePersonDetection(List<DetectionResult> detections) {
    final landmarks = poseService.extractLandmarks(detections);
    // Ensure Key Landmarks are detected for chair stand test
    final requiredLandmarks = [
      'left_hip',
      'right_hip',
      'left_knee',
      'right_knee',
      "left_shoulder",
      "right_shoulder"
    ];

    // Find which required landmarks are not present
    final missingLandmarks = <String>[];
    for (final landmark in requiredLandmarks) {
      if (!landmarks.containsKey(landmark)) {
        missingLandmarks.add(landmark);
      }
    }
    
    return missingLandmarks.isEmpty;
  }

  bool _validateChairStandDetection(List<DetectionResult> detections, TestStep step) {
    final landmarks = poseService.extractLandmarks(detections);

    if (landmarks.isNotEmpty) {
      final analysisResult = analysisService.analyzeMovement(landmarks: landmarks, timestamp: DateTime.now());

      _currentMetrics = analysisService.getTestMetrics();

      // React to explicit repititon flag returned by the analysis service
      if (analysisResult.repDetected) {
        final now = DateTime.now();
        // Debounce
        if (lastRepDetectionTime == null ||
            now.difference(lastRepDetectionTime!).inMilliseconds > 500) {
          lastRepDetectionTime = now;
          pushDisplayMessage("You have completed ${_currentMetrics?.completedRepetitions}/${targetRepetitions} repetitions.");
          return true;
        }
      }
    }
    return false;
  }
}