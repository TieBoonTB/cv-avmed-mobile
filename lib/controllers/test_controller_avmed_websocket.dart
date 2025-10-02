import 'package:flutter/foundation.dart';
import 'base_test_controller.dart';
import '../services/base_detection_service.dart';
import '../services/avmed_websocket_detection_service.dart';
import '../types/detection_types.dart';
import '../utils/step_constants.dart';
import '../config/websocket_config.dart';
import '../utils/websocket_utils.dart';

/// AVMED WebSocket Test Controller
/// Implements the medication adherence test pipeline using WebSocket-based AVMED detection
class TestControllerAVMedWebSocket extends BaseTestController {
  AVMedWebSocketDetectionService? _avmedWebSocketService;
  
  // WebSocket configuration
  String? _serverUrl;
  String? _patientCode;
  bool _shouldRecord;
  
  TestControllerAVMedWebSocket({
    VoidCallback? onTestUpdate,
    VoidCallback? onTestComplete,
    Function(bool)? onStepComplete,
    String? serverUrl,
    String? patientCode,
    bool shouldRecord = false,
  }) : _serverUrl = serverUrl,
       _patientCode = patientCode,
       _shouldRecord = shouldRecord,
       super(
          onTestUpdate: onTestUpdate,
          onTestComplete: onTestComplete,
          onStepComplete: onStepComplete,
        ) {
    // Recommend a processing interval (ms) for callers
    frameProcessingIntervalMs = 300.0; // 3.3 FPS to avoid overwhelming WebSocket
  }

  /// Configure WebSocket connection parameters
  void configureWebSocket({
    required String serverUrl,
    required String patientCode,
    bool shouldRecord = false,
  }) {
    _serverUrl = serverUrl;
    _patientCode = patientCode;
    _shouldRecord = shouldRecord;
  }

  @override
  Map<String, BaseDetectionService> createDetectionServices() {
    _avmedWebSocketService = AVMedWebSocketDetectionService();
    return {
      'objects': _avmedWebSocketService!,
    };
  }

  @override
  List<TestStep> createTestSteps() {
    const double intervalMs = 300.0; // Match frame processing interval
    
    return [
      TestStep(
        label: 'Hold pill',
        targetLabel: StepConstants.pill,
        videoPath: 'assets/instructions/holding-pill.mp4',
        targetTimeSeconds: 2.0,
        maxTime: 10.0,
        confidenceThreshold: 0.4,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Put pill on tongue',
        targetLabel: StepConstants.pillOnTongue,
        videoPath: 'assets/instructions/pill-on-tongue.mp4',
        targetTimeSeconds: 2.0,
        maxTime: 10.0,
        confidenceThreshold: 0.4,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Show no pill on tongue',
        targetLabel: StepConstants.noPillOnTongue,
        videoPath: 'assets/instructions/no-pill-on-tongue.mp4',
        targetTimeSeconds: 2.0,
        maxTime: 10.0,
        confidenceThreshold: 0.4,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Drink water',
        targetLabel: StepConstants.drinkWater,
        videoPath: 'assets/instructions/drink-water.mp4',
        targetTimeSeconds: 2.0,
        maxTime: 15.0,
        confidenceThreshold: 0.4,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Show no pill under tongue',
        targetLabel: StepConstants.noPillUnderTongue,
        videoPath: 'assets/instructions/no-pill-under-tongue.mp4',
        targetTimeSeconds: 2.0,
        maxTime: 10.0,
        confidenceThreshold: 0.4,
        frameProcessingIntervalMs: intervalMs,
      ),
    ];
  }

  /// Initialize WebSocket connection before starting test
  @override
  Future<void> initialize() async {
    // Use default configuration if not explicitly set
    if (_serverUrl == null || _patientCode == null) {
      print('[TestController-WS] Using default WebSocket configuration');
      _serverUrl = _serverUrl ?? WebSocketConfig.defaultServerUrl;
      _patientCode = _patientCode ?? WebSocketUtils.generatePatientCode();
      print('[TestController-WS] Server: $_serverUrl, Patient: $_patientCode');
    }

    // Initialize base controller and detection services
    await super.initialize();

    // Connect and initialize WebSocket session
    if (_avmedWebSocketService != null) {
      try {
        print('[TestController-WS] Connecting to WebSocket server: $_serverUrl');
        
        final success = await _avmedWebSocketService!.connectAndInitialize(
          serverUrl: _serverUrl!,
          patientCode: _patientCode!,
          shouldRecord: _shouldRecord,
          frameWidth: 1280,
          frameHeight: 720,
          framesPerSecond: 30,
        );

        if (success) {
          print('[TestController-WS] WebSocket connection established');
        } else {
          print('[TestController-WS] Initial connection failed, will retry in background');
          // Don't throw an exception - let the reconnection logic handle it
        }
      } catch (e) {
        print('[TestController-WS] Error during WebSocket connection: $e');
        print('[TestController-WS] Continuing with background reconnection...');
        // Don't rethrow - allow the app to continue and let reconnection handle it
      }
    }
  }

  /// Get WebSocket connection information
  Map<String, dynamic> getWebSocketInfo() {
    if (_avmedWebSocketService != null) {
      return _avmedWebSocketService!.getConnectionInfo();
    }
    return {
      'error': 'WebSocket service not initialized',
      'configured': {
        'serverUrl': _serverUrl,
        'patientCode': _patientCode,
        'shouldRecord': _shouldRecord,
      }
    };
  }

  /// End WebSocket session (stop recording if enabled)
  Future<void> endWebSocketSession() async {
    if (_avmedWebSocketService != null) {
      await _avmedWebSocketService!.endSession();
      print('[TestController-WS] WebSocket session ended');
    }
  }

  @override
  void dispose() {
    print('[TestController-WS] Disposing AVMED WebSocket test controller...');
    
    // End WebSocket session
    if (_avmedWebSocketService != null) {
      _avmedWebSocketService!.endSession().catchError((e) {
        print('[TestController-WS] Error ending session during dispose: $e');
      });
    }
    
    super.dispose();
    print('[TestController-WS] AVMED WebSocket test controller disposed');
  }
}