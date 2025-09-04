import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Simplified TensorFlow Lite utilities
class TFLiteUtils {
  /// Load and initialize interpreter from asset
  static Future<Interpreter> loadModelFromAsset(String assetPath) async {
    final interpreter = await Interpreter.fromAsset(assetPath);
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
}
