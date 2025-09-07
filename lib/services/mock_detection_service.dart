import 'dart:typed_data';
import '../services/base_detection_service.dart';
import '../types/detection_types.dart';
import '../models/base_model.dart';
import '../models/mock_model.dart';

/// Mock detection service for testing and development
/// Always returns predefined mock results to simulate detection behavior
class MockDetectionService extends BaseDetectionService {
  MockModel? _mockModel;
  
  @override
  String get serviceType => 'Mock Detection Service';
  
  @override
  BaseModel? get currentModel => _mockModel;

  @override
  Future<void> initialize() async {
    try {
      _mockModel = MockModel();
      await _mockModel!.initialize();
      setInitialized(true);
      print('Mock detection service initialized');
    } catch (e) {
      print('Error initializing mock detection service: $e');
      rethrow;
    }
  }

  @override
  Future<List<DetectionResult>> processFrame(
    Uint8List frameData, 
    int imageHeight, 
    int imageWidth
  ) async {
    if (!isInitialized || _mockModel == null) {
      throw Exception('Mock detection service not initialized');
    }

    try {
      // Get mock results from the model
      final results = await _mockModel!.processFrame(frameData, imageHeight, imageWidth);
      
      // Update the cached results
      updateDetections(results);
      
      return results;
    } catch (e) {
      print('Error processing frame in mock detection service: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _mockModel?.dispose();
    super.dispose();
  }
}
