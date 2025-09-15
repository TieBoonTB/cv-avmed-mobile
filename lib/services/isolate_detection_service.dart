import 'dart:typed_data';
import 'base_detection_service.dart';
import 'isolate_inference_service.dart';
import '../models/base_model.dart';
import '../types/detection_types.dart';

/// Detection service that runs inference in background isolates
/// This prevents UI freezing during heavy ML operations
class IsolateDetectionService extends BaseDetectionService {
  final String _modelType;
  IsolateInferenceService? _isolateService;
  bool _isDisposing = false;

  IsolateDetectionService(this._modelType);

  @override
  String get serviceType => 'Isolate-based $_modelType Detection';

  @override
  BaseModel? get currentModel => null; // Model runs in isolate

  @override
  Future<void> initialize() async {
    try {
      print('Initializing isolate detection service for $_modelType...');
      
      _isolateService = IsolateInferenceService();
      await _isolateService!.initialize(_modelType);
      
      setInitialized(true);
      print('Isolate detection service initialized successfully');
    } catch (e) {
      print('Error initializing isolate detection service: $e');
      setInitialized(false);
      rethrow;
    }
  }

  @override
  Future<List<DetectionResult>> processFrame(
    Uint8List frameData,
    int imageHeight,
    int imageWidth,
  ) async {
    if (!isInitialized || _isolateService == null || _isDisposing) {
      print("[ISOLATE] Isolate Service not initialized.");
      return [];
    }

    try {
      // Process frame in isolate - this won't block the UI thread
      final results = await _isolateService!.processFrame(
        frameData: frameData,
        imageHeight: imageHeight,
        imageWidth: imageWidth,
      );

      // Update cached results
      updateDetections(results);
      
      return results;
    } catch (e) {
      print('Error processing frame in isolate: $e');
      return [];
    }
  }

  @override
  void dispose() {
    if (_isDisposing) return;
    
    _isDisposing = true;
    print('Disposing isolate detection service...');
    
    _isolateService?.dispose();
    _isolateService = null;
    
    super.dispose();
    print('Isolate detection service disposed');
  }
}

/// YOLOv5 detection service using isolates
class IsolateYOLOv5DetectionService extends IsolateDetectionService {
  IsolateYOLOv5DetectionService() : super('yolov5');
}

/// AVMED detection service using isolates
class IsolateAVMedDetectionService extends IsolateDetectionService {
  IsolateAVMedDetectionService() : super('avmed');
}

/// Chair detection service using isolates (extends YOLOv5 with filtering)
class IsolateChairDetectionService extends IsolateYOLOv5DetectionService {
  @override
  String get serviceType => 'Isolate-based Chair Detection (YOLOv5 filtered)';

  @override
  Future<List<DetectionResult>> processFrame(
    Uint8List frameData,
    int imageHeight,
    int imageWidth,
  ) async {
    // Get all YOLOv5 detections from the isolate
    final allDetections = await super.processFrame(frameData, imageHeight, imageWidth);
    
    // Filter for chairs only at the service level
    final chairDetections = allDetections.where((d) => d.label.toLowerCase() == 'chair').toList();
    
    print('Chair Detection: Found ${chairDetections.length} chairs out of ${allDetections.length} total detections');
    
    // Update cached results with filtered detections
    updateDetections(chairDetections);
    
    return chairDetections;
  }
}

/// Pose detection service using isolates
class IsolatePoseDetectionService extends IsolateDetectionService {
  IsolatePoseDetectionService() : super('pose');
}
