import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'base_model.dart';
import '../types/detection_types.dart';
import '../config/model_config.dart';

/// ML Kit Pose Detector wrapper implementing BaseModel
class MLKitPoseModel extends BaseModel {
  PoseDetector? _detector;
  bool _isInitialized = false;

  @override
  ModelInfo get modelInfo => ModelConfigurations.mediapipe;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    try {
      // Use single image mode for better performance when processing discrete frames
      // Stream mode is optimized for continuous video processing
      final options = PoseDetectorOptions(mode: PoseDetectionMode.single);
      _detector = PoseDetector(options: options);
      _isInitialized = true;
      print('[MLKIT] PoseDetector initialized');
    } catch (e) {
      _isInitialized = false;
      print('[MLKIT] Failed to initialize PoseDetector: $e');
      rethrow;
    }
  }

  @override
  Future<List<DetectionResult>> processFrame(
      Uint8List frameData, int imageHeight, int imageWidth) async {
    if (!_isInitialized || _detector == null) {
      throw StateError(
          'MLKitPoseModel not initialized. Call initialize() first.');
    }

    try {
      // Use package:image to decode the JPEG
      final image = img.decodeImage(frameData);
      if (image == null) {
        debugPrint('[MLKIT] Failed to decode image');
        return [];
      }

      // Re-encode the rotation-corrected image as PNG
      final byteData = Uint8List.fromList(img.encodePng(image));

      // Create temp file from corrected bytes (ML Kit needs file path for reliable operation)
      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}/mlkit_corrected_${DateTime.now().microsecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(byteData);

      try {
        // Use file path approach - more reliable than fromBytes
        final inputImage = InputImage.fromFilePath(tempFile.path);
        final poses = await _detector!.processImage(inputImage);

        if (poses.isEmpty) return [];

        // Convert poses to DetectionResult list
        final results = <DetectionResult>[];
        for (final pose in poses) {
          // Use the corrected image dimensions for landmark extraction
          final landmarkMap =
              _extractLandmarks(pose, image.width, image.height);
          for (final entry in landmarkMap.entries) {
            final lm = entry.value;
            results.add(DetectionResult(
              label: entry.key,
              confidence: lm.confidence, // use computed per-landmark confidence
              box: DetectionBox(
                x: lm.x.clamp(0.0, 1.0),
                y: lm.y.clamp(0.0, 1.0),
                width: 0.01,
                height: 0.01,
              ),
            ));
          }
        }

        return results;
      } finally {
        // Clean up temp file
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {
          // Ignore cleanup errors
        }
      }
    } catch (e) {
      print('[MLKIT] Error processing frame: $e');
      return [DetectionResult.createError('MLKitPoseModel', e.toString())];
    }
  }

  /// Extract normalized landmarks (0..1) keyed by MediaPipe names
  Map<String, _NormalizedPoint> _extractLandmarks(
      Pose pose, int imageWidth, int imageHeight) {
    // Map ML Kit PoseLandmark types to MediaPipe names used in ModelConfigurations
    final map = <String, _NormalizedPoint>{};

    void addLandmark(PoseLandmarkType type, String name) {
      final lm = pose.landmarks[type];
      if (lm != null) {
        // ML Kit returns pixel coordinates - normalize by provided image size
        final nx = lm.x / imageWidth;
        final ny = lm.y / imageHeight;
        // Compute binary confidence: point is either within the image (1.0) or not (0.0).
        // This treats landmarks at the edge as "inside" if 0..1; anything outside is 0.
        final inside = nx >= 0.0 && nx <= 1.0 && ny >= 0.0 && ny <= 1.0;
        final rawConfidence = inside ? 1.0 : 0.0;
        map[name] = _NormalizedPoint(nx, ny, rawConfidence);
      }
    }

    // Common set - map as many as possible
    addLandmark(PoseLandmarkType.nose, 'nose');
    addLandmark(PoseLandmarkType.leftEyeInner, 'left_eye_inner');
    addLandmark(PoseLandmarkType.leftEye, 'left_eye');
    addLandmark(PoseLandmarkType.leftEyeOuter, 'left_eye_outer');
    addLandmark(PoseLandmarkType.rightEyeInner, 'right_eye_inner');
    addLandmark(PoseLandmarkType.rightEye, 'right_eye');
    addLandmark(PoseLandmarkType.rightEyeOuter, 'right_eye_outer');
    addLandmark(PoseLandmarkType.leftEar, 'left_ear');
    addLandmark(PoseLandmarkType.rightEar, 'right_ear');
    addLandmark(PoseLandmarkType.leftMouth, 'mouth_left');
    addLandmark(PoseLandmarkType.rightMouth, 'mouth_right');
    addLandmark(PoseLandmarkType.leftShoulder, 'left_shoulder');
    addLandmark(PoseLandmarkType.rightShoulder, 'right_shoulder');
    addLandmark(PoseLandmarkType.leftElbow, 'left_elbow');
    addLandmark(PoseLandmarkType.rightElbow, 'right_elbow');
    addLandmark(PoseLandmarkType.leftWrist, 'left_wrist');
    addLandmark(PoseLandmarkType.rightWrist, 'right_wrist');
    addLandmark(PoseLandmarkType.leftPinky, 'left_pinky');
    addLandmark(PoseLandmarkType.rightPinky, 'right_pinky');
    addLandmark(PoseLandmarkType.leftIndex, 'left_index');
    addLandmark(PoseLandmarkType.rightIndex, 'right_index');
    addLandmark(PoseLandmarkType.leftThumb, 'left_thumb');
    addLandmark(PoseLandmarkType.rightThumb, 'right_thumb');
    addLandmark(PoseLandmarkType.leftHip, 'left_hip');
    addLandmark(PoseLandmarkType.rightHip, 'right_hip');
    addLandmark(PoseLandmarkType.leftKnee, 'left_knee');
    addLandmark(PoseLandmarkType.rightKnee, 'right_knee');
    addLandmark(PoseLandmarkType.leftAnkle, 'left_ankle');
    addLandmark(PoseLandmarkType.rightAnkle, 'right_ankle');
    addLandmark(PoseLandmarkType.leftHeel, 'left_heel');
    addLandmark(PoseLandmarkType.rightHeel, 'right_heel');
    addLandmark(PoseLandmarkType.leftFootIndex, 'left_foot_index');
    addLandmark(PoseLandmarkType.rightFootIndex, 'right_foot_index');

    return map;
  }

  @override
  void dispose() {
    _detector?.close();
    _detector = null;
    _isInitialized = false;
  }
}

// Simple holder for normalized coordinates
class _NormalizedPoint {
  final double x;
  final double y;
  final double confidence;
  _NormalizedPoint(this.x, this.y, [this.confidence = 1.0]);
}
