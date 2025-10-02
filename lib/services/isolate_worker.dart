import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../models/yolov5s_model.dart';
import '../models/avmed_model.dart';
import '../models/mediapipe_pose_model.dart';
import '../models/base_model.dart';
import '../types/detection_types.dart';
import '../config/model_config.dart';
import 'isolate_inference_service.dart';

/// Worker that runs ML inference in an isolate
class InferenceIsolateWorker {
  final SendPort mainSendPort;
  late ReceivePort receivePort;
  BaseModel? _model;
  bool _isInitialized = false;

  InferenceIsolateWorker(this.mainSendPort);

  /// Start the isolate worker
  void start() {
    print('[ISOLATE] Starting inference worker...');
    receivePort = ReceivePort();

    // Send the send port back to main isolate
    mainSendPort.send(IsolateMessage(
      type: IsolateMessageType.ready,
      data: {'sendPort': receivePort.sendPort},
    ).toMap());

    // Start listening for messages
    receivePort.listen(_handleMessage);
    print('[ISOLATE] Worker started and listening for messages');
  }

  /// Handle messages from the main isolate
  void _handleMessage(dynamic message) async {
    try {
      final isolateMessage =
          IsolateMessage.fromMap(Map<String, dynamic>.from(message));
      print('[ISOLATE] Received message: ${isolateMessage.type}');

      switch (isolateMessage.type) {
        case IsolateMessageType.initialize:
          await _handleInitialize(isolateMessage);

        case IsolateMessageType.processFrame:
          await _handleProcessFrame(isolateMessage);

        case IsolateMessageType.dispose:
          await _handleDispose();

        default:
          print('[ISOLATE] Unknown message type: ${isolateMessage.type}');
      }
    } catch (e) {
      print('[ISOLATE] Error handling message: $e');
      _sendError('Error handling message: $e', null);
    }
  }

  /// Initialize the ML model in the isolate
  Future<void> _handleInitialize(IsolateMessage message) async {
    try {
      print('[ISOLATE] Initializing model...');
      final modelTypeIndex = message.data['modelType'] as int;
      final modelType = ModelType.values[modelTypeIndex];
      final modelBytesMap =
          Map<String, Uint8List>.from(message.data['modelBytes']);

      // Create the appropriate model with bytes
      switch (modelType) {
        case ModelType.yolov5s:
          _model = YOLOv5sModel();
          // Initialize with model bytes instead of asset path
          await (_model as YOLOv5sModel)
              .initializeWithBytes(modelBytesMap['main']!);

        case ModelType.avmed:
          _model = AVMedModel();
          // Initialize with both model bytes
          await (_model as AVMedModel).initializeWithBytes(
              modelBytesMap['main']!, modelBytesMap['face']!);

        case ModelType.mediapipe:
          _model = MediaPipePoseModel();
          // Initialize with model bytes
          await (_model as MediaPipePoseModel)
              .initializeWithBytes(modelBytesMap['main']!);

        case ModelType.sppbAnalysis:
          _model = MediaPipePoseModel();
          // Initialize with model bytes
          await (_model as MediaPipePoseModel)
              .initializeWithBytes(modelBytesMap['main']!);

        case ModelType.mlkit:
          throw Exception('Model type $modelType not yet implemented in isolate worker');
      }

      _isInitialized = true;

      print('[ISOLATE] Model initialized successfully: $modelType');

      // Send success response
      _sendResult([], message.requestId);
    } catch (e) {
      print('[ISOLATE] Error initializing model: $e');
      _sendError('Failed to initialize model: $e', message.requestId);
    }
  }

  /// Process a frame in the isolate
  Future<void> _handleProcessFrame(IsolateMessage message) async {
    if (!_isInitialized || _model == null) {
      _sendError('Model not initialized', message.requestId);
      return;
    }

    try {
      // Extract frame data
      final frameData = message.data['frameData'] as Uint8List;
      final imageHeight = message.data['imageHeight'] as int;
      final imageWidth = message.data['imageWidth'] as int;

      print(
          '[ISOLATE] Processing frame: ${frameData.length} bytes, ${imageWidth}x$imageHeight');

      // Run inference
      final stopwatch = Stopwatch()..start();
      final detections =
          await _model!.processFrame(frameData, imageHeight, imageWidth);
      stopwatch.stop();

      print(
          '[ISOLATE] Inference completed in ${stopwatch.elapsedMilliseconds}ms, found ${detections.length} detections');

      // Send results back
      _sendResult(detections, message.requestId);
    } catch (e) {
      print('[ISOLATE] Error processing frame: $e');
      _sendError('Error processing frame: $e', message.requestId);
    }
  }

  /// Handle dispose message
  Future<void> _handleDispose() async {
    try {
      print('[ISOLATE] Disposing model...');

      if (_model != null) {
        _model!.dispose();
        _model = null;
      }

      _isInitialized = false;
      receivePort.close();

      print('[ISOLATE] Worker disposed');
    } catch (e) {
      print('[ISOLATE] Error disposing: $e');
    }
  }

  /// Send successful result back to main isolate
  void _sendResult(List<DetectionResult> detections, String? requestId) {
    try {
      final detectionsData = detections.map((d) => d.toMap()).toList();

      mainSendPort.send(IsolateMessage(
        type: IsolateMessageType.result,
        data: {'detections': detectionsData},
        requestId: requestId,
      ).toMap());
    } catch (e) {
      print('[ISOLATE] Error sending result: $e');
      _sendError('Error sending result: $e', requestId);
    }
  }

  /// Send error back to main isolate
  void _sendError(String error, String? requestId) {
    try {
      mainSendPort.send(IsolateMessage(
        type: IsolateMessageType.error,
        data: {'error': error},
        requestId: requestId,
      ).toMap());
    } catch (e) {
      print('[ISOLATE] Failed to send error message: $e');
    }
  }
}
