import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:math' as math;
import 'base_model.dart';
import '../types/detection_types.dart';
import '../config/model_config.dart';
import '../utils/tflite_utils.dart';
import '../utils/camera_image_utils.dart';

/// AVMED model for on-device medication adherence detection
/// Implements dual model inference (main detection + face detection)
class AVMedModel extends BaseModel {
  Interpreter? _interpreter;
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
      _interpreter = await _loadModel(modelInfo.modelPath);
      print('Main detection model loaded successfully');
      
      // Validate model
      if (_interpreter != null) {
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
  Future<void> initializeWithBytes(Uint8List mainModelBytes) async {
    try {
      print('[ISOLATE] Initializing AVMED dual model system from bytes...');
      
      // Initialize main detection model from bytes
      _interpreter = TFLiteUtils.createInterpreterFromBytes(mainModelBytes);
      print('[ISOLATE] Main detection model loaded successfully');
      
      // Initialize face detection model from bytes
      // Validate models
      if (_interpreter != null) {
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

  @override
  Future<List<DetectionResult>> processFrame(Uint8List frameData, int imageHeight, int imageWidth) async {
    if (!_isInitialized) {
      throw Exception('AVMED model not initialized');
    }

    try {
      // Decode JPEG bytes to Image object 
      final decodedImage = img.decodeImage(frameData);
      if (decodedImage == null) {
        throw Exception('Failed to decode image data');
      }
      
      // Convert image to tensor since letterboxing is already done
      final preprocessed = CameraImageUtils.imageToTensor(
        decodedImage,
        modelInfo.inputHeight,
        modelInfo.inputWidth,
      );
      
      // Run dual model inference
      final mainDetections = await _runMainDetection(preprocessed, imageWidth, imageHeight);
      
      // Combine results
      final allDetections = <DetectionResult>[];
      allDetections.addAll(mainDetections);
      
      return allDetections;
    } catch (e) {
      print('Error in AVMED frame processing: $e');
      return [DetectionResult.createError('AVMED', e.toString())];
    }
  }

  /// Run main detection inference
  /// Based on: main detection logic with confidence 0.7
  Future<List<DetectionResult>> _runMainDetection(Float32List input, int originalWidth, int originalHeight) async {
    try {
      // Create input tensor
      final inputTensor = TFLiteUtils.reshapeInput4D(input, modelInfo.inputHeight, modelInfo.inputWidth, 3);
      
      // Create output tensor for main detection
      var output = TFLiteUtils.createOutputForModel(_interpreter!);
      
      // Run inference
      final success = TFLiteUtils.runInference(_interpreter!, inputTensor, output);
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


  /// Process main detection output
  /// Extract: x1, y1, x2, y2, conf, cls and normalize coordinates
  List<DetectionResult> _processMainDetectionOutput(dynamic output, int originalWidth, int originalHeight) {
    
    try {
      final rawDetections = _processOutput(
        output,
        modelInfo.defaultConfidenceThreshold,
        modelInfo.supportedLabels,
        originalWidth,
        originalHeight,
        originalWidth, // Use original width instead of model input width
        originalHeight, // Use original height instead of model input height
      );

      // Apply Non-Maximum Suppression to remove duplicate detections
      final nmsDetections = TFLiteUtils.applyNMS(rawDetections, 0.45);
      
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
      print('Error processing main detection output: $e');
      return [];
    }
  }

  

  /// YOLOv8-style parser..
  List<Map<String, dynamic>> _processOutput(
    List<List<List<double>>> output,
    double confidenceThreshold,
    List<String> labels,
    int originalWidth,
    int originalHeight,
    int inputWidth,
    int inputHeight,
  ) {
    final List<Map<String, dynamic>> detections = [];
    
    if (output.isEmpty) {
      return detections;
    }
    
    // Handle shapes: TFLite often outputs [1, features, num] similar to ONNX exports
    List<List<double>> preds;
    final out = output[0];
    
    if (out.isEmpty || out[0].isEmpty) {
      return detections;
    }
    
    final int b = out.length;
    final int c = out[0].length;
    
    // Decide whether to transpose: if second dim looks like features (>=4) and smaller than third
    if (b < c && b >= 4) {
      // Transpose equivalent: out = np.transpose(out, (0, 2, 1))
      preds = List.generate(c, (i) => List.generate(b, (j) => out[j][i]));
    } else {
      preds = out;
    }
    
    // Parse as YOLOv8-like: [x,y,w,h,class_scores...]
    if (preds.isEmpty || preds[0].length < 4) {
      return detections;
    }
    
    // Extract boxes and class scores
    final List<List<double>> boxesXywh = [];
    final List<List<double>> classScores = [];
    
    for (int i = 0; i < preds.length; i++) {
      final detection = preds[i];
      boxesXywh.add(detection.sublist(0, 4));
      
      if (detection.length > 4) {
        // Only take the number of classes we have labels for
        final int numClassesToTake = math.min(labels.length, detection.length - 4);
        classScores.add(detection.sublist(4, 4 + numClassesToTake));
      } else {
        classScores.add([1.0]); // Default score if no class scores
      }
    }
    
    // Calculate max scores and class IDs
    final List<double> scores = [];
    final List<int> classIds = [];
    
    for (int i = 0; i < classScores.length; i++) {
      if (classScores[i].isNotEmpty) {
        double maxScore = classScores[i][0];
        int maxIndex = 0;
        
        for (int j = 1; j < classScores[i].length; j++) {
          if (classScores[i][j] > maxScore) {
            maxScore = classScores[i][j];
            maxIndex = j;
          }
        }
        
        scores.add(maxScore);
        classIds.add(maxIndex);
      } else {
        scores.add(1.0);
        classIds.add(0);
      }
    }
    
    // Filter by confidence threshold
    final List<int> validIndices = [];
    for (int i = 0; i < scores.length; i++) {
      if (scores[i] >= confidenceThreshold) {
        validIndices.add(i);
      }
    }
    
    if (validIndices.isEmpty) {
      return detections;
    }
    
    // Filter arrays
    final List<List<double>> filteredBoxes = validIndices.map((i) => boxesXywh[i]).toList();
    final List<double> filteredScores = validIndices.map((i) => scores[i]).toList();
    final List<int> filteredClassIds = validIndices.map((i) => classIds[i]).toList();
    
    // Extract center coordinates and dimensions
    final List<double> xC = filteredBoxes.map((box) => box[0]).toList();
    final List<double> yC = filteredBoxes.map((box) => box[1]).toList();
    final List<double> wBox = filteredBoxes.map((box) => box[2]).toList();
    final List<double> hBox = filteredBoxes.map((box) => box[3]).toList();
    
    // Check if coordinates are normalized (0-1) and scale to input size
    final double maxX = xC.isEmpty ? 0.0 : xC.reduce(math.max);
    final double maxY = yC.isEmpty ? 0.0 : yC.reduce(math.max);
    
    if (maxX <= 1.0 && maxY <= 1.0) {
      // Coordinates are normalized, scale to input size
      for (int i = 0; i < xC.length; i++) {
        xC[i] = xC[i] * inputWidth;
        yC[i] = yC[i] * inputHeight;
        wBox[i] = wBox[i] * inputWidth;
        hBox[i] = hBox[i] * inputHeight;
      }
    }
    
    // Convert from center format to corners and transform to original image
    final double scaleX = originalWidth / inputWidth;
    final double scaleY = originalHeight / inputHeight;
    
    final List<List<double>> xyxyBoxes = [];
    for (int i = 0; i < xC.length; i++) {
      final double x1 = (xC[i] - wBox[i] / 2.0) * scaleX;
      final double y1 = (yC[i] - hBox[i] / 2.0) * scaleY;
      final double x2 = (xC[i] + wBox[i] / 2.0) * scaleX;
      final double y2 = (yC[i] + hBox[i] / 2.0) * scaleY;
      
      xyxyBoxes.add([x1, y1, x2, y2]);
    }
    
    // Apply clipping and convert to final format
    for (int i = 0; i < xyxyBoxes.length; i++) {
      final double x1 = xyxyBoxes[i][0];
      final double y1 = xyxyBoxes[i][1];
      final double x2 = xyxyBoxes[i][2];
      final double y2 = xyxyBoxes[i][3];
      
      // Clip to image bounds
      final double clippedX1 = x1.clamp(0.0, originalWidth - 1.0);
      final double clippedY1 = y1.clamp(0.0, originalHeight - 1.0);
      final double clippedX2 = x2.clamp(0.0, originalWidth - 1.0);
      final double clippedY2 = y2.clamp(0.0, originalHeight - 1.0);
      
      // Convert to normalized coordinates for rendering (0.0-1.0)
      final Map<String, double> normalizedBox = {
        'x': (clippedX1 / originalWidth).clamp(0.0, 1.0),
        'y': (clippedY1 / originalHeight).clamp(0.0, 1.0),
        'width': ((clippedX2 - clippedX1) / originalWidth).clamp(0.001, 1.0),
        'height': ((clippedY2 - clippedY1) / originalHeight).clamp(0.001, 1.0),
      };
      
      // Get class label
      final int classIndex = filteredClassIds[i];
      final String label = classIndex < labels.length ? labels[classIndex] : 'class_$classIndex';
      
      detections.add({
        'box': normalizedBox,
        'confidence': filteredScores[i],
        'class_index': classIndex,
        'label': label,
      });
    }
    
    return detections;
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    
    _isInitialized = false;
    print('AVMED model disposed');
  }
}
