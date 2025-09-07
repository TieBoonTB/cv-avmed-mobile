import '../controllers/base_test_controller.dart';
import '../controllers/mock_test_controller.dart';
import '../controllers/object_detection_test_controller.dart';
import 'package:flutter/material.dart';

/// Factory for creating test controllers
/// This makes it easy to add new test types without modifying the camera page
class TestControllerFactory {
  /// Available test types
  static const String mockTest = 'mock';
  static const String objectDetectionTest = 'objects';
  
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
      default:
        return 'Unknown test type';
    }
  }
  
  /// Get all available test types
  static List<String> getAvailableTestTypes() {
    return [mockTest, objectDetectionTest];
  }
  
  /// Check if a test type is valid
  static bool isValidTestType(String testType) {
    return getAvailableTestTypes().contains(testType.toLowerCase());
  }
}
