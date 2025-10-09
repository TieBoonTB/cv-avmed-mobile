import 'dart:typed_data';
import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'base_model.dart';
import '../types/detection_types.dart';
import '../config/model_config.dart';
import '../utils/tflite_utils.dart';
import '../utils/camera_image_utils.dart';

/// Face detection model extracted from AVMed
class FaceDetectionModel extends BaseModel {
  Interpreter? _interpreter;
  bool _isInitialized = false;

  @override
  ModelInfo get modelInfo => ModelConfigurations.avmed; // uses same input size/config

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    try {
      print('Loading Face Detection model...');
      _interpreter = await TFLiteUtils.loadModelFromAsset('assets/models/face-detection_f16.tflite');
      _isInitialized = true;
      print('Face Detection model initialized');
    } catch (e) {
      print('Error initializing FaceDetectionModel: $e');
      rethrow;
    }
  }

  Future<void> initializeWithBytes(Uint8List modelBytes) async {
    try {
      print('[ISOLATE] Loading Face Detection model from bytes...');
      _interpreter = TFLiteUtils.createInterpreterFromBytes(modelBytes);
      _isInitialized = true;
      print('[ISOLATE] Face Detection model initialized');
    } catch (e) {
      print('[ISOLATE] Error initializing FaceDetectionModel: $e');
      rethrow;
    }
  }

  @override
  Future<List<DetectionResult>> processFrame(Uint8List frameData, int imageHeight, int imageWidth) async {
    if (!_isInitialized || _interpreter == null) {
      throw Exception('FaceDetectionModel not initialized');
    }

    try {
      final decodedImage = img.decodeImage(frameData);
      if (decodedImage == null) return [];

      final preprocessed = CameraImageUtils.imageToTensor(
        decodedImage,
        modelInfo.inputHeight,
        modelInfo.inputWidth,
      );

      final inputTensor = TFLiteUtils.reshapeInput4D(preprocessed, modelInfo.inputHeight, modelInfo.inputWidth, 3);
      final output = TFLiteUtils.createOutputForModel(_interpreter!);
      final success = TFLiteUtils.runInference(_interpreter!, inputTensor, output);
      if (!success) return [];

      final rawDetections = _processOutput(
        output,
        modelInfo.defaultConfidenceThreshold,
        ['face'],
        imageWidth,
        imageHeight,
        modelInfo.inputWidth,
        modelInfo.inputHeight,
      );

      final nms = TFLiteUtils.applyNMS(rawDetections, 0.45);

      return nms.map((detection) {
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
      print('Error in FaceDetectionModel.processFrame: $e');
      return [];
    }
  }

  /// Reuse the same parser logic used by AVMed
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
    print('FaceDetectionModel disposed');
  }
}
