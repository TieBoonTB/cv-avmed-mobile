import '../config/model_config.dart';

/// Configuration for the detection service
class DetectionConfig {
  /// Default model type to use
  static const ModelType defaultModelType = ModelType.yolov5s;
  
  /// Fallback model type if default fails
  static const ModelType fallbackModelType = ModelType.mock;
  
  /// Enable automatic fallback to mock model
  static const bool enableFallback = true;
  
  /// Frame processing rate (frames per second)
  static const int processingFps = 15;
  
  /// Confidence threshold for detections
  static const double confidenceThreshold = 0.5;
  
  /// IoU threshold for Non-Maximum Suppression
  static const double iouThreshold = 0.4;
  
  /// Maximum number of detections to return per frame
  static const int maxDetections = 10;
  
  /// Target labels for pill compliance detection
  static const List<String> pillComplianceLabels = [
    'person',
    'bottle',
    'cup',
    'spoon',
  ];
  
  /// Custom labels mapping for pill detection
  /// Maps YOLOv5 class names to pill compliance steps
  static const Map<String, String> labelMapping = {
    'person': 'person',
    'bottle': 'pill container',
    'cup': 'water cup',
    'spoon': 'spoon',
    // Add more mappings as needed
  };
  
  /// Get mapped label name
  static String getMappedLabel(String originalLabel) {
    return labelMapping[originalLabel] ?? originalLabel;
  }
  
  /// Check if label is relevant for pill compliance
  static bool isRelevantLabel(String label) {
    return pillComplianceLabels.contains(label) || 
           labelMapping.containsKey(label);
  }
}

/// Model performance metrics
class ModelMetrics {
  final String modelName;
  final int totalFramesProcessed;
  final double averageProcessingTime;
  final double averageConfidence;
  final DateTime lastUpdated;

  ModelMetrics({
    required this.modelName,
    required this.totalFramesProcessed,
    required this.averageProcessingTime,
    required this.averageConfidence,
    required this.lastUpdated,
  });

  @override
  String toString() {
    return 'ModelMetrics(model: $modelName, frames: $totalFramesProcessed, '
           'avgTime: ${averageProcessingTime.toStringAsFixed(2)}ms, '
           'avgConf: ${averageConfidence.toStringAsFixed(3)})';
  }
}
