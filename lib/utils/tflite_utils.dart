import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Simplified TensorFlow Lite utilities
class TFLiteUtils {
  /// Load and initialize interpreter from asset
  static Future<Interpreter> loadModelFromAsset(String assetPath) async {
    final interpreter = await Interpreter.fromAsset(assetPath);
    interpreter.allocateTensors();
    return interpreter;
  }
  
  /// Load model bytes from asset (for isolate use)
  static Future<Uint8List> loadModelBytesFromAsset(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  }
  
  /// Create interpreter from model bytes (isolate-safe)
  static Interpreter createInterpreterFromBytes(Uint8List modelBytes) {
    final interpreter = Interpreter.fromBuffer(modelBytes);
    interpreter.allocateTensors();
    return interpreter;
  }
  
  /// Run inference safely with error handling
  static bool runInference(Interpreter interpreter, dynamic input, dynamic output) {
    try {
      interpreter.run(input, output);
      return true;
    } catch (e) {
      print('Error running inference: $e');
      return false;
    }
  }
  
  /// Create 4D input tensor from Float32List
  static List<List<List<List<double>>>> reshapeInput4D(
    Float32List data, 
    int height, 
    int width, 
    int channels
  ) {
    final input = <List<List<List<double>>>>[];
    final batch = <List<List<double>>>[];
    
    for (int h = 0; h < height; h++) {
      final row = <List<double>>[];
      for (int w = 0; w < width; w++) {
        final pixel = <double>[];
        for (int c = 0; c < channels; c++) {
          final index = h * width * channels + w * channels + c;
          pixel.add(index < data.length ? data[index] : 0.0);
        }
        row.add(pixel);
      }
      batch.add(row);
    }
    input.add(batch);
    
    return input;
  }
  
  /// Create 3D output tensor
  static List<List<List<double>>> createOutput3D(int detections, int classes) {
    return [
      List.generate(detections, (_) => List.filled(classes, 0.0))
    ];
  }

  /// Apply Non-Maximum Suppression to filter overlapping detections
  /// Uses IoU (Intersection over Union) to remove duplicate detections
  static List<Map<String, dynamic>> applyNMS(
    List<Map<String, dynamic>> detections,
    double nmsThreshold,
  ) {
    if (detections.isEmpty) return [];
    
    // Sort by confidence (highest first)
    detections.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));
    
    final List<Map<String, dynamic>> filteredDetections = [];
    final List<bool> suppressed = List.filled(detections.length, false);
    
    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;
      
      filteredDetections.add(detections[i]);
      
      final currentBox = detections[i]['box'] as Map<String, double>;
      
      // Suppress overlapping boxes
      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;
        
        final compareBox = detections[j]['box'] as Map<String, double>;
        final iou = _calculateIoU(currentBox, compareBox);
        
        if (iou > nmsThreshold) {
          suppressed[j] = true;
        }
      }
    }
    
    return filteredDetections;
  }

  /// Calculate Intersection over Union (IoU) between two bounding boxes
  static double _calculateIoU(Map<String, double> box1, Map<String, double> box2) {
    final double x1_1 = box1['x']!;
    final double y1_1 = box1['y']!;
    final double x2_1 = x1_1 + box1['width']!;
    final double y2_1 = y1_1 + box1['height']!;
    
    final double x1_2 = box2['x']!;
    final double y1_2 = box2['y']!;
    final double x2_2 = x1_2 + box2['width']!;
    final double y2_2 = y1_2 + box2['height']!;
    
    // Calculate intersection area
    final double intersectionX1 = math.max(x1_1, x1_2);
    final double intersectionY1 = math.max(y1_1, y1_2);
    final double intersectionX2 = math.min(x2_1, x2_2);
    final double intersectionY2 = math.min(y2_1, y2_2);
    
    final double intersectionWidth = math.max(0.0, intersectionX2 - intersectionX1);
    final double intersectionHeight = math.max(0.0, intersectionY2 - intersectionY1);
    final double intersectionArea = intersectionWidth * intersectionHeight;
    
    // Calculate union area
    final double area1 = (x2_1 - x1_1) * (y2_1 - y1_1);
    final double area2 = (x2_2 - x1_2) * (y2_2 - y1_2);
    final double unionArea = area1 + area2 - intersectionArea;
    
    return unionArea > 0 ? intersectionArea / unionArea : 0.0;
  }

  /// Create output tensor dynamically based on interpreter
  static List<List<List<double>>> createOutputForModel(Interpreter interpreter) {
    final outputTensors = interpreter.getOutputTensors();
    if (outputTensors.isEmpty) {
      throw Exception('No output tensors found in model');
    }
    
    final outputShape = outputTensors.first.shape;
    
    // Create dynamic output based on model shape
    if (outputShape.length == 3) {
      // Format: [batch, detections, features]
      return List.generate(
        outputShape[0],
        (i) => List.generate(
          outputShape[1],
          (j) => List.generate(outputShape[2], (k) => 0.0),
        ),
      );
    } else {
      throw Exception('Unsupported output shape: $outputShape');
    }
  }

  /// Validate model input dimensions
  static bool validateModelInput(Interpreter interpreter, int expectedWidth, int expectedHeight) {
    final inputTensors = interpreter.getInputTensors();
    if (inputTensors.isEmpty) return false;
    
    final inputShape = inputTensors.first.shape;
    if (inputShape.length < 3) return false;
    
    // Check if dimensions match (allowing for batch dimension)
    final bool widthMatch = inputShape.contains(expectedWidth);
    final bool heightMatch = inputShape.contains(expectedHeight);
    
    return widthMatch && heightMatch;
  }

  /// Get model performance statistics
  static Map<String, dynamic> getModelStats(Interpreter interpreter) {
    final inputTensors = interpreter.getInputTensors();
    final outputTensors = interpreter.getOutputTensors();
    
    return {
      'input_tensors': inputTensors.length,
      'output_tensors': outputTensors.length,
      'input_shape': inputTensors.isNotEmpty ? inputTensors.first.shape : null,
      'output_shape': outputTensors.isNotEmpty ? outputTensors.first.shape : null,
      'input_type': inputTensors.isNotEmpty ? inputTensors.first.type.toString() : null,
      'output_type': outputTensors.isNotEmpty ? outputTensors.first.type.toString() : null,
    };
  }
}
