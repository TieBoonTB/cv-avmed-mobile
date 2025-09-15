import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'base_model.dart';
import '../types/detection_types.dart';
import '../config/model_config.dart';
import '../utils/tflite_utils.dart';

/// Qualcomm BlazePose Landmark Detection Model (Optimized)
/// Based on Qualcomm AI Hub implementation for BlazePose
///
/// Spec:
/// - Input: RGB image 256x256, normalized [0-1]
/// - Output: [ld_scores, landmarks]
///   - ld_scores: Shape [B] - single confidence score per batch
///   - landmarks: Shape [B, 31, 4] - normalized coordinates (x,y,z,visibility)
class QualcommPoseModel extends BaseModel {
  Interpreter? _interpreter;
  bool _isInitialized = false;

  // Qualcomm BlazePose landmark names (31 total)
  static const List<String> _landmarkNames = [
    'nose',             // 0
    'left_eye_inner',   // 1
    'left_eye',         // 2
    'left_eye_outer',   // 3
    'right_eye_inner',  // 4
    'right_eye',        // 5
    'right_eye_outer',  // 6
    'left_ear',         // 7
    'right_ear',        // 8
    'mouth_left',       // 9
    'mouth_right',      // 10
    'left_shoulder',    // 11
    'right_shoulder',   // 12
    'left_elbow',       // 13
    'right_elbow',      // 14
    'left_wrist',       // 15
    'right_wrist',      // 16
    'left_pinky',       // 17
    'right_pinky',      // 18
    'left_index',       // 19
    'right_index',      // 20
    'left_thumb',       // 21
    'right_thumb',      // 22
    'left_hip',         // 23
    'right_hip',        // 24
    'left_knee',        // 25
    'right_knee',       // 26
    'left_ankle',       // 27
    'right_ankle',      // 28
    'left_heel',        // 29
    'right_heel',       // 30
  ];

  @override
  ModelInfo get modelInfo => ModelConfigurations.qualcommPose;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    try {
      print('[QUALCOMM] Loading Qualcomm BlazePose model from ${modelInfo.modelPath}');
      _interpreter = await TFLiteUtils.loadModelFromAsset(modelInfo.modelPath);

      // Validate input dimensions match expected 256x256
      if (!TFLiteUtils.validateModelInput(_interpreter!, modelInfo.inputWidth, modelInfo.inputHeight)) {
        print('[QUALCOMM] Warning: Input shape mismatch. Expected ${modelInfo.inputWidth}x${modelInfo.inputHeight}');
      }

      _isInitialized = true;
      print('[QUALCOMM] Qualcomm BlazePose model initialized successfully');
    } catch (e) {
      _isInitialized = false;
      print('[QUALCOMM] Failed to initialize model: $e');
      rethrow;
    }
  }

  /// Initialize model from bytes (for isolate usage)
  Future<void> initializeWithBytes(Uint8List modelBytes) async {
    try {
      _interpreter = Interpreter.fromBuffer(modelBytes);
      _interpreter!.allocateTensors();
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  @override
  Future<List<DetectionResult>> processFrame(Uint8List frameData, int imageHeight, int imageWidth) async {
    if (!_isInitialized || _interpreter == null) {
      throw StateError('Model not initialized. Call initialize() first.');
    }

    try {
      // Decode and preprocess image
      final image = img.decodeImage(frameData);
      if (image == null) {
        print('[QUALCOMM] Failed to decode image');
        return [];
      }

      // Resize to model input size (256x256)
      final resized = img.copyResize(image, width: modelInfo.inputWidth, height: modelInfo.inputHeight);
      
      // Convert to model input format
      final inputTensor = _imageToTensor(resized);

      // Prepare output tensors based on model structure
      final outputs = _prepareOutputTensors();

      // Run inference
      _interpreter!.runForMultipleInputs([inputTensor], outputs);

      // Parse outputs
      final results = _parseModelOutputs(outputs, imageWidth, imageHeight);

      return results;

    } catch (e) {
      print('[QUALCOMM] Error processing frame: $e');
      return [DetectionResult.createError('Qualcomm BlazePose', 'Processing failed: $e')];
    }
  }

  /// Convert image to model input tensor format
  List<List<List<List<double>>>> _imageToTensor(img.Image image) {
    // Check actual input tensor shape from the model
    final inputTensors = _interpreter!.getInputTensors();
    if (inputTensors.isNotEmpty) {
      final inputShape = inputTensors[0].shape;
      
      // Handle different input formats
      if (inputShape.length == 4) {
        // Standard format: [batch, height, width, channels] or [batch, channels, height, width]
        final batch = inputShape[0];
        final dim1 = inputShape[1]; 
        final dim2 = inputShape[2];
        final dim3 = inputShape[3];
        
        // Determine if it's NHWC [batch, height, width, channels] or NCHW [batch, channels, height, width]
        if (dim3 == 3) {
          // NHWC format: [batch, height, width, channels]
          return _createNHWCTensor(image, batch, dim1, dim2, dim3);
        } else if (dim1 == 3) {
          // NCHW format: [batch, channels, height, width] 
          return _createNCHWTensor(image, batch, dim1, dim2, dim3);
        }
      }
    }
    
    // Fallback to standard NHWC format
    return _createNHWCTensor(image, 1, modelInfo.inputHeight, modelInfo.inputWidth, 3);
  }
  
  /// Create tensor in NHWC format [batch, height, width, channels]
  List<List<List<List<double>>>> _createNHWCTensor(img.Image image, int batch, int height, int width, int channels) {
    
    final tensor = List.generate(
      batch,
      (_) => List.generate(
        height,
        (_) => List.generate(
          width,
          (_) => List.filled(channels, 0.0),
        ),
      ),
    );

    // Fill tensor with normalized pixel data
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        // Normalize to [0-1] range
        tensor[0][y][x][0] = pixel.r / 255.0;
        tensor[0][y][x][1] = pixel.g / 255.0;
        tensor[0][y][x][2] = pixel.b / 255.0;
      }
    }

    return tensor;
  }
  
  /// Create tensor in NCHW format [batch, channels, height, width]  
  List<List<List<List<double>>>> _createNCHWTensor(img.Image image, int batch, int channels, int height, int width) {
    
    final tensor = List.generate(
      batch,
      (_) => List.generate(
        channels,
        (_) => List.generate(
          height,
          (_) => List.filled(width, 0.0),
        ),
      ),
    );

    // Fill tensor with normalized pixel data in NCHW format
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        // Normalize to [0-1] range and place in channel-first format
        tensor[0][0][y][x] = pixel.r / 255.0; // Red channel
        tensor[0][1][y][x] = pixel.g / 255.0; // Green channel  
        tensor[0][2][y][x] = pixel.b / 255.0; // Blue channel
      }
    }

    return tensor;
  }

  /// Prepare output tensors based on model structure
  Map<int, Object> _prepareOutputTensors() {
    final outputs = <int, Object>{};
    final outputTensors = _interpreter!.getOutputTensors();

    for (int i = 0; i < outputTensors.length; i++) {
      final shape = outputTensors[i].shape;

      // Create output tensor with proper shape
      if (shape.length == 1) {
        // 1D tensor (likely confidence score)
        outputs[i] = List.filled(shape[0], 0.0);
      } else if (shape.length == 2) {
        // 2D tensor (batch, features)
        outputs[i] = List.generate(shape[0], (_) => List.filled(shape[1], 0.0));
      } else if (shape.length == 3) {
        // 3D tensor (batch, landmarks, coordinates)
        outputs[i] = List.generate(
          shape[0], 
          (_) => List.generate(
            shape[1], 
            (_) => List.filled(shape[2], 0.0)
          )
        );
      } else {
        // Fallback for other shapes
        final totalSize = shape.fold(1, (a, b) => a * b);
        outputs[i] = List.filled(totalSize, 0.0);
      }
    }

    return outputs;
  }

  /// Parse model outputs
  /// Format: [ld_scores, landmarks]
  /// - ld_scores: Shape [B] - confidence score
  /// - landmarks: Shape [B, 31, 4] - normalized coordinates (x,y,z,visibility)
  List<DetectionResult> _parseModelOutputs(Map<int, Object> outputs, int originalWidth, int originalHeight) {
    try {
      // Extract confidence score (should be output 0)
      double confidence = 1.0;
      if (outputs.containsKey(0)) {
        final scoreOutput = outputs[0];
        if (scoreOutput is List && scoreOutput.isNotEmpty) {
          if (scoreOutput[0] is double) {
            confidence = (scoreOutput[0] as double).clamp(0.0, 1.0);
          } else if (scoreOutput[0] is List && (scoreOutput[0] as List).isNotEmpty) {
            confidence = ((scoreOutput[0] as List)[0] as double).clamp(0.0, 1.0);
          }
        }
      }

      // Apply confidence threshold
      if (confidence < modelInfo.defaultConfidenceThreshold) {
        return [];
      }

      // Extract landmarks (should be output 1)
      List<DetectionResult> results = [];
      if (outputs.containsKey(1)) {
        final landmarkOutput = outputs[1];
        if (landmarkOutput != null) {
          results = _parseLandmarks(landmarkOutput, confidence, originalWidth, originalHeight);
        }
      } else {
        // Fallback: search for landmark data in any output
        for (var entry in outputs.entries) {
          final possibleResults = _parseLandmarks(entry.value, confidence, originalWidth, originalHeight);
          if (possibleResults.isNotEmpty) {
            results = possibleResults;
            break;
          }
        }
      }

      return results;

    } catch (e) {
      print('[QUALCOMM] Error parsing outputs: $e');
      return [];
    }
  }

  /// Parse landmark tensor into DetectionResult list
  /// Format: Shape [1, 31, 4] - 31 landmarks with 4 values each (x,y,z,visibility)
  List<DetectionResult> _parseLandmarks(Object landmarkOutput, double confidence, int originalWidth, int originalHeight) {
    try {
      // Handle the 3D tensor format [1, 31, 4]
      if (landmarkOutput is List && landmarkOutput.isNotEmpty) {
        final batch = landmarkOutput[0];
        if (batch is List && batch.length >= 31) {
          final results = <DetectionResult>[];
          
          for (int i = 0; i < _landmarkNames.length && i < batch.length; i++) {
            final landmark = batch[i];
            if (landmark is List && landmark.length >= 2) {
              // Extract x,y coordinates (first two values)
              double x = (landmark[0] as num).toDouble();
              double y = (landmark[1] as num).toDouble();
              
              // Extract z and visibility if available
              double visibility = landmark.length > 3 ? (landmark[3] as num).toDouble() : 1.0;
              
              // Handle different coordinate formats
              if (x > 1.0 || y > 1.0) {
                // Coordinates might be in pixel space, normalize by input size
                x = x / modelInfo.inputWidth;
                y = y / modelInfo.inputHeight;
              }

              // Ensure coordinates are in [0-1] range
              x = x.clamp(0.0, 1.0);
              y = y.clamp(0.0, 1.0);
              
              // Use visibility as confidence if it's in reasonable range
              final landmarkConfidence = (visibility >= 0.0 && visibility <= 1.0) ? visibility * confidence : confidence;

              // Create detection result for this landmark
              results.add(DetectionResult(
                label: _landmarkNames[i],
                confidence: landmarkConfidence.clamp(0.0, 1.0),
                box: DetectionBox(
                  x: x,
                  y: y,
                  width: 0.01, // Small width for point landmark
                  height: 0.01, // Small height for point landmark
                ),
              ));
            }
          }
          
          return results;
        }
      }
      
      // Fallback: flatten and parse as before
      final flatData = <double>[];
      void flatten(Object obj) {
        if (obj is double) {
          flatData.add(obj);
        } else if (obj is num) {
          flatData.add(obj.toDouble());
        } else if (obj is List) {
          for (var item in obj) {
            flatten(item);
          }
        }
      }
      flatten(landmarkOutput);

      if (flatData.length < 62) { // 31 landmarks × 2 coordinates = 62 minimum
        return [];
      }

      // Calculate values per landmark
      final valuesPerLandmark = (flatData.length / _landmarkNames.length).round();

      // Parse each landmark
      final results = <DetectionResult>[];
      for (int i = 0; i < _landmarkNames.length; i++) {
        final landmarkIndex = i * valuesPerLandmark;
        if (landmarkIndex + 1 >= flatData.length) break;

        // Extract x,y coordinates (should be first two values)
        double x = flatData[landmarkIndex];
        double y = flatData[landmarkIndex + 1];

        // Handle different coordinate formats
        if (x > 1.0 || y > 1.0) {
          // Coordinates might be in pixel space, normalize by input size
          x = x / modelInfo.inputWidth;
          y = y / modelInfo.inputHeight;
        }

        // Ensure coordinates are in [0-1] range
        x = x.clamp(0.0, 1.0);
        y = y.clamp(0.0, 1.0);

        // Create detection result for this landmark
        results.add(DetectionResult(
          label: _landmarkNames[i],
          confidence: confidence,
          box: DetectionBox(
            x: x,
            y: y,
            width: 0.01, // Small width for point landmark
            height: 0.01, // Small height for point landmark
          ),
        ));
      }

      return results;

    } catch (e) {
      print('[QUALCOMM] Error parsing landmarks: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    print('[QUALCOMM] Model disposed');
  }
}