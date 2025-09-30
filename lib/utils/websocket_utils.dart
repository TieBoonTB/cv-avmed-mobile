import 'dart:convert';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../models/websocket_models.dart';
import '../config/websocket_config.dart';

/// Utility functions for WebSocket operations
class WebSocketUtils {
  static const Uuid _uuid = Uuid();
  
  /// Generate a unique session ID
  static String generateSessionId() {
    return _uuid.v4();
  }
  
  /// Generate a unique patient code (for testing purposes)
  static String generatePatientCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'PT_${timestamp.toString().substring(timestamp.toString().length - 8)}';
  }
  
  /// Convert Uint8List to base64 string for WebSocket transmission
  static String frameToBase64(Uint8List frameData) {
    return base64Encode(frameData);
  }
  
  /// Convert base64 string back to Uint8List
  static Uint8List base64ToFrame(String base64Data) {
    return base64Decode(base64Data);
  }
  
  /// Validate WebSocket message structure
  static bool isValidMessage(Map<String, dynamic> json) {
    try {
      // Check required fields
      if (!json.containsKey('type')) return false;
      
      final type = json['type'] as String?;
      if (type == null || type.isEmpty) return false;
      
      // Validate message type
      try {
        MessageTypeExtension.fromString(type);
      } catch (e) {
        return false;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Create error message
  static WebSocketMessage createErrorMessage(String error, [String? details]) {
    return WebSocketMessage(
      type: MessageType.error,
      payload: {
        'error': error,
        if (details != null) 'details': details,
      },
    );
  }
  
  /// Create heartbeat message
  static WebSocketMessage createHeartbeatMessage() {
    return WebSocketMessage(
      type: MessageType.heartbeat,
      payload: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
  
  /// Parse detection confidence from string
  static double parseConfidence(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }
  
  /// Normalize bounding box coordinates
  static NormalizedBoundingBox normalizeBoundingBox({
    required double x,
    required double y,
    required double width,
    required double height,
    required double imageWidth,
    required double imageHeight,
  }) {
    return NormalizedBoundingBox(
      x: x / imageWidth,
      y: y / imageHeight,
      width: width / imageWidth,
      height: height / imageHeight,
    );
  }
  
  /// Denormalize bounding box coordinates
  static Map<String, double> denormalizeBoundingBox({
    required NormalizedBoundingBox box,
    required double imageWidth,
    required double imageHeight,
  }) {
    return {
      'x': box.x * imageWidth,
      'y': box.y * imageHeight,
      'width': box.width * imageWidth,
      'height': box.height * imageHeight,
    };
  }
  
  /// Check if detection confidence meets threshold
  static bool meetsConfidenceThreshold(double confidence, double threshold) {
    return confidence >= threshold && 
           WebSocketConfig.isValidConfidenceThreshold(confidence);
  }
  
  /// Filter detections by confidence threshold
  static List<ObjectDetection> filterByConfidence(
    List<ObjectDetection> detections,
    double threshold,
  ) {
    return detections
        .where((detection) => meetsConfidenceThreshold(detection.confidence, threshold))
        .toList();
  }
  
  /// Sort detections by confidence (highest first)
  static List<ObjectDetection> sortByConfidence(List<ObjectDetection> detections) {
    final sorted = List<ObjectDetection>.from(detections);
    sorted.sort((a, b) => b.confidence.compareTo(a.confidence));
    return sorted;
  }
  
  /// Find best detection for a specific label
  static ObjectDetection? findBestDetection(
    List<ObjectDetection> detections,
    String targetLabel, {
    double? minConfidence,
  }) {
    final filtered = detections
        .where((detection) => detection.label.toLowerCase() == targetLabel.toLowerCase())
        .where((detection) => minConfidence == null || detection.confidence >= minConfidence)
        .toList();
    
    if (filtered.isEmpty) return null;
    
    final sorted = sortByConfidence(filtered);
    return sorted.first;
  }
  
  /// Calculate detection area (normalized)
  static double calculateDetectionArea(NormalizedBoundingBox box) {
    return box.width * box.height;
  }
  
  /// Check if detection is near image edge
  static bool isNearEdge(
    NormalizedBoundingBox box, {
    double edgeThreshold = 0.05, // 5% from edge
  }) {
    return box.x <= edgeThreshold ||
           box.y <= edgeThreshold ||
           (box.x + box.width) >= (1.0 - edgeThreshold) ||
           (box.y + box.height) >= (1.0 - edgeThreshold);
  }
  
  /// Validate session configuration
  static bool isValidSessionConfig(SessionConfig config) {
    // Check required fields
    if (config.patientCode.isEmpty) return false;
    if (config.sessionId == null || config.sessionId!.isEmpty) return false;
    
    // Check frame dimensions
    if (!WebSocketConfig.isValidFrameDimensions(config.frameWidth, config.frameHeight)) {
      return false;
    }
    
    // Check frames per second
    if (config.framesPerSecond <= 0 || config.framesPerSecond > 60) {
      return false;
    }
    
    return true;
  }
  
  /// Create default session configuration
  static SessionConfig createDefaultSessionConfig(String patientCode) {
    return SessionConfig(
      sessionId: generateSessionId(),
      patientCode: patientCode,
      shouldRecord: WebSocketConfig.defaultShouldRecord,
      frameWidth: WebSocketConfig.maxFrameWidth,
      frameHeight: WebSocketConfig.maxFrameHeight,
      framesPerSecond: WebSocketConfig.defaultFramesPerSecond,
    );
  }
  
  /// Calculate recommended frame processing interval
  static Duration calculateFrameInterval({
    required int targetFps,
    Duration? minInterval,
  }) {
    final calculatedInterval = Duration(milliseconds: (1000 / targetFps).round());
    final minimum = minInterval ?? WebSocketConfig.minFrameInterval;
    
    return calculatedInterval.compareTo(minimum) < 0 ? minimum : calculatedInterval;
  }
  
  /// Format duration for display
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final milliseconds = duration.inMilliseconds % 1000;
    
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else if (seconds > 0) {
      return '${seconds}s';
    } else {
      return '${milliseconds}ms';
    }
  }
  
  /// Convert detection to debug string
  static String detectionToDebugString(ObjectDetection detection) {
    return '${detection.label} (${(detection.confidence * 100).toStringAsFixed(1)}%) '
           'at (${(detection.box.x * 100).toStringAsFixed(1)}, '
           '${(detection.box.y * 100).toStringAsFixed(1)}) '
           '${(detection.box.width * 100).toStringAsFixed(1)}x'
           '${(detection.box.height * 100).toStringAsFixed(1)}';
  }
  
  /// Get AVMED label enum from string
  static AVMedLabel? getAVMedLabel(String labelString) {
    return AVMedLabel.fromString(labelString);
  }
  
  /// Check if label is a target step
  static bool isTargetStepLabel(String labelString) {
    final label = getAVMedLabel(labelString);
    return label?.isTargetStep() ?? false;
  }
  
  /// Throttle function calls based on time interval
  static DateTime? _lastCallTime;
  static bool shouldThrottle(Duration interval) {
    final now = DateTime.now();
    if (_lastCallTime == null || now.difference(_lastCallTime!) >= interval) {
      _lastCallTime = now;
      return false;
    }
    return true;
  }
  
  /// Reset throttle timer
  static void resetThrottle() {
    _lastCallTime = null;
  }
}