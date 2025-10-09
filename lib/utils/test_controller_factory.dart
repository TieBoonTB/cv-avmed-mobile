import 'package:flutter/material.dart';
import '../controllers/base_test_controller.dart';
import '../controllers/test_controller_object_detector.dart';
import '../controllers/test_controller_avmed.dart';
import '../controllers/test_controller_sppb_chair_stand.dart';
import '../controllers/test_controller_avmed_websocket.dart';

/// Enum of supported test types. Use this instead of raw strings to make the
/// API safer and less error-prone.
enum TestType { objectDetector, avmed, avmedWebSocket, sppbChairStand }

/// Factory for creating test controllers. Accepts a [TestType] enum value.
class TestControllerFactory {

  static BaseTestController createController({
    required TestType type,
    VoidCallback? onTestUpdate,
    VoidCallback? onTestComplete,
    Function(bool isSuccess)? onStepComplete,
    // WebSocket-specific parameters
    String? websocketServerUrl,
    String? patientCode,
    bool shouldRecord = false,
  }) {
    switch (type) {
      case TestType.objectDetector:
        return TestControllerObjectDetector(
          onTestUpdate: onTestUpdate,
          onTestComplete: onTestComplete,
          onStepComplete: onStepComplete,
        );
      case TestType.avmed:
        return TestControllerAVMed(
          onTestUpdate: onTestUpdate,
          onTestComplete: onTestComplete,
          onStepComplete: onStepComplete,
        );
      case TestType.sppbChairStand:
        return TestControllerSPPBChairStand(
          onTestUpdate: onTestUpdate,
          onTestComplete: onTestComplete,
          onStepComplete: onStepComplete,
        );
      case TestType.avmedWebSocket:
        return TestControllerAVMedWebSocket(
          onTestUpdate: onTestUpdate,
          onTestComplete: onTestComplete,
          onStepComplete: onStepComplete,
          serverUrl: websocketServerUrl,
          patientCode: patientCode,
          shouldRecord: shouldRecord,
        );
    }
  }

  /// Human-friendly display name
  static String getTestDisplayName(TestType type) {
    switch (type) {
      case TestType.objectDetector:
        return 'Object Detection Test (YOLOv5)';
      case TestType.avmed:
        return 'AVMED Medication Adherence Test';
      case TestType.sppbChairStand:
        return 'SPPB Chair Stand Test';
      case TestType.avmedWebSocket:
        return 'AVMED Test (WebSocket)';
    }
  }

  /// Short description for UI
  static String getTestDescription(TestType type) {
    switch (type) {
      case TestType.objectDetector:
        return 'Real object detection using YOLOv5 model - show different objects';
      case TestType.avmed:
        return 'Medication adherence test using AVMED model to detect pill and mouth/tongue actions';
      case TestType.sppbChairStand:
        return 'Chair stand functional test using pose and object detection';
      case TestType.avmedWebSocket:
        return 'Medication adherence test using remote WebSocket AVMED service';
    }
  }

  /// Get all available test types
  static List<TestType> getAvailableTestTypes() => TestType.values;

  /// Check if a test type is valid (always true for enum values)
  static bool isValidTestType(TestType type) => TestType.values.contains(type);
}
