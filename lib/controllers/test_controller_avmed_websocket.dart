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
      'avmed': _avmedWebSocketService!,
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
        targetTimeSeconds: 3.0,
        maxTime: 10.0,
        confidenceThreshold: 0.7,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Put pill on tongue',
        targetLabel: StepConstants.pillOnTongue,
        videoPath: 'assets/instructions/pill-on-tongue.mp4',
        targetTimeSeconds: 2.0,
        maxTime: 10.0,
        confidenceThreshold: 0.7,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Show no pill on tongue',
        targetLabel: StepConstants.noPillOnTongue,
        videoPath: 'assets/instructions/no-pill-on-tongue.mp4',
        targetTimeSeconds: 2.0,
        maxTime: 10.0,
        confidenceThreshold: 0.7,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Drink water',
        targetLabel: StepConstants.drinkWater,
        videoPath: 'assets/instructions/drink-water.mp4',
        targetTimeSeconds: 3.0,
        maxTime: 15.0,
        confidenceThreshold: 0.65,
        frameProcessingIntervalMs: intervalMs,
      ),
      TestStep(
        label: 'Show no pill under tongue',
        targetLabel: StepConstants.noPillUnderTongue,
        videoPath: 'assets/instructions/no-pill-under-tongue.mp4',
        targetTimeSeconds: 2.0,
        maxTime: 10.0,
        confidenceThreshold: 0.7,
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

  /// Override the test-step processing to use AVMED WebSocket detection outputs
  @override
  Future<void> processTestStep() async {
    final step = currentStep;
    if (step == null) return;
    if (!step.isActive) return;

    // Get AVMED WebSocket detections
    final detections = getDetections('avmed');

    final targetLabel = (step.targetLabel ?? '').toLowerCase();
    final threshold = step.confidenceThreshold;

    bool found = false;
    if (_avmedWebSocketService != null) {
      switch (targetLabel) {
        case 'pill':
          found = _avmedWebSocketService!.detectPill(threshold);
          break;
        case 'pill on tongue':
          found = _avmedWebSocketService!.detectPillOnTongue(threshold);
          break;
        case 'no pill on tongue':
          found = _avmedWebSocketService!.detectNoPillOnTongue(threshold);
          break;
        case 'drink water':
          found = _avmedWebSocketService!.detectDrinkingAction(threshold);
          break;
        case 'no pill under tongue':
          found = _avmedWebSocketService!.detectNoPillUnderTongue(threshold);
          break;
        default:
          found = _detectGenericTarget(detections, targetLabel, threshold);
      }
    } else {
      // Fallback to generic detection if WebSocket service not available
      found = _detectGenericTarget(detections, targetLabel, threshold);
    }

    // Use the base helper to update counters / advance steps
    processStepDetectionResult(step, found);
  }

  // --- Fallback detection helper ---
  bool _detectGenericTarget(List<DetectionResult> detections, String targetLabel, double threshold) {
    for (final detection in detections) {
      if (detection.label.toLowerCase() == targetLabel &&
          detection.confidence >= threshold) {
        return true;
      }
    }
    return false;
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

  /// Get AVMED test results with WebSocket information
  Map<String, dynamic> getAVMedTestResults() {
    final results = <String, dynamic>{
      'test_type': 'AVMED Medication Adherence (WebSocket)',
      'total_steps': testSteps.length,
      'successful_steps': testSteps.where((s) => s.isSuccess).length,
      'step_details': <Map<String, dynamic>>[],
      'websocket_info': getWebSocketInfo(),
      'detection_method': 'WebSocket',
    };

    for (var i = 0; i < testSteps.length; i++) {
      final step = testSteps[i];
      results['step_details'].add({
        'step_number': i + 1,
        'label': step.label,
        'target_label': step.targetLabel,
        'is_completed': step.startTime != null && !step.isActive,
        'is_successful': step.isSuccess,
        'detected_frames': step.detectionsCount,
        'target_frames': step.detectionsRequired,
        'confidence_threshold': step.confidenceThreshold,
      });
    }

    final successful = results['successful_steps'] as int;
    final total = results['total_steps'] as int;
    results['success_percentage'] = total > 0 ? (successful / total * 100).round() : 0;
    results['overall_success'] = successful == total;
    
    return results;
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