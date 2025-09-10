import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'base_model.dart';
import '../types/detection_types.dart';
import '../config/model_config.dart';
import '../utils/tflite_utils.dart';

/// AVMED model for on-device medication adherence detection
/// Implements dual model inference (main detection + face detection)
class AVMedModel extends BaseModel {
  Interpreter? _mainDetectionInterpreter;
  Interpreter? _faceDetectionInterpreter;
  bool _isInitialized = false;

  @override
  ModelInfo get modelInfo => ModelConfigurations.avmed;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    try {
      print('Initializing AVMED dual model system...');
      
      // Initialize main detection model
      _mainDetectionInterpreter = await _loadModel('assets/models/av_med_16-12-24_f16.tflite');
      print('Main detection model loaded successfully');
      
      // Initialize face detection model  
      _faceDetectionInterpreter = await _loadModel('assets/models/face-detection_f16.tflite');
      print('Face detection model loaded successfully');
      
      // Validate models
      if (_mainDetectionInterpreter != null && _faceDetectionInterpreter != null) {
        _printModelInfo();
        _isInitialized = true;
        print('AVMED model system initialized successfully');
      } else {
        throw Exception('Failed to load one or both AVMED models');
      }
    } catch (e) {
      print('Error initializing AVMED model: $e');
      rethrow;
    }
  }

  /// Initialize model with bytes (for isolate use)
  Future<void> initializeWithBytes(Uint8List mainModelBytes, Uint8List faceModelBytes) async {
    try {
      print('[ISOLATE] Initializing AVMED dual model system from bytes...');
      
      // Initialize main detection model from bytes
      _mainDetectionInterpreter = TFLiteUtils.createInterpreterFromBytes(mainModelBytes);
      print('[ISOLATE] Main detection model loaded successfully');
      
      // Initialize face detection model from bytes
      _faceDetectionInterpreter = TFLiteUtils.createInterpreterFromBytes(faceModelBytes);
      print('[ISOLATE] Face detection model loaded successfully');
      
      // Validate models
      if (_mainDetectionInterpreter != null && _faceDetectionInterpreter != null) {
        _printModelInfo();
        _isInitialized = true;
        print('[ISOLATE] AVMED model system initialized successfully');
      } else {
        throw Exception('Failed to load one or both AVMED models');
      }
    } catch (e) {
      print('[ISOLATE] Error initializing AVMED model: $e');
      rethrow;
    }
  }

  Future<Interpreter> _loadModel(String modelPath) async {
    try {
      return await TFLiteUtils.loadModelFromAsset(modelPath);
    } catch (e) {
      print('Error loading model from $modelPath: $e');
      rethrow;
    }
  }

  void _printModelInfo() {
    if (_mainDetectionInterpreter != null) {
      final mainInputs = _mainDetectionInterpreter!.getInputTensors();
      final mainOutputs = _mainDetectionInterpreter!.getOutputTensors();
      print('Main Detection Model:');
      print('  Input shape: ${mainInputs.isNotEmpty ? mainInputs.first.shape : 'Unknown'}');
      print('  Output shape: ${mainOutputs.isNotEmpty ? mainOutputs.first.shape : 'Unknown'}');
    }
    
    if (_faceDetectionInterpreter != null) {
      final faceInputs = _faceDetectionInterpreter!.getInputTensors();
      final faceOutputs = _faceDetectionInterpreter!.getOutputTensors();
      print('Face Detection Model:');
      print('  Input shape: ${faceInputs.isNotEmpty ? faceInputs.first.shape : 'Unknown'}');
      print('  Output shape: ${faceOutputs.isNotEmpty ? faceOutputs.first.shape : 'Unknown'}');
    }
  }

  @override
  Future<List<DetectionResult>> processFrame(Uint8List frameData, int imageHeight, int imageWidth) async {
    if (!_isInitialized) {
      throw Exception('AVMED model not initialized');
    }

    try {
      // Preprocess frame for both models
      final mainInput = _preprocessForMainDetection(frameData, imageHeight, imageWidth);
      final faceInput = _preprocessForFaceDetection(frameData, imageHeight, imageWidth);
      
      // Run dual model inference
      final mainDetections = await _runMainDetection(mainInput, imageWidth, imageHeight);
      final faceDetections = await _runFaceDetection(faceInput, imageWidth, imageHeight);
      
      // Combine results
      final allDetections = <DetectionResult>[];
      allDetections.addAll(mainDetections);
      allDetections.addAll(faceDetections);
      
      return allDetections;
    } catch (e) {
      print('Error in AVMED frame processing: $e');
      return [];
    }
  }

  /// Preprocess frame for main detection model
  /// Based on: backend/utils/pre_process.py logic
  Float32List _preprocessForMainDetection(Uint8List frameData, int imageHeight, int imageWidth) {
    return TFLiteUtils.preprocessImage(
      frameData,
      imageHeight,
      imageWidth,
      modelInfo.inputHeight,
      modelInfo.inputWidth,
    );
  }

  /// Preprocess frame for face detection model  
  /// Resize to 640x640 as per ModelConfig.FACE_INPUT_DIM
  Float32List _preprocessForFaceDetection(Uint8List frameData, int imageHeight, int imageWidth) {
    return TFLiteUtils.preprocessImage(
      frameData,
      imageHeight,
      imageWidth,
      TFLiteUtils.avmedFaceInputSize,
      TFLiteUtils.avmedFaceInputSize,
    );
  }

  /// Run main detection inference
  /// Based on: main detection logic with confidence 0.7
  Future<List<DetectionResult>> _runMainDetection(Float32List input, int originalWidth, int originalHeight) async {
    try {
      // Create input tensor
      final inputTensor = TFLiteUtils.reshapeInput4D(input, modelInfo.inputHeight, modelInfo.inputWidth, 3);
      
      // Create output tensor for main detection
      var output = TFLiteUtils.createOutputForModel(_mainDetectionInterpreter!);
      
      // Run inference
      final success = TFLiteUtils.runInference(_mainDetectionInterpreter!, inputTensor, output);
      if (!success) {
        print('Main detection inference failed');
        return [];
      }
      
      // Process main detection results
      return _processMainDetectionOutput(output, originalWidth, originalHeight);
    } catch (e) {
      print('Error in main detection inference: $e');
      return [];
    }
  }

  /// Run face detection inference
  /// Based on: face detection logic with confidence 0.7, NMS 0.5
  Future<List<DetectionResult>> _runFaceDetection(Float32List input, int originalWidth, int originalHeight) async {
    try {
      // Create input tensor
      final inputTensor = TFLiteUtils.reshapeInput4D(input, TFLiteUtils.avmedFaceInputSize, TFLiteUtils.avmedFaceInputSize, 3);
      
      // Create output tensor for face detection
      var output = TFLiteUtils.createOutputForModel(_faceDetectionInterpreter!);
      
      // Run inference
      final success = TFLiteUtils.runInference(_faceDetectionInterpreter!, inputTensor, output);
      if (!success) {
        print('Face detection inference failed');
        return [];
      }
      
      // Process face detection results with NMS
      return _processFaceDetectionOutput(output, originalWidth, originalHeight);
    } catch (e) {
      print('Error in face detection inference: $e');
      return [];
    }
  }

  /// Process main detection output
  /// Extract: x1, y1, x2, y2, conf, cls and normalize coordinates
  List<DetectionResult> _processMainDetectionOutput(dynamic output, int originalWidth, int originalHeight) {
    const double confidenceThreshold = TFLiteUtils.avmedMainConfidence;
    
    try {
      // Parse output using consolidated TFLite utilities
      final rawDetections = TFLiteUtils.parseDetectionOutput(
        output,
        confidenceThreshold,
        modelInfo.supportedLabels,
        originalWidth,
        originalHeight,
      );
      
      // Convert to DetectionResult objects
      return rawDetections.map((detection) {
        final box = detection['box'] as Map<String, double>;
        return DetectionResult(
          label: detection['label'] as String,
          confidence: detection['confidence'] as double,
          box: DetectionBox(
            x: box['x']!,
            y: box['y']!,
            width: box['width']!,
            height: box['height']!,
          ),
        );
      }).toList();
    } catch (e) {
      print('Error processing main detection output: $e');
      return [];
    }
  }

  /// Process face detection output with NMS
  /// Apply non-max suppression and convert coordinates to relative values
  List<DetectionResult> _processFaceDetectionOutput(dynamic output, int originalWidth, int originalHeight) {
    const double confidenceThreshold = TFLiteUtils.avmedFaceConfidence;
    const double nmsThreshold = TFLiteUtils.avmedNmsThreshold;
    
    try {
      // Parse output using consolidated TFLite utilities
      final rawDetections = TFLiteUtils.parseDetectionOutput(
        output,
        confidenceThreshold,
        ['face'], // Face detection only detects faces
        originalWidth,
        originalHeight,
      );
      
      // Apply Non-Maximum Suppression using consolidated utilities
      final nmsDetections = TFLiteUtils.applyNMS(rawDetections, nmsThreshold);
      
      // Convert to DetectionResult objects
      return nmsDetections.map((detection) {
        final box = detection['box'] as Map<String, double>;
        return DetectionResult(
          label: detection['label'] as String,
          confidence: detection['confidence'] as double,
          box: DetectionBox(
            x: box['x']!,
            y: box['y']!,
            width: box['width']!,
            height: box['height']!,
          ),
        );
      }).toList();
    } catch (e) {
      print('Error processing face detection output: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _mainDetectionInterpreter?.close();
    _faceDetectionInterpreter?.close();
    _mainDetectionInterpreter = null;
    _faceDetectionInterpreter = null;
    _isInitialized = false;
    print('AVMED model disposed');
  }
}
