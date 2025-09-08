import 'dart:async';
import 'dart:typed_data';
import 'base_detection_service.dart';
import '../models/avmed_model.dart';
import '../models/base_model.dart';
import '../types/detection_types.dart';

/// AVMED Detection Service implementing dual model inference
/// Handles on-device medication adherence detection using:
/// - Main detection model (av_med_16-12-24_f16.tflite)
/// - Face detection model (face-detection_f16.tflite)
class AVMedDetectionService extends BaseDetectionService {
  AVMedModel? _avmedModel;
  bool _isProcessing = false;

  @override
  String get serviceType => 'AVMED Dual Model Detection';

  @override
  BaseModel? get currentModel => _avmedModel;

  @override
  Future<void> initialize() async {
    try {
      print('Initializing AVMED Detection Service...');
      
      _avmedModel = AVMedModel();
      await _avmedModel!.initialize();
      
      setInitialized(true);
      print('AVMED Detection Service initialized successfully');
    } catch (e) {
      print('Error initializing AVMED Detection Service: $e');
      setInitialized(false);
      rethrow;
    }
  }

  @override
  Future<List<DetectionResult>> processFrame(
    Uint8List frameData, 
    int imageHeight, 
    int imageWidth
  ) async {
    if (!isInitialized || _avmedModel == null) {
      throw Exception('AVMED Detection Service not initialized');
    }

    // Prevent overlapping processing calls
    if (_isProcessing) {
      print('Skipping AVMED frame - previous processing still in progress');
      return lastDetections;
    }

    _isProcessing = true;
    List<DetectionResult> detections = [];
    
    try {
      // Performance monitoring
      final stopwatch = Stopwatch()..start();
      
      // Run dual model inference
      detections = await _avmedModel!.processFrame(frameData, imageHeight, imageWidth);
      
      stopwatch.stop();
      final processingTime = stopwatch.elapsedMilliseconds;
      
      // Log performance metrics
      print('AVMED processing completed in ${processingTime}ms, found ${detections.length} detections');
      
      // Performance warning for slow processing
      if (processingTime > 500) {
        print('Warning: AVMED processing took ${processingTime}ms - consider optimization');
      }
      
      // Filter and validate detections
      detections = _filterValidDetections(detections);
      
      // Update cache and notify listeners
      updateDetections(detections);
      
    } catch (e) {
      print('Error in AVMED frame processing: $e');
      detections = [];
    } finally {
      _isProcessing = false;
    }
    
    return detections;
  }

  /// Filter and validate detection results
  /// Ensures detections meet quality thresholds and are properly formatted
  List<DetectionResult> _filterValidDetections(List<DetectionResult> detections) {
    return detections.where((detection) {
      // Basic validation
      if (detection.confidence < 0.0 || detection.confidence > 1.0) {
        return false;
      }
      
      // Bounding box validation
      final box = detection.box;
      if (box.x < 0.0 || box.x > 1.0 || 
          box.y < 0.0 || box.y > 1.0 ||
          box.width <= 0.0 || box.height <= 0.0) {
        return false;
      }
      
      // AVMED-specific label validation
      if (!_isValidAVMedLabel(detection.label)) {
        return false;
      }
      
      return true;
    }).toList();
  }

  /// Check if label is valid for AVMED detection
  bool _isValidAVMedLabel(String label) {
    const validLabels = [
      'pill',
      'mouth',
      'hand', 
      'face',
      'tongue',
      'water',
      'cup',
      'person',
      // Add other AVMED-specific labels as needed
    ];
    
    return validLabels.contains(label.toLowerCase());
  }

  /// Get detection statistics for monitoring
  Map<String, dynamic> getDetectionStats() {
    final labelCounts = <String, int>{};
    final confidenceSum = <String, double>{};
    
    for (final detection in lastDetections) {
      final label = detection.label.toLowerCase();
      labelCounts[label] = (labelCounts[label] ?? 0) + 1;
      confidenceSum[label] = (confidenceSum[label] ?? 0.0) + detection.confidence;
    }
    
    final avgConfidence = <String, double>{};
    for (final label in labelCounts.keys) {
      avgConfidence[label] = confidenceSum[label]! / labelCounts[label]!;
    }
    
    return {
      'total_detections': lastDetections.length,
      'label_counts': labelCounts,
      'average_confidence': avgConfidence,
      'is_processing': _isProcessing,
    };
  }

  @override
  void dispose() {
    _avmedModel?.dispose();
    _avmedModel = null;
    setInitialized(false);
    super.dispose();
    print('AVMED Detection Service disposed');
  }
}
