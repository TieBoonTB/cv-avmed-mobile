import 'dart:typed_data';
import '../services/base_detection_service.dart';
import '../types/detection_types.dart';
import '../models/base_model.dart';
import '../models/yolov5s_model.dart';

/// YOLOv5 detection service for object detection
/// Uses the YOLOv5 model to detect various objects in camera frames
class YOLOv5DetectionService extends BaseDetectionService {
  YOLOv5sModel? _yoloModel;
  
  @override
  String get serviceType => 'YOLOv5 Object Detection Service';
  
  @override
  BaseModel? get currentModel => _yoloModel;

  @override
  Future<void> initialize() async {
    try {
      _yoloModel = YOLOv5sModel();
      await _yoloModel!.initialize();
      setInitialized(true);
      print('YOLOv5 detection service initialized');
    } catch (e) {
      print('Error initializing YOLOv5 detection service: $e');
      rethrow;
    }
  }

  @override
  Future<List<DetectionResult>> processFrame(
    Uint8List frameData, 
    int imageHeight, 
    int imageWidth
  ) async {
    if (!isInitialized || _yoloModel == null) {
      throw Exception('YOLOv5 detection service not initialized');
    }

    try {
      // Process frame using YOLOv5 model
      final results = await _yoloModel!.processFrame(frameData, imageHeight, imageWidth);
      
      // Update the cached results
      updateDetections(results);
      
      return results;
    } catch (e) {
      print('Error processing frame in YOLOv5 detection service: $e');
      return [];
    }
  }

  /// Detect specific objects by label with confidence filtering
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

  @override
  void dispose() {
    _yoloModel?.dispose();
    super.dispose();
  }
}
