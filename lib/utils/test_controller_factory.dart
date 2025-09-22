import '../controllers/base_test_controller.dart';
import '../controllers/mock_test_controller.dart';
import '../controllers/object_detection_test_controller.dart';
import '../controllers/avmed_test_controller.dart';
import '../controllers/sppb_test_controllers.dart';
import 'package:flutter/material.dart';

/// Factory for creating test controllers
/// This makes it easy to add new test types without modifying the camera page
class TestControllerFactory {
  /// Available test types
  static const String mockTest = 'mock';
  static const String objectDetectionTest = 'objects';
  static const String avmedTest = 'avmed';
  static const String chairStandTest = 'chair-stand';
  static const String balanceTest = 'balance';
  static const String gaitTest = 'gait';

  /// Create a test controller based on type
  static BaseTestController createController({
    required String testType,
    required bool isTrial,
    VoidCallback? onTestUpdate,
    VoidCallback? onTestComplete,
    Function(bool isSuccess)? onStepComplete,
  }) {
    switch (testType.toLowerCase()) {
      case mockTest:
        return MockTestController(
          isTrial: isTrial,
          onTestUpdate: onTestUpdate,
          onTestComplete: onTestComplete,
          onStepComplete: onStepComplete,
        );

      case objectDetectionTest:
        return ObjectDetectionTestController(
          isTrial: isTrial,
          onTestUpdate: onTestUpdate,
          onTestComplete: onTestComplete,
          onStepComplete: onStepComplete,
        );

      case avmedTest:
        return AVMedTestController(
          isTrial: isTrial,
          onTestUpdate: onTestUpdate,
          onTestComplete: onTestComplete,
          onStepComplete: onStepComplete,
        );

      case chairStandTest:
        return ChairStandTestController(
          isTrial: isTrial,
          onTestUpdate: onTestUpdate,
          onTestComplete: onTestComplete,
          onStepComplete: onStepComplete,
        );

      case balanceTest:
        return BalanceTestController(
          isTrial: isTrial,
          onTestUpdate: onTestUpdate,
          onTestComplete: onTestComplete,
          onStepComplete: onStepComplete,
        );

      case gaitTest:
        return GaitTestController(
          isTrial: isTrial,
          onTestUpdate: onTestUpdate,
          onTestComplete: onTestComplete,
          onStepComplete: onStepComplete,
        );

      default:
        // Default to mock test for unknown types
        return MockTestController(
          isTrial: isTrial,
          onTestUpdate: onTestUpdate,
          onTestComplete: onTestComplete,
          onStepComplete: onStepComplete,
        );
    }
  }

  /// Get display name for test type
  static String getTestDisplayName(String testType) {
    switch (testType.toLowerCase()) {
      case mockTest:
        return 'Mock Detection Test';
      case objectDetectionTest:
        return 'Object Detection Test (YOLOv5)';
      case avmedTest:
        return 'AVMED Medication Adherence Test';
      case chairStandTest:
        return 'Chair Stand Test (SPPB)';
      case balanceTest:
        return 'Balance Test (SPPB)';
      case gaitTest:
        return 'Gait Speed Test (SPPB)';
      default:
        return 'Unknown Test';
    }
  }

  /// Get description for test type
  static String getTestDescription(String testType) {
    switch (testType.toLowerCase()) {
      case mockTest:
        return 'Test with simulated detection results for development and testing';
      case objectDetectionTest:
        return 'Real object detection using YOLOv5 model - show different objects';
      case avmedTest:
        return 'Medication adherence monitoring using dual model AI detection (pill, mouth, face detection)';
      case chairStandTest:
        return 'Chair stand assessment for lower body strength using YOLOv5 + MediaPipe pose detection';
      case balanceTest:
        return 'Balance assessment with side-by-side, semi-tandem, and tandem stands';
      case gaitTest:
        return 'Gait speed assessment using computer vision movement tracking';
      default:
        return 'Unknown test type';
    }
  }

  /// Get all available test types
  static List<String> getAvailableTestTypes() {
    // return [mockTest, objectDetectionTest, avmedTest, chairStandTest, balanceTest, gaitTest];
    return [objectDetectionTest, chairStandTest];
  }

  /// Check if a test type is valid
  static bool isValidTestType(String testType) {
    return getAvailableTestTypes().contains(testType.toLowerCase());
  }
}
