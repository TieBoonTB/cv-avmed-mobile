import 'dart:typed_data';
import 'base_model.dart';
import '../types/detection_types.dart';
import '../config/model_config.dart';

/// Mock model for testing and fallback
class MockModel extends BaseModel {
  bool _isInitialized = false;

  @override
  ModelInfo get modelInfo => ModelConfigurations.mock;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _isInitialized = true;
  }

  @override
  Future<List<DetectionResult>> processFrame(Uint8List frameData, int imageHeight, int imageWidth) async {
    if (!_isInitialized) {
      throw Exception('Model not initialized');
    }
    
    await Future.delayed(const Duration(milliseconds: 50));
    
    // Return mock detection results
    return [
      DetectionResult(
        label: 'pill',
        confidence: 0.85,
        box: DetectionBox(x: 0.3, y: 0.4, width: 0.1, height: 0.1),
      ),
      DetectionResult(
        label: 'person',
        confidence: 0.95,
        box: DetectionBox(x: 0.2, y: 0.1, width: 0.6, height: 0.8),
      ),
    ];
  }

  @override
  void dispose() {
    _isInitialized = false;
  }
}
