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

  /// AVMED-specific constants
  static const double avmedMainConfidence = 0.5;
  static const double avmedFaceConfidence = 0.5;
  static const double avmedNmsThreshold = 0.5;
  static const int avmedFaceInputSize = 224; 

  /// Preprocess image for AVMED models
  /// Converts BGR→RGB, resizes, normalizes, and formats for inference
  static Float32List preprocessImage(
    Uint8List imageData,
    int originalHeight,
    int originalWidth,
    int targetHeight,
    int targetWidth,
  ) {
    // This is a simplified preprocessing implementation
    // In production, you would implement full BGR→RGB conversion,
    // proper resizing algorithm, and normalization
    
    final int totalPixels = targetHeight * targetWidth * 3;
    final Float32List preprocessed = Float32List(totalPixels);
    
    // Placeholder preprocessing - replace with actual implementation
    // that handles BGR→RGB conversion, resizing, and normalization
    final double scaleX = originalWidth / targetWidth;
    final double scaleY = originalHeight / targetHeight;
    
    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        // Simple nearest neighbor sampling (replace with proper interpolation)
        final int srcX = (x * scaleX).round().clamp(0, originalWidth - 1);
        final int srcY = (y * scaleY).round().clamp(0, originalHeight - 1);
        final int srcIndex = (srcY * originalWidth + srcX) * 3;
        final int dstIndex = (y * targetWidth + x) * 3;
        
        if (srcIndex + 2 < imageData.length && dstIndex + 2 < preprocessed.length) {
          // BGR → RGB conversion and normalization
          preprocessed[dstIndex] = (imageData[srcIndex + 2] / 255.0);     // R
          preprocessed[dstIndex + 1] = (imageData[srcIndex + 1] / 255.0); // G
          preprocessed[dstIndex + 2] = (imageData[srcIndex] / 255.0);     // B
        }
      }
    }
    
    return preprocessed;
  }

  /// Parse detection output from model
  /// Extracts bounding boxes, confidence scores, and class labels
  static List<Map<String, dynamic>> parseDetectionOutput(
    List<List<List<double>>> output,
    double confidenceThreshold,
    List<String> classNames,
    int originalWidth,
    int originalHeight,
  ) {
    final List<Map<String, dynamic>> detections = [];
    
    if (output.isEmpty || output[0].isEmpty) {
      return detections;
    }
    
    final int numDetections = output[0].length;
    final int numFeatures = output[0][0].length;
    
    for (int i = 0; i < numDetections; i++) {
      final detection = output[0][i];
      
      // Extract confidence (assuming format: [x, y, w, h, conf, class_scores...])
      final double confidence = detection[4];
      
      if (confidence < confidenceThreshold) continue;
      
      // Extract bounding box coordinates
      final double x = detection[0];
      final double y = detection[1];
      final double width = detection[2];
      final double height = detection[3];
      
      // Extract class index (highest confidence class)
      int classIndex = 0;
      double maxClassScore = 0.0;
      if (numFeatures > 5) {
        for (int j = 5; j < numFeatures; j++) {
          if (detection[j] > maxClassScore) {
            maxClassScore = detection[j];
            classIndex = j - 5;
          }
        }
      }
      
      // Normalize coordinates to relative values (0.0-1.0)
      final Map<String, double> normalizedBox = {
        'x': (x / originalWidth).clamp(0.0, 1.0),
        'y': (y / originalHeight).clamp(0.0, 1.0),
        'width': (width / originalWidth).clamp(0.0, 1.0),
        'height': (height / originalHeight).clamp(0.0, 1.0),
      };
      
      detections.add({
        'box': normalizedBox,
        'confidence': confidence,
        'class_index': classIndex,
        'label': classIndex < classNames.length ? classNames[classIndex] : 'unknown',
      });
    }
    
    return detections;
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
    print('Creating output tensor with shape: $outputShape');
    
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
