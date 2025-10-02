import 'dart:async';
import 'dart:typed_data';
import 'base_detection_service.dart';
import '../models/base_model.dart';
import '../types/detection_types.dart';
import '../models/websocket_models.dart';
import 'websocket_detection_service.dart';

/// AVMED WebSocket Detection Service
/// Integrates WebSocket communication with the existing detection service architecture
class AVMedWebSocketDetectionService extends BaseDetectionService {
  final WebSocketDetectionService _webSocketService = WebSocketDetectionService();
  
  String? _serverUrl;
  SessionConfig? _sessionConfig;
  bool _isSessionActive = false;
  
  // Detection throttling
  DateTime? _lastFrameTime;
  static const Duration minFrameInterval = Duration(milliseconds: 200); // 5 FPS max
  
  @override
  String get serviceType => 'AVMED WebSocket Detection Service';

  @override
  BaseModel? get currentModel => null; // Remote model

  /// Check if service is fully ready (connected and session initialized)
  bool get isSessionReady => _webSocketService.isReady && _isSessionActive;

  /// Get current session ID
  String? get sessionId => _webSocketService.sessionId;

  @override
  Future<void> initialize() async {
    if (isInitialized) return;
    
    try {
      print('[AVMED-WS] Initializing AVMED WebSocket detection service...');
      
      // Initialize base WebSocket service
      await _webSocketService.initialize();
      
      // Listen to WebSocket detections and forward them
      _webSocketService.detectionStream.listen((detections) {
        updateDetections(detections);
      });
      
      setInitialized(true);
      print('[AVMED-WS] AVMED WebSocket detection service initialized');
    } catch (e) {
      print('[AVMED-WS] Error initializing: $e');
      setInitialized(false);
      rethrow;
    }
  }

  /// Connect to AVMED WebSocket server and initialize session
  Future<bool> connectAndInitialize({
    required String serverUrl,
    required String patientCode,
    bool shouldRecord = false,
    int frameWidth = 1280,
    int frameHeight = 720,
    int framesPerSecond = 30,
  }) async {
    if (!isInitialized) {
      throw StateError('Service not initialized. Call initialize() first.');
    }

    _serverUrl = serverUrl;
    
    try {
      print('[AVMED-WS] Connecting to server: $serverUrl');
      
      // Connect to WebSocket
      final connected = await _webSocketService.connect(serverUrl);
      if (!connected) {
        print('[AVMED-WS] Failed to connect to server');
        return false;
      }

      // Create session configuration
      _sessionConfig = SessionConfig(
        patientCode: patientCode,
        shouldRecord: shouldRecord,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
        framesPerSecond: framesPerSecond,
      );

      // Initialize session
      final sessionInitialized = await _webSocketService.initializeSession(_sessionConfig!);
      if (!sessionInitialized) {
        print('[AVMED-WS] Failed to initialize session');
        _webSocketService.disconnect();
        return false;
      }

      _isSessionActive = true;
      print('[AVMED-WS] Successfully connected and initialized session: ${_sessionConfig!.sessionId}');
      return true;
    } catch (e) {
      print('[AVMED-WS] Error connecting and initializing: $e');
      _isSessionActive = false;
      return false;
    }
  }

  @override
  Future<List<DetectionResult>> processFrame(
    Uint8List frameData,
    int imageHeight,
    int imageWidth,
  ) async {
    if (!isSessionReady) {
      print('[AVMED-WS] Service not ready for frame processing (connected: ${_webSocketService.isConnected}, sessionActive: $_isSessionActive)');
      return [];
    }

    // Throttle frame processing to avoid overwhelming the server
    final now = DateTime.now();
    if (_lastFrameTime != null && now.difference(_lastFrameTime!) < minFrameInterval) {
      // Return cached results if we're throttling
      print('[AVMED-WS] Throttling frame (${now.difference(_lastFrameTime!).inMilliseconds}ms since last frame)');
      return lastDetections;
    }
    _lastFrameTime = now;

    try {
      print('[AVMED-WS] Processing frame: ${imageWidth}x$imageHeight (${frameData.length} bytes)');
      // Process frame through WebSocket service
      final results = await _webSocketService.processFrame(frameData, imageHeight, imageWidth);
      
      // Update cached results
      updateDetections(results);
      
      return results;
    } catch (e) {
      print('[AVMED-WS] Error processing frame: $e');
      return [];
    }
  }

  /// End current session (stop recording if enabled)
  Future<void> endSession() async {
    if (!_isSessionActive) {
      print('[AVMED-WS] No active session to end');
      return;
    }

    try {
      await _webSocketService.endSession();
      _isSessionActive = false;
      _sessionConfig = null;
      
      print('[AVMED-WS] Session ended successfully');
    } catch (e) {
      print('[AVMED-WS] Error ending session: $e');
    }
  }

  /// Disconnect from WebSocket server
  void disconnect() {
    _webSocketService.disconnect();
    _isSessionActive = false;
    _sessionConfig = null;
    _serverUrl = null;
    print('[AVMED-WS] Disconnected from server');
  }

  /// Manually retry connection (useful for UI retry buttons)
  Future<bool> retryConnection() async {
    if (_serverUrl != null && _sessionConfig != null) {
      print('[AVMED-WS] Manually retrying connection...');
      return await connectAndInitialize(
        serverUrl: _serverUrl!,
        patientCode: _sessionConfig!.patientCode,
        shouldRecord: _sessionConfig!.shouldRecord,
        frameWidth: _sessionConfig!.frameWidth,
        frameHeight: _sessionConfig!.frameHeight,
        framesPerSecond: _sessionConfig!.framesPerSecond,
      );
    }
    return false;
  }

  /// Check if a specific label has been detected within the given threshold
  bool isLabelDetected(String label, double threshold) {
    print('[AVMED-WS] Checking isLabelDetected for label: "$label", threshold: $threshold');
    
    // Check if any detections exist
    if (lastDetections.isEmpty) {
      print('[AVMED-WS] No detections available');
      return false;
    }

    print('[AVMED-WS] Checking ${lastDetections.length} detections');
    
    // Check each detection object for the label
    for (final detection in lastDetections) {
      print('[AVMED-WS] Checking detection: label="${detection.label}", confidence=${detection.confidence}');
      
      // Normalize both strings for comparison (lowercase, trimmed)
      final normalizedDetectionLabel = detection.label.toLowerCase().trim();
      final normalizedTargetLabel = label.toLowerCase().trim();
      
      print('[AVMED-WS] Normalized comparison: "$normalizedDetectionLabel" vs "$normalizedTargetLabel"');
      
      // Check for exact match or contains match
      bool labelMatches = false;
      if (normalizedDetectionLabel == normalizedTargetLabel) {
        labelMatches = true;
        print('[AVMED-WS] Exact label match found');
      } else if (normalizedDetectionLabel.contains(normalizedTargetLabel) || 
                normalizedTargetLabel.contains(normalizedDetectionLabel)) {
        labelMatches = true;
        print('[AVMED-WS] Partial label match found');
      }
      
      // Check confidence threshold
      bool confidenceOk = detection.confidence >= threshold;
      print('[AVMED-WS] Confidence check: ${detection.confidence} >= $threshold = $confidenceOk');
      
      if (labelMatches && confidenceOk) {
        print('[AVMED-WS] Label "$label" detected with confidence ${detection.confidence}');
        return true;
      }
    }

    print('[AVMED-WS] Label "$label" not detected above threshold $threshold');
    return false;
  }

  /// Get all detections for a specific label
  List<DetectionResult> getDetectionsForLabel(String targetLabel) {
    return lastDetections
        .where((detection) => detection.label.toLowerCase() == targetLabel.toLowerCase())
        .toList();
  }

  /// Get detection with highest confidence for a specific label
  DetectionResult? getBestDetectionForLabel(String targetLabel) {
    final detections = getDetectionsForLabel(targetLabel);
    if (detections.isEmpty) return null;
    
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    return detections.first;
  }

  /// Get connection status information
  Map<String, dynamic> getConnectionInfo() {
    return {
      'serverUrl': _serverUrl,
      'isConnected': _webSocketService.isConnected,
      'isReconnecting': _webSocketService.isReconnecting,
      'isSessionActive': _isSessionActive,
      'sessionId': sessionId,
      'patientCode': _sessionConfig?.patientCode,
      'shouldRecord': _sessionConfig?.shouldRecord ?? false,
      'lastDetectionTime': _lastFrameTime?.toIso8601String(),
      'lastDetectionCount': lastDetections.length,
    };
  }

  @override
  void dispose() {
    print('[AVMED-WS] Disposing AVMED WebSocket detection service...');
    
    // End session if active
    if (_isSessionActive) {
      endSession();
    }
    
    // Disconnect and dispose WebSocket service
    _webSocketService.dispose();
    
    _isSessionActive = false;
    _sessionConfig = null;
    _serverUrl = null;
    _lastFrameTime = null;
    
    super.dispose();
    print('[AVMED-WS] AVMED WebSocket detection service disposed');
  }
}