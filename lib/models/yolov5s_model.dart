import 'dart:typed_data';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'base_model.dart';
import '../types/detection_types.dart';
import '../config/model_config.dart';
import '../utils/tflite_utils.dart';

/// YOLOv5s TensorFlow Lite model implementation
class YOLOv5sModel extends BaseModel {
  Interpreter? _interpreter;
  bool _isInitialized = false;

  @override
  ModelInfo get modelInfo => ModelConfigurations.yolov5s;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    try {
      print('Loading YOLOv5s model...');

      // Load the TFLite model
      _interpreter = await TFLiteUtils.loadModelFromAsset(modelInfo.modelPath);

      // Print model info for debugging
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();

      print('YOLOv5s model loaded successfully');
      print('Input tensors: ${inputTensors.length}');
      print('Output tensors: ${outputTensors.length}');

      if (inputTensors.isNotEmpty) {
        print('Input shape: ${inputTensors.first.shape}');
        print('Input type: ${inputTensors.first.type}');
      }

      if (outputTensors.isNotEmpty) {
        print('Output shape: ${outputTensors.first.shape}');
        print('Output type: ${outputTensors.first.type}');
      }

      _isInitialized = true;
      print('YOLOv5s model initialized successfully');
    } catch (e) {
      print('Error initializing YOLOv5s model: $e');
      rethrow;
    }
  }

  /// Initialize model with bytes (for isolate use)
  Future<void> initializeWithBytes(Uint8List modelBytes) async {
    try {
      print('[ISOLATE] Loading YOLOv5s model from bytes...');

      // Create interpreter from bytes
      _interpreter = TFLiteUtils.createInterpreterFromBytes(modelBytes);

      // Print model info for debugging
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();

      print('[ISOLATE] YOLOv5s model loaded successfully');
      print('[ISOLATE] Input tensors: ${inputTensors.length}');
      print('[ISOLATE] Output tensors: ${outputTensors.length}');

      if (inputTensors.isNotEmpty) {
        print('[ISOLATE] Input shape: ${inputTensors.first.shape}');
        print('[ISOLATE] Input type: ${inputTensors.first.type}');
      }

      if (outputTensors.isNotEmpty) {
        print('[ISOLATE] Output shape: ${outputTensors.first.shape}');
        print('[ISOLATE] Output type: ${outputTensors.first.type}');
      }

      _isInitialized = true;
      print('[ISOLATE] YOLOv5s model initialized successfully');
    } catch (e) {
      print('[ISOLATE] Error initializing YOLOv5s model: $e');
      rethrow;
    }
  }

  @override
  Future<List<DetectionResult>> processFrame(
      Uint8List frameData, int imageHeight, int imageWidth) async {
    if (!_isInitialized || _interpreter == null) {
      throw Exception('YOLOv5s model not initialized');
    }

    try {
      // Decode image from bytes
      img.Image? image = img.decodeImage(frameData);
      if (image == null) {
        print('Failed to decode image');
        return [];
      }

      // Resize image to model input size
      img.Image resizedImage = img.copyResize(
        image,
        width: modelInfo.inputWidth,
        height: modelInfo.inputHeight,
      );

      // Convert image to input tensor
      var inputBytes = _imageToByteListFloat32(resizedImage);
      var input = TFLiteUtils.reshapeInput4D(
          inputBytes, modelInfo.inputHeight, modelInfo.inputWidth, 3);

      // Create output tensor (YOLOv5s outputs [1, 6300, 85] for 320x320 input)
      var output = TFLiteUtils.createOutput3D(6300, 85);

      // Run inference
      final success = TFLiteUtils.runInference(_interpreter!, input, output);
      if (!success) {
        print('Inference failed');
        return [];
      }

      // Process output to get detection results
      List<DetectionResult> detections = _processOutput(
        output,
        imageWidth,
        imageHeight,
        modelInfo.defaultConfidenceThreshold,
      );

      return detections;
    } catch (e) {
      print('Error processing frame with YOLOv5s: $e');
      return [DetectionResult.createError('YOLOv5', e.toString())];
    }
  }

  /// Convert image to input tensor format
  Float32List _imageToByteListFloat32(img.Image image) {
    final convertedBytes =
        Float32List(1 * modelInfo.inputHeight * modelInfo.inputWidth * 3);

    int pixelIndex = 0;
    for (int i = 0; i < modelInfo.inputHeight; i++) {
      for (int j = 0; j < modelInfo.inputWidth; j++) {
        final pixel = image.getPixel(j, i);
        convertedBytes[pixelIndex++] = pixel.r / 255.0;
        convertedBytes[pixelIndex++] = pixel.g / 255.0;
        convertedBytes[pixelIndex++] = pixel.b / 255.0;
      }
    }

    return convertedBytes;
  }

  /// Process YOLOv5s output to detection results
  List<DetectionResult> _processOutput(
    List<List<List<double>>> output,
    int imageWidth,
    int imageHeight,
    double confidenceThreshold,
  ) {
    List<DetectionResult> detections = [];

    // YOLOv5s output format: [batch, detections, (x, y, w, h, confidence, class_probs...)]
    final batch = output[0];

    for (int i = 0; i < batch.length; i++) {
      final detection = batch[i];

      if (detection.length < 85) continue;

      final objectness = detection[4];
      if (objectness < confidenceThreshold) continue;

      // Find the class with highest probability
      double maxClassProb = 0.0;
      int maxClassIndex = 0;

      for (int j = 5; j < detection.length; j++) {
        if (detection[j] > maxClassProb) {
          maxClassProb = detection[j];
          maxClassIndex = j - 5;
        }
      }

      final confidence = objectness * maxClassProb;
      if (confidence < confidenceThreshold) continue;

      // Convert from model coordinates to image coordinates
      final centerX = detection[0] / modelInfo.inputWidth;
      final centerY = detection[1] / modelInfo.inputHeight;
      final width = detection[2] / modelInfo.inputWidth;
      final height = detection[3] / modelInfo.inputHeight;

      // Convert to corner coordinates
      final x = centerX - width / 2;
      final y = centerY - height / 2;

      // Get class label
      final label = maxClassIndex < modelInfo.supportedLabels.length
          ? modelInfo.supportedLabels[maxClassIndex]
          : 'unknown';

      detections.add(DetectionResult(
        label: label,
        confidence: confidence,
        box: DetectionBox(x: x, y: y, width: width, height: height),
      ));
    }

    // Apply Non-Maximum Suppression
    return _applyNMS(detections, 0.45);
  }

  /// Apply Non-Maximum Suppression to remove duplicate detections
  List<DetectionResult> _applyNMS(
      List<DetectionResult> detections, double nmsThreshold) {
    if (detections.isEmpty) return detections;

    // Sort by confidence in descending order
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    List<DetectionResult> filteredDetections = [];

    for (int i = 0; i < detections.length; i++) {
      bool keep = true;

      for (int j = 0; j < filteredDetections.length; j++) {
        if (_calculateIoU(detections[i].box, filteredDetections[j].box) >
            nmsThreshold) {
          keep = false;
          break;
        }
      }

      if (keep) {
        filteredDetections.add(detections[i]);
      }
    }

    return filteredDetections;
  }

  /// Calculate Intersection over Union (IoU) between two bounding boxes
  double _calculateIoU(DetectionBox box1, DetectionBox box2) {
    final intersectionX1 = max(box1.x, box2.x);
    final intersectionY1 = max(box1.y, box2.y);
    final intersectionX2 = min(box1.x + box1.width, box2.x + box2.width);
    final intersectionY2 = min(box1.y + box1.height, box2.y + box2.height);

    if (intersectionX2 <= intersectionX1 || intersectionY2 <= intersectionY1) {
      return 0.0;
    }

    final intersectionArea =
        (intersectionX2 - intersectionX1) * (intersectionY2 - intersectionY1);
    final box1Area = box1.width * box1.height;
    final box2Area = box2.width * box2.height;
    final unionArea = box1Area + box2Area - intersectionArea;

    return unionArea > 0 ? intersectionArea / unionArea : 0.0;
  }

  @override
  void dispose() {
    try {
      _interpreter?.close();
      _interpreter = null;
      _isInitialized = false;
      print('YOLOv5s model disposed');
    } catch (e) {
      print('Error disposing YOLOv5s model: $e');
    }
  }
}
