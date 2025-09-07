import 'dart:typed_data';
import '../types/detection_types.dart';
import '../config/model_config.dart';

/// Abstract base class for all ML models
abstract class BaseModel {
  /// Initialize the model
  Future<void> initialize();
  
  /// Process a frame and return detection results
  Future<List<DetectionResult>> processFrame(Uint8List frameData, int imageHeight, int imageWidth);
  
  /// Dispose resources
  void dispose();
  
  /// Get model info
  ModelInfo get modelInfo;
  
  /// Check if model is initialized
  bool get isInitialized;
}
