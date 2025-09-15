import 'dart:typed_data';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'base_model.dart';
import '../types/detection_types.dart';
import '../config/model_config.dart';
import '../utils/tflite_utils.dart';

/// MediaPipe Pose Landmark model for body pose detection
class MediaPipePoseModel extends BaseModel {
  Interpreter? _interpreter;
  late List<List<int>> _inputShape;
  late List<List<int>> _outputShape;
  bool _isInitialized = false;

  @override
  ModelInfo get modelInfo => ModelConfigurations.mediapipe;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    try {
      print('Loading MediaPipe Pose model from ${ModelConfigurations.mediapipe.modelPath}');
      
      // Load the TensorFlow Lite model
      _interpreter = await TFLiteUtils.loadModelFromAsset(ModelConfigurations.mediapipe.modelPath);
      
      // Get input and output shapes
      _inputShape = _interpreter!.getInputTensors().map((tensor) => tensor.shape).toList();
      _outputShape = _interpreter!.getOutputTensors().map((tensor) => tensor.shape).toList();
      
      print('MediaPipe Model loaded successfully');
      print('Input shape: $_inputShape');
      print('Output shape: $_outputShape');
      
      // Validate model shapes
      if (_inputShape.isEmpty || _outputShape.isEmpty) {
        throw Exception('Invalid MediaPipe model - missing input or output tensors');
      }
      
      _isInitialized = true;
      print('MediaPipe Pose Model initialized successfully');
    } catch (e) {
      print('Error loading MediaPipe model: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Initialize the model with bytes (for isolate usage)
  Future<void> initializeWithBytes(Uint8List modelBytes) async {
    try {
      print('Loading MediaPipe Pose model from bytes (${modelBytes.length} bytes)');
      
      // Load the TensorFlow Lite model from bytes
      _interpreter = await Interpreter.fromBuffer(modelBytes);
      
      // Get input and output shapes
      _inputShape = _interpreter!.getInputTensors().map((tensor) => tensor.shape).toList();
      _outputShape = _interpreter!.getOutputTensors().map((tensor) => tensor.shape).toList();
      
      print('[ISOLATE] MediaPipe Model loaded successfully from bytes');
      print('[ISOLATE] Input shape: $_inputShape');
      print('[ISOLATE] Output shape: $_outputShape');
      
      // Validate model shapes
      if (_inputShape.isEmpty || _outputShape.isEmpty) {
        throw Exception('Invalid MediaPipe model - missing input or output tensors');
      }
      
      _isInitialized = true;
      print('[ISOLATE] MediaPipe Pose Model initialized successfully from bytes');
    } catch (e) {
      print('[ISOLATE] Error loading MediaPipe model from bytes: $e');
      _isInitialized = false;
      rethrow;
    }
  }


  @override
  Future<List<DetectionResult>> processFrame(Uint8List frameData, int imageHeight, int imageWidth) async {
    // Use the coordinate-based detection method internally
    final result = await detectPoseLandmarks(frameData);
    if (result == null) return [];
    
    // Convert landmark coordinates to DetectionResult for compatibility with existing code
    final landmarks = result['landmarks'] as List<Map<String, dynamic>>? ?? [];
    final detectionResults = landmarks.map((landmark) {
      final name = landmark['name'] as String;
      final x = landmark['x'] as double;       // Normalized coordinates 0-1
      final y = landmark['y'] as double;
      final confidence = landmark['confidence'] as double? ?? 0.9;  // Use per-landmark confidence
      
      return DetectionResult(
        label: name,
        confidence: confidence,
        box: DetectionBox(
          x: x,           // Already normalized 0-1
          y: y,           // Already normalized 0-1  
          width: 0.01,    // Small point size for landmarks
          height: 0.01,   // Small point size for landmarks
        ),
      );
    }).toList();
    
    print('[ISOLATE] Inference completed in ???ms, found ${detectionResults.length} detections');
    return detectionResults;
  }

  /// Detect pose landmarks and return coordinate data like source repository
  Future<Map<String, dynamic>?> detectPoseLandmarks(Uint8List frameData) async {
    if (!_isInitialized || _interpreter == null) {
      throw StateError('MediaPipe model not initialized. Call initialize() first.');
    }

    try {
      // Convert JPEG bytes to Image object (like source repository)
      final image = img.decodeImage(frameData);
      if (image == null) {
        print('Failed to decode camera image');
        return null;
      }

      // Resize to model input size (256x256 like source)
      final resizedImage = img.copyResize(image, width: modelInfo.inputWidth, height:  modelInfo.inputHeight);

      // Convert to normalized float tensor like source repository
      final inputTensor = _imageToNormalizedTensor(resizedImage);

      // Prepare output tensors using source repository pattern
      final outputShapes = _outputShape;
      print('MediaPipe inference with ${outputShapes.length} output tensors');

      // Create output arrays for each tensor (simplified approach based on source)
      final outputs = <int, Object>{};
      
      // Output 0: Landmarks [1, 195] 
      final outputLandmarks = List.generate(outputShapes[0][0], (_) => List.filled(outputShapes[0][1], 0.0));
      outputs[0] = outputLandmarks;
      
      // Output 1: Confidence [1, 1] - like source repository outputIdentity1
      final outputConfidence = List.generate(outputShapes[1][0], (_) => List.filled(outputShapes[1][1], 0.0));
      outputs[1] = outputConfidence;
      
      // Additional outputs (create based on actual shapes)
      for (int i = 2; i < outputShapes.length; i++) {
        if (outputShapes[i].length == 4) {
          // 4D tensor
          outputs[i] = List.generate(outputShapes[i][0], (_) =>
            List.generate(outputShapes[i][1], (_) =>
              List.generate(outputShapes[i][2], (_) =>
                List.filled(outputShapes[i][3], 0.0)
              )
            )
          );
        } else if (outputShapes[i].length == 2) {
          // 2D tensor
          outputs[i] = List.generate(outputShapes[i][0], (_) => List.filled(outputShapes[i][1], 0.0));
        }
      }

      // Run inference like source repository
      final inputs = <Object>[inputTensor];
      _interpreter!.runForMultipleInputs(inputs, outputs);

      // Check confidence like source repository (from output 1)
      final confidenceValue = outputConfidence[0][0];
      print('MediaPipe confidence: $confidenceValue');
      
      // Use threshold like source (0.8)
      if (confidenceValue < 0.8) {
        print('MediaPipe confidence too low: $confidenceValue');
        return null;
      }

      // Parse landmarks and return coordinate data like source repository
      return _parseLandmarkCoordinates(outputLandmarks[0], 256, image.width, image.height);

    } catch (e) {
      print('Error during MediaPipe inference: $e');
      return null;
    }
  }

  /// Convert image to normalized tensor like source repository  
  List<List<List<List<double>>>> _imageToNormalizedTensor(img.Image image) {
    final tensor = List.generate(1, (_) =>
      List.generate(256, (h) =>
        List.generate(256, (w) =>
          List.filled(3, 0.0)
        )
      )
    );

    for (int h = 0; h < 256; h++) {
      for (int w = 0; w < 256; w++) {
        final pixel = image.getPixel(w, h);
        // Normalize to 0-1 range like source repository
        tensor[0][h][w][0] = pixel.r / 255.0;  // R channel
        tensor[0][h][w][1] = pixel.g / 255.0;  // G channel  
        tensor[0][h][w][2] = pixel.b / 255.0;  // B channel
      }
    }

    return tensor;
  }

  /// Parse landmarks like source repository and return coordinate data
  Map<String, dynamic> _parseLandmarkCoordinates(List<double> outputData, int inputSize, int originalWidth, int originalHeight) {
    print('Parsing landmarks from ${outputData.length} output values');
    
    // Source repository expects 39 landmarks with 5 values each = 195 total
    const int landmarksCount = 33;
    const int valuesPerLandmark = 5;
    
    // MediaPipe pose landmark names (based on source repository usage)
    const landmarkNames = [
      'nose', 'left_eye_inner', 'left_eye', 'left_eye_outer', 'right_eye_inner',
      'right_eye', 'right_eye_outer', 'left_ear', 'right_ear', 'mouth_left',
      'mouth_right', 'left_shoulder', 'right_shoulder', 'left_elbow', 'right_elbow',
      'left_wrist', 'right_wrist', 'left_pinky', 'right_pinky', 'left_index',
      'right_index', 'left_thumb', 'right_thumb', 'left_hip', 'right_hip',
      'left_knee', 'right_knee', 'left_ankle', 'right_ankle', 'left_heel',
      'right_heel', 'left_foot_index', 'right_foot_index'
    ];

    final landmarks = <Map<String, dynamic>>[];
    final points = <Map<String, double>>[];

    // Parse landmarks with robust handling for units (pixels vs normalized)
    // We'll auto-detect whether outputs are in pixels (0..inputSize) or normalized (0..1)
    double sampleMin = double.infinity;
    double sampleMax = -double.infinity;

    for (int i = 0; i < landmarksCount; i++) {
      final baseIndex = i * valuesPerLandmark;

      final rawOutX = outputData[baseIndex];
      final rawOutY = outputData[baseIndex + 1];

      // Track min/max for debugging
      sampleMin = math.min(sampleMin, math.min(rawOutX, rawOutY));
      sampleMax = math.max(sampleMax, math.max(rawOutX, rawOutY));
    }

    // Print a small summary to help diagnose whether outputs are 0..1 or 0..inputSize
    print('Landmark output sample min=$sampleMin max=$sampleMax (inputSize=$inputSize)');

    for (int i = 0; i < landmarksCount; i++) {
      final baseIndex = i * valuesPerLandmark;

      // Extract the full tuple for this landmark (may have >2 values)
      final tuple = List<double>.generate(valuesPerLandmark, (j) => outputData[baseIndex + j]);

      final rawOutX = tuple[0];
      final rawOutY = tuple[1];

      // If values are > 1.5 we assume they're in pixel units relative to inputSize
      final normalizedX = (rawOutX > 1.5) ? (rawOutX / inputSize) : rawOutX;
      final normalizedY = (rawOutY > 1.5) ? (rawOutY / inputSize) : rawOutY;

      // Clamp to 0..1 after normalization
      final nx = normalizedX.clamp(0.0, 1.0);
      final ny = normalizedY.clamp(0.0, 1.0);

      // Convert to pixel coordinates for rawX/rawY (map to original image)
      final rawX = nx * originalWidth;
      final rawY = ny * originalHeight;

      // Get landmark name, fallback to index if not available
      final landmarkName = i < landmarkNames.length ? landmarkNames[i] : 'landmark_$i';

      // This model doesn't seem to have landmark confidence
      final landmarkConfidence = 7;
      
      // Apply per-landmark confidence threshold (adjust this value as needed)
      const double landmarkThreshold = 5.0; // arbitrary number

      // Debug print the full tuple and computed coords
      // print('LM[$i] $landmarkName tuple=${tuple.map((v) => v.toStringAsFixed(4)).toList()} visibility=${visibility.toStringAsFixed(4)} presence=${presence.toStringAsFixed(4)} normalized=(${nx.toStringAsFixed(4)}, ${ny.toStringAsFixed(4)})');

      // Only include landmarks that pass the per-landmark confidence threshold
      if (landmarkConfidence >= landmarkThreshold) {

        // Store with corrected coordinate system
        landmarks.add({
          'name': landmarkName,
          'x': nx,        // Normalized 0-1
          'y': ny,        // Normalized 0-1
          'rawX': rawX,   // Pixel coordinates for drawing
          'rawY': rawY,
        });

        // Also provide pixel coordinates for drawing (like source repository)
        points.add({
          'x': rawX,
          'y': rawY,
        });
      }
    }
    
    print('MediaPipe detected ${landmarks.length} landmarks');
    
    // Return data like source repository
    return {
      'landmarks': landmarks,
      'points': points,           // For drawing skeleton
      'confidence': 0.9,         // Overall confidence
    };
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    print('MediaPipe Pose model disposed');
  }
}
