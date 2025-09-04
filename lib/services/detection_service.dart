import 'dart:async';
import 'dart:typed_data';
import '../types/detection_types.dart';
import '../config/model_config.dart';
import '../models/base_model.dart';

/// High-level detection service that manages ML models
class DetectionService {
  static const int framesPerSecond = 30;
  
  final StreamController<List<DetectionResult>> _detectionController = 
      StreamController<List<DetectionResult>>.broadcast();
  
  BaseModel? _currentModel;
  ModelType? _currentModelType;
  bool _isInitialized = false;

  Stream<List<DetectionResult>> get detectionStream => _detectionController.stream;
  bool get isInitialized => _isInitialized;
  ModelType? get currentModelType => _currentModelType;
  
  /// Initialize the detection service with a specific model
  Future<void> initialize({ModelType modelType = ModelType.yolov5s}) async {
    try {
      if (_currentModel != null) {
        _currentModel!.dispose();
      }
      
      _currentModel = ModelFactory.createModel(modelType);
      await _currentModel!.initialize();
      _currentModelType = modelType;
      _isInitialized = true;
      
      print('Detection service initialized with ${_currentModel!.modelInfo.name}');
    } catch (e) {
      print('Error initializing detection service: $e');
      // Fallback to mock model only if requested model fails
      if (modelType != ModelType.mock) {
        print('Falling back to mock model');
        await initialize(modelType: ModelType.mock);
      } else {
        rethrow;
      }
    }
  }
  
  /// Switch to a different model
  Future<void> setModel(ModelType modelType) async {
    if (_currentModelType == modelType) return;
    await initialize(modelType: modelType);
  }
  
  /// Process a camera frame for object detection
  Future<List<DetectionResult>> processFrame(
    Uint8List frameData, 
    int imageHeight, 
    int imageWidth
  ) async {
    if (!_isInitialized || _currentModel == null) {
      throw Exception('Detection service not initialized');
    }
    
    try {
      final results = await _currentModel!.processFrame(frameData, imageHeight, imageWidth);
      _detectionController.add(results);
      return results;
    } catch (e) {
      print('Error processing frame: $e');
      return [];
    }
  }
  
  /// Detect specific objects by label
  Future<List<DetectionResult>> detectObjects(
    Uint8List frameData,
    int imageHeight,
    int imageWidth, {
    List<String>? targetLabels,
    double? confidenceThreshold,
  }) async {
    final allResults = await processFrame(frameData, imageHeight, imageWidth);
    
    var filteredResults = allResults;
    
    // Filter by target labels if specified
    if (targetLabels != null && targetLabels.isNotEmpty) {
      filteredResults = filteredResults
          .where((result) => targetLabels.contains(result.label))
          .toList();
    }
    
    // Filter by confidence threshold if specified
    if (confidenceThreshold != null) {
      filteredResults = filteredResults
          .where((result) => result.confidence >= confidenceThreshold)
          .toList();
    }
    
    return filteredResults;
  }
  
  /// Get model information
  ModelInfo? get modelInfo => _currentModel?.modelInfo;
  
  /// Dispose resources
  void dispose() {
    _currentModel?.dispose();
    _detectionController.close();
    _isInitialized = false;
  }
}
