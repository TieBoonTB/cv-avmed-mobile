import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../types/detection_types.dart';
import '../utils/tflite_utils.dart';
import 'isolate_worker.dart';

/// Message types for isolate communication
enum IsolateMessageType {
  initialize,
  processFrame,
  dispose,
  result,
  error,
  ready,
}

/// Message structure for isolate communication
class IsolateMessage {
  final IsolateMessageType type;
  final Map<String, dynamic> data;
  final String? requestId;

  IsolateMessage({
    required this.type,
    required this.data,
    this.requestId,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.index,
      'data': data,
      'requestId': requestId,
    };
  }

  static IsolateMessage fromMap(Map<String, dynamic> map) {
    return IsolateMessage(
      type: IsolateMessageType.values[map['type']],
      data: Map<String, dynamic>.from(map['data']),
      requestId: map['requestId'],
    );
  }
}

/// Isolate-based inference service that runs ML models in background
class IsolateInferenceService {
  Isolate? _isolate;
  late SendPort _sendPort;
  late ReceivePort _receivePort;
  StreamSubscription? _permanentSubscription;
  bool _isInitialized = false;
  bool _isInitializing = false;
  
  // Request tracking
  final Map<String, Completer<List<DetectionResult>>> _pendingRequests = {};
  int _requestCounter = 0;

  bool get isInitialized => _isInitialized;

  /// Initialize the isolate and communication channels
  Future<void> initialize(String modelType) async {
    if (_isInitialized || _isInitializing) {
      return;
    }

    _isInitializing = true;
    
    try {
      print('Initializing isolate inference service for $modelType...');
      
      // Load model bytes in main thread (can access assets)
      final modelBytes = await _loadModelBytes(modelType);
      
      // Create receive port for main isolate
      _receivePort = ReceivePort();
      
      // Spawn the isolate
      _isolate = await Isolate.spawn(
        _isolateEntryPoint,
        _receivePort.sendPort,
        debugName: 'InferenceIsolate',
      );
      
      print('Isolate spawned successfully');
      
      // Set up message handling with a single persistent listener
      final completer = Completer<void>();
      bool isInitialized = false;
      
      _permanentSubscription = _receivePort.listen((message) {
        try {
          final isolateMessage = IsolateMessage.fromMap(Map<String, dynamic>.from(message));
          
          if (!isInitialized && isolateMessage.type == IsolateMessageType.ready) {
            print('Isolate is ready');
            _sendPort = isolateMessage.data['sendPort'];
            isInitialized = true;
            if (!completer.isCompleted) {
              completer.complete();
            }
          } else {
            // Handle regular messages after initialization
            _handleRegularMessage(message);
          }
        } catch (e) {
          print('Error handling isolate message: $e');
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        }
      });
      
      // Wait for isolate to be ready
      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Isolate initialization timeout'),
      );
      
      // Send initialization message with model bytes
      final initRequestId = _generateRequestId();
      
      _pendingRequests[initRequestId] = Completer<List<DetectionResult>>();
      
      _sendPort.send(IsolateMessage(
        type: IsolateMessageType.initialize,
        data: {
          'modelType': modelType,
          'modelBytes': modelBytes,
        },
        requestId: initRequestId,
      ).toMap());
      
      // Wait for initialization to complete
      try {
        await _pendingRequests[initRequestId]!.future.timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw TimeoutException('Model initialization timeout'),
        );
        print('Model initialization completed successfully');
      } catch (e) {
        print('Model initialization failed: $e');
        rethrow;
      } finally {
        _pendingRequests.remove(initRequestId);
      }
      _isInitialized = true;
      print('Isolate inference service initialized successfully');
      
    } catch (e) {
      print('Error initializing isolate inference service: $e');
      await dispose();
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Load model bytes based on model type
  Future<Map<String, Uint8List>> _loadModelBytes(String modelType) async {
    switch (modelType.toLowerCase()) {
      case 'yolov5':
      case 'yolov5s':
        final yoloBytes = await TFLiteUtils.loadModelBytesFromAsset('assets/models/yolov5s_f16.tflite');
        return {'main': yoloBytes};
        
        case 'avmed':
        final mainBytes = await TFLiteUtils.loadModelBytesFromAsset('assets/models/av_med_16-12-24_f16.tflite');
        final faceBytes = await TFLiteUtils.loadModelBytesFromAsset('assets/models/face-detection_f16.tflite');
        return {'main': mainBytes, 'face': faceBytes};
        
      case 'pose':
      case 'mediapipe':
      case 'sppb':
        final poseBytes = await TFLiteUtils.loadModelBytesFromAsset('assets/models/pose_landmark_full.tflite');
        return {'main': poseBytes};      default:
        throw Exception('Unknown model type: $modelType');
    }
  }

  /// Process a frame using the isolate
  Future<List<DetectionResult>> processFrame({
    required Uint8List frameData,
    required int imageHeight,
    required int imageWidth,
  }) async {
    if (!_isInitialized) {
      throw Exception('Isolate inference service not initialized');
    }

    final requestId = _generateRequestId();
    final completer = Completer<List<DetectionResult>>();
    _pendingRequests[requestId] = completer;

    try {
      // Send frame processing request
      _sendPort.send(IsolateMessage(
        type: IsolateMessageType.processFrame,
        data: {
          'frameData': frameData,
          'imageHeight': imageHeight,
          'imageWidth': imageWidth,
        },
        requestId: requestId,
      ).toMap());

      // Wait for result with timeout
      final result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _pendingRequests.remove(requestId);
          return <DetectionResult>[];
        },
      );

      return result;
    } catch (e) {
      _pendingRequests.remove(requestId);
      print('Error processing frame in isolate: $e');
      return [];
    }
  }

  /// Handle regular messages (after initialization)
  void _handleRegularMessage(dynamic message) {
    try {
      final isolateMessage = IsolateMessage.fromMap(Map<String, dynamic>.from(message));
      
      switch (isolateMessage.type) {
        case IsolateMessageType.result:
          _handleResultMessage(isolateMessage);
          
        case IsolateMessageType.error:
          _handleErrorMessage(isolateMessage);
          
        case IsolateMessageType.ready:
          // Ignore duplicate ready messages
          print('Ignoring duplicate ready message');
          
        default:
          print('Unknown message type: ${isolateMessage.type}');
      }
    } catch (e) {
      print('Error handling regular message: $e');
    }
  }

  /// Handle result messages from isolate
  void _handleResultMessage(IsolateMessage message) {
    final requestId = message.requestId;
    print('Received result message for request: $requestId');
    
    if (requestId != null && _pendingRequests.containsKey(requestId)) {
      final resultData = message.data['detections'] as List<dynamic>;
      final detections = resultData.map((data) => DetectionResult.fromMap(Map<String, dynamic>.from(data))).toList();
      
      print('Completing request $requestId with ${detections.length} detections');
      _pendingRequests[requestId]!.complete(detections);
      _pendingRequests.remove(requestId);
    } else {
      print('Warning: Received result for unknown request ID: $requestId');
    }
  }

  /// Handle error messages from isolate
  void _handleErrorMessage(IsolateMessage message) {
    final requestId = message.requestId;
    final error = message.data['error'] ?? 'Unknown error';
    
    print('Isolate error: $error');
    
    if (requestId != null && _pendingRequests.containsKey(requestId)) {
      _pendingRequests[requestId]!.complete([]);
      _pendingRequests.remove(requestId);
    }
  }

  /// Generate unique request ID
  String _generateRequestId() {
    return 'req_${_requestCounter++}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Dispose the isolate and clean up resources
  Future<void> dispose() async {
    if (_isolate != null) {
      try {
        // Send dispose message if isolate is still alive
        if (_isInitialized) {
          _sendPort.send(IsolateMessage(
            type: IsolateMessageType.dispose,
            data: {},
          ).toMap());
        }
      } catch (e) {
        print('Error sending dispose message: $e');
      }
      
      // Kill the isolate
      _isolate!.kill(priority: Isolate.immediate);
      _isolate = null;
    }
    
    // Cancel subscriptions
    _permanentSubscription?.cancel();
    _permanentSubscription = null;
    
    // Close receive port
    _receivePort.close();
    
    // Complete any pending requests with empty results
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.complete([]);
      }
    }
    _pendingRequests.clear();
    
    _isInitialized = false;
    print('Isolate inference service disposed');
  }

  /// Isolate entry point - runs in the background isolate
  static void _isolateEntryPoint(SendPort mainSendPort) {
    // Import the worker here to avoid loading in main isolate
    IsolateWorker.run(mainSendPort);
  }
}

/// Worker class that runs inside the isolate
class IsolateWorker {
  static void run(SendPort mainSendPort) {
    // Import here to avoid loading in main isolate
    InferenceIsolateWorker(mainSendPort).start();
  }
}
