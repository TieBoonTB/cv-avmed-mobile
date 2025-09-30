import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'base_detection_service.dart';
import '../models/base_model.dart';
import '../types/detection_types.dart';
import '../models/websocket_models.dart';

/// WebSocket-based detection service for AVMED
/// Communicates with remote AVMED WebSocket server for AI detection
class WebSocketDetectionService extends BaseDetectionService {
  WebSocketChannel? _channel;
  String? _serverUrl;
  SessionConfig? _sessionConfig;
  
  bool _isConnected = false;
  bool _isSessionInitialized = false;
  String? _sessionId;
  
  // Connection management
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const Duration heartbeatInterval = Duration(seconds: 30);
  
  // Message handling
  final Completer<bool> _initCompleter = Completer<bool>();
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};
  
  @override
  String get serviceType => 'WebSocket AVMED Detection Service';

  @override
  BaseModel? get currentModel => null; // No local model

  /// Check if WebSocket is connected and session is initialized
  bool get isReady => _isConnected && _isSessionInitialized;

  /// Check if WebSocket is connected
  bool get isConnected => _isConnected;

  /// Check if WebSocket is currently attempting to reconnect
  bool get isReconnecting => _reconnectTimer?.isActive == true;

  /// Get current session ID
  String? get sessionId => _sessionId;

  @override
  Future<void> initialize() async {
    if (isInitialized) return;
    
    try {
      print('[WebSocket] Initializing WebSocket detection service...');
      setInitialized(true);
      print('[WebSocket] WebSocket detection service initialized (connection pending)');
    } catch (e) {
      print('[WebSocket] Error initializing: $e');
      setInitialized(false);
      rethrow;
    }
  }

  /// Connect to WebSocket server
  Future<bool> connect(String serverUrl) async {
    if (_isConnected) {
      print('[WebSocket] Already connected to $serverUrl');
      return true;
    }

    _serverUrl = serverUrl;
    print('[WebSocket] Connecting to $serverUrl');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      
      // Listen for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      
      // Start heartbeat
      _startHeartbeat();
      
      print('[WebSocket] Connected to $serverUrl');
      return true;
    } catch (e) {
      print('[WebSocket] Connection failed: $e');
      _isConnected = false;
      _scheduleReconnect();
      return false;
    }
  }

  /// Initialize session with configuration
  Future<bool> initializeSession(SessionConfig config) async {
    if (!_isConnected || _channel == null) {
      print('[WebSocket] Cannot initialize session - not connected');
      return false;
    }

    if (_isSessionInitialized) {
      print('[WebSocket] Session already initialized');
      return true;
    }

    _sessionConfig = config;
    _sessionId = config.sessionId;

    try {
      final initMessage = WebSocketMessage(
        type: MessageType.init,
        payload: config.toJson(),
      );

      print('[WebSocket] Sending init message: ${config.toJson()}');
      _channel!.sink.add(json.encode(initMessage.toJson()));

      // Wait for response
      final result = await _initCompleter.future;
      _isSessionInitialized = result;
      
      if (result) {
        print('[WebSocket] Session initialized successfully');
      } else {
        print('[WebSocket] Session initialization failed');
      }
      
      return result;
    } catch (e) {
      print('[WebSocket] Error initializing session: $e');
      _isSessionInitialized = false;
      return false;
    }
  }

  @override
  Future<List<DetectionResult>> processFrame(
    Uint8List frameData,
    int imageHeight,
    int imageWidth,
  ) async {
    if (!isReady || _channel == null) {
      print('[WebSocket] Service not ready for frame processing');
      return [];
    }

    try {
      // Convert frame to base64
      final base64Frame = base64Encode(frameData);
      
      final frameMessage = WebSocketMessage(
        type: MessageType.frame,
        payload: {
          'b64Frame': base64Frame,
        },
      );

      // Send frame to server
      _channel!.sink.add(json.encode(frameMessage.toJson()));
      
      // Return current detections (will be updated when response arrives)
      return lastDetections;
    } catch (e) {
      print('[WebSocket] Error processing frame: $e');
      return [];
    }
  }

  /// End current session
  Future<void> endSession() async {
    if (!_isConnected || _channel == null || !_isSessionInitialized) {
      print('[WebSocket] Cannot end session - not in valid state');
      return;
    }

    try {
      final endMessage = WebSocketMessage(
        type: MessageType.end,
      );

      print('[WebSocket] Sending end session message');
      _channel!.sink.add(json.encode(endMessage.toJson()));
      
      _isSessionInitialized = false;
      _sessionId = null;
      _sessionConfig = null;
      
      print('[WebSocket] Session ended successfully');
    } catch (e) {
      print('[WebSocket] Error ending session: $e');
    }
  }

  /// Disconnect from WebSocket
  void disconnect() {
    print('[WebSocket] Disconnecting...');
    
    _stopHeartbeat();
    _stopReconnectTimer();
    
    if (_channel != null) {
      _channel!.sink.close(status.normalClosure);
      _channel = null;
    }
    
    _isConnected = false;
    _isSessionInitialized = false;
    _sessionId = null;
    _sessionConfig = null;
    
    print('[WebSocket] Disconnected');
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(dynamic message) {
    try {
      print('[WebSocket] Raw message received: $message');
      print('[WebSocket] Message type: ${message.runtimeType}');
      
      // First check if it's a string that looks like an error message
      if (message is String && !message.startsWith('{')) {
        print('[WebSocket] Received plain text message (not JSON): $message');
        // Handle plain text messages from server
        if (message.toLowerCase().contains('error') || message.toLowerCase().contains('invalid')) {
          print('[WebSocket] Server sent error message: $message');
        }
        return;
      }
      
      final Map<String, dynamic> data = json.decode(message);
      print('[WebSocket] Parsed JSON data: $data');
      print('[WebSocket] JSON keys: ${data.keys.toList()}');
      
      final responseMessage = WebSocketMessage.fromJson(data);
      
      print('[WebSocket] Received message: ${responseMessage.type}');
      
      switch (responseMessage.type) {
        case MessageType.init:
          _handleInitResponse(responseMessage, data);
          break;
        case MessageType.detection:
          _handleDetectionResponse(responseMessage);
          break;
        case MessageType.end:
          _handleEndResponse(responseMessage, data);
          break;
        case MessageType.error:
          _handleErrorResponse(responseMessage);
          break;
        case MessageType.heartbeat:
          _handleHeartbeatResponse(responseMessage);
          break;
        default:
          print('[WebSocket] Unknown message type: ${responseMessage.type}');
      }
    } catch (e, stackTrace) {
      print('[WebSocket] Error handling message: $e');
      print('[WebSocket] Raw message that caused error: $message');
      print('[WebSocket] Stack trace: $stackTrace');
    }
  }

  /// Handle init response
  void _handleInitResponse(WebSocketMessage message, Map<String, dynamic> rawData) {
    // Check for status in payload first, then at root level (server sends it at root)
    String? status = message.payload?['status'] as String? ?? rawData['status'] as String?;
    final success = status == 'success';
    
    if (!_initCompleter.isCompleted) {
      _initCompleter.complete(success);
    }
    
    if (success) {
      print('[WebSocket] Init response: Success');
    } else {
      print('[WebSocket] Init response: Failed - $status');
    }
  }

  /// Handle detection response
  void _handleDetectionResponse(WebSocketMessage message) {
    try {
      print('[WebSocket] Raw detection payload: ${message.payload}');
      
      // Log the raw structure to understand the server format
      if (message.payload != null) {
        final payload = message.payload!;
        print('[WebSocket] Payload keys: ${payload.keys.toList()}');
        
        if (payload.containsKey('boxes')) {
          final boxes = payload['boxes'];
          print('[WebSocket] Boxes type: ${boxes.runtimeType}, content: $boxes');
          if (boxes is List && boxes.isNotEmpty) {
            print('[WebSocket] First box structure: ${boxes.first}');
            if (boxes.first is Map) {
              final firstBox = boxes.first as Map;
              print('[WebSocket] First box keys: ${firstBox.keys.toList()}');
              if (firstBox.containsKey('label')) {
                print('[WebSocket] Label type: ${firstBox['label'].runtimeType}, value: ${firstBox['label']}');
              }
            }
          }
        }
        
        if (payload.containsKey('faces')) {
          final faces = payload['faces'];
          print('[WebSocket] Faces type: ${faces.runtimeType}, content: $faces');
          if (faces is List && faces.isNotEmpty) {
            print('[WebSocket] First face structure: ${faces.first}');
            if (faces.first is Map) {
              final firstFace = faces.first as Map;
              print('[WebSocket] First face keys: ${firstFace.keys.toList()}');
              if (firstFace.containsKey('label')) {
                print('[WebSocket] Face label type: ${firstFace['label'].runtimeType}, value: ${firstFace['label']}');
              }
            }
          }
        }
      }
      
      final detectionResult = DetectionResponseData.fromJson(message.payload ?? {});
      
      print('[WebSocket] Parsed detection - boxes: ${detectionResult.boxes.length}, faces: ${detectionResult.faces.length}');
      
      // Convert to Flutter detection format
      final List<DetectionResult> flutterDetections = [];
      
      // Add object detections with detailed logging
      for (final obj in detectionResult.boxes) {
        print('[WebSocket] Object detected: ${obj.label} (${(obj.confidence * 100).toStringAsFixed(1)}%) at (${(obj.box.x * 100).toStringAsFixed(1)}, ${(obj.box.y * 100).toStringAsFixed(1)}) size ${(obj.box.width * 100).toStringAsFixed(1)}x${(obj.box.height * 100).toStringAsFixed(1)}');
        flutterDetections.add(DetectionResult(
          label: obj.label,
          confidence: obj.confidence,
          box: DetectionBox(
            x: obj.box.x,
            y: obj.box.y,
            width: obj.box.width,
            height: obj.box.height,
            confidence: obj.confidence,
          ),
        ));
      }
      
      // Add face detections (treat as objects for compatibility) with detailed logging
      for (final face in detectionResult.faces) {
        print('[WebSocket] Face detected: label ${face.label} (${(face.confidence * 100).toStringAsFixed(1)}%) at (${(face.box.x * 100).toStringAsFixed(1)}, ${(face.box.y * 100).toStringAsFixed(1)}) size ${(face.box.width * 100).toStringAsFixed(1)}x${(face.box.height * 100).toStringAsFixed(1)}');
        flutterDetections.add(DetectionResult(
          label: 'face',
          confidence: face.confidence,
          box: DetectionBox(
            x: face.box.x,
            y: face.box.y,
            width: face.box.width,
            height: face.box.height,
            confidence: face.confidence,
          ),
        ));
      }
      
      // Update cached results and notify listeners
      updateDetections(flutterDetections);
      
      print('[WebSocket] Updated detections: ${flutterDetections.length} total (${detectionResult.boxes.length} objects, ${detectionResult.faces.length} faces)');
      
      // Log summary of unique labels detected
      final uniqueLabels = flutterDetections.map((d) => d.label).toSet();
      if (uniqueLabels.isNotEmpty) {
        print('[WebSocket] Detected labels: ${uniqueLabels.join(', ')}');
      } else {
        print('[WebSocket] No detections in this frame');
      }
    } catch (e) {
      print('[WebSocket] Error parsing detection response: $e');
    }
  }

  /// Handle end response
  void _handleEndResponse(WebSocketMessage message, Map<String, dynamic> rawData) {
    final status = message.payload?['status'] as String? ?? rawData['status'] as String?;
    print('[WebSocket] End response: $status');
  }

  /// Handle error response
  void _handleErrorResponse(WebSocketMessage message) {
    final error = message.payload?['error'] as String? ?? 'Unknown error';
    print('[WebSocket] Server error: $error');
  }

  /// Handle heartbeat response
  void _handleHeartbeatResponse(WebSocketMessage message) {
    print('[WebSocket] Heartbeat response received');
  }

  /// Handle WebSocket errors
  void _handleError(error) {
    print('[WebSocket] Connection error: $error');
    _isConnected = false;
    _scheduleReconnect();
  }

  /// Handle WebSocket disconnection
  void _handleDisconnection() {
    print('[WebSocket] Connection closed');
    _isConnected = false;
    _isSessionInitialized = false;
    _scheduleReconnect();
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      print('[WebSocket] Max reconnection attempts reached');
      return;
    }

    if (_reconnectTimer?.isActive == true) return;

    _reconnectTimer = Timer(reconnectDelay, () async {
      _reconnectAttempts++;
      print('[WebSocket] Reconnection attempt $_reconnectAttempts');
      
      if (_serverUrl != null) {
        final success = await connect(_serverUrl!);
        if (success && _sessionConfig != null) {
          await initializeSession(_sessionConfig!);
        }
      }
    });
  }

  /// Stop reconnection timer
  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Start heartbeat timer
  void _startHeartbeat() {
    print('[WebSocket] Heartbeat disabled - server may not support it');
    // Disable heartbeat as server may not support this message type
    // _heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) {
    //   if (_isConnected && _channel != null) {
    //     final heartbeatMessage = WebSocketMessage(
    //       type: MessageType.heartbeat,
    //     );
    //     _channel!.sink.add(json.encode(heartbeatMessage.toJson()));
    //   }
    // });
  }

  /// Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @override
  void dispose() {
    print('[WebSocket] Disposing WebSocket detection service...');
    
    disconnect();
    
    // Complete any pending requests
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError('Service disposed');
      }
    }
    _pendingRequests.clear();
    
    super.dispose();
    print('[WebSocket] WebSocket detection service disposed');
  }
}