import 'dart:async';
import 'dart:typed_data';
import '../types/detection_types.dart';
import '../models/base_model.dart';

/// Abstract base class for all detection services
/// Different detection services can implement different logic for
/// processing camera frames and managing detection streams
abstract class BaseDetectionService {
  final StreamController<List<DetectionResult>> _detectionController =
      StreamController<List<DetectionResult>>.broadcast();

  bool _isInitialized = false;
  List<DetectionResult> _lastDetections = [];

  /// Stream of detection results
  Stream<List<DetectionResult>> get detectionStream =>
      _detectionController.stream;
  bool get isInitialized => _isInitialized;
  List<DetectionResult> get lastDetections => _lastDetections;

  /// Abstract methods to be implemented by subclasses
  Future<void> initialize();
  Future<List<DetectionResult>> processFrame(Uint8List frameData, int imageHeight, int imageWidth);

  BaseModel? get currentModel;
  String get serviceType;

  // Common functionality provided by base class

  /// Get current detections (returns cached results if available)
  Future<List<DetectionResult>> getCurrentDetections() async {
    return _lastDetections;
  }

  /// Update detection results and notify listeners
  void updateDetections(List<DetectionResult> detections) {
    _lastDetections = detections;
    _detectionController.add(detections);
  }

  /// Set initialized state
  void setInitialized(bool initialized) {
    _isInitialized = initialized;
  }

  /// Dispose resources
  void dispose() {
    _detectionController.close();
    _isInitialized = false;
  }
}
