import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../controllers/camera_feed_controller.dart';
import '../services/isolate_detection_service.dart';
import '../services/base_detection_service.dart';
import '../utils/camera_image_utils.dart';
import '../types/detection_types.dart';

class CameraTestPage extends StatefulWidget {
  const CameraTestPage({super.key});

  @override
  State<CameraTestPage> createState() => _CameraTestPageState();
}

class _CameraTestPageState extends State<CameraTestPage> {
  // Camera controller
  final CameraFeedController _cameraController = Get.put(CameraFeedController());
  
  // Detection services (isolate-based only)
  IsolateYOLOv5DetectionService? _isolateYolov5Service;
  IsolateAVMedDetectionService? _isolateAvmedService;
  BaseDetectionService? _currentDetectionService;
  bool _useAVMedModel = false; // Start with YOLOv5 by default
  bool _isDetectionServiceReady = false;
  
  // Detection testing variables
  bool _isDetectionRunning = false;
  bool _isProcessing = false;
  Timer? _detectionTimer;
  List<DetectionResult> _lastDetections = [];
  int _processedFrames = 0;
  int _detectionInterval = 500; // Fixed interval in ms (no longer adaptive)

  @override
  void initState() {
    super.initState();
    
    _setupDetectionService();
  }

  void _setupDetectionService() async {
    try {
      print('Initializing isolate-based detection services...');
      
      // Initialize isolate-based services
      _isolateYolov5Service = IsolateYOLOv5DetectionService();
      _isolateAvmedService = IsolateAVMedDetectionService();
      
      bool yolov5Success = false;
      bool avmedSuccess = false;
      
      try {
        await _isolateYolov5Service?.initialize();
        print('Isolate YOLOv5 service initialized');
        yolov5Success = true;
      } catch (e) {
        print('Failed to initialize isolate YOLOv5 service: $e');
      }
      
      try {
        await _isolateAvmedService?.initialize();
        print('Isolate AVMED service initialized');
        avmedSuccess = true;
      } catch (e) {
        print('Failed to initialize isolate AVMED service: $e');
      }
      
      if (yolov5Success || avmedSuccess) {
        // Set current service based on model selection and availability
        if (_useAVMedModel && avmedSuccess) {
          _currentDetectionService = _isolateAvmedService;
        } else if (!_useAVMedModel && yolov5Success) {
          _currentDetectionService = _isolateYolov5Service;
        } else if (yolov5Success) {
          // Fallback to YOLOv5 if AVMED requested but failed
          _currentDetectionService = _isolateYolov5Service;
          _useAVMedModel = false;
        } else if (avmedSuccess) {
          // Fallback to AVMED if YOLOv5 requested but failed
          _currentDetectionService = _isolateAvmedService;
          _useAVMedModel = true;
        }
      }
      
      setState(() {
        _isDetectionServiceReady = _currentDetectionService?.isInitialized ?? false;
      });
      
      print('Detection service setup complete. Ready: $_isDetectionServiceReady, YOLOv5: $yolov5Success, AVMED: $avmedSuccess');
    } catch (e) {
      _showMessage('Failed to initialize detection models. Please try restarting the page.');
      
      // Ensure partial services are cleaned up
      try {
        _isolateYolov5Service?.dispose();
        _isolateAvmedService?.dispose();
      } catch (_) {}
    }
  }

  /// Toggle between AVMED and YOLOv5 models
  void _toggleDetectionModel() {
    if (!_isDetectionServiceReady) {
      _showMessage('Detection services not ready yet');
      return;
    }

    // Stop detection if running
    bool wasRunning = _isDetectionRunning;
    if (wasRunning) {
      _stopDetectionTesting();
    }

    setState(() {
      _useAVMedModel = !_useAVMedModel;
      
      // Switch to appropriate isolate service
      if (_useAVMedModel && _isolateAvmedService?.isInitialized == true) {
        _currentDetectionService = _isolateAvmedService;
      } else if (!_useAVMedModel && _isolateYolov5Service?.isInitialized == true) {
        _currentDetectionService = _isolateYolov5Service;
      }
      
      // Reset statistics when switching models
      _processedFrames = 0;
      _lastDetections.clear();
    });

    _showMessage('Switched to ${_getCurrentModelName()} model');

    // Restart detection if it was running
    if (wasRunning) {
      _startDetectionTesting();
    }
  }

  /// Get current model name for display
  String _getCurrentModelName() {
    return _useAVMedModel ? 'AVMED' : 'YOLOv5';
  }

  /// Start object detection testing
  void _startDetectionTesting() {
    if (!_isDetectionServiceReady) {
      _showMessage('Detection service not ready yet');
      return;
    }

    if (_isDetectionRunning) {
      return;
    }

    setState(() {
      _isDetectionRunning = true;
      _processedFrames = 0;
    });

    _startDetectionTimer();
  }

  /// Start or restart the detection timer with current interval
  void _startDetectionTimer() {
    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(Duration(milliseconds: _detectionInterval), (timer) {
      if (!_isProcessing) {
        _processCurrentCameraImage();
      }
    });
  }

  /// Stop object detection testing
  void _stopDetectionTesting() {
    if (_detectionTimer != null) {
      _detectionTimer!.cancel();
      _detectionTimer = null;
    }
    
    setState(() {
      _isDetectionRunning = false;
    });

  }

  /// Process current camera image for object detection
  Future<void> _processCurrentCameraImage() async {
    if (_isProcessing) return;
    _isProcessing = true;
    
    final currentImage = _cameraController.currentImage;
    
    if (currentImage == null) {
      print('No camera image available');
      _isProcessing = false;
      return;
    }

    try {
      // Convert camera image to bytes for ML processing (measure timing)
      final conversionStart = DateTime.now();
      final imageBytes = CameraImageUtils.convertCameraImageToBytes(currentImage, isFrontCamera: _cameraController.isFrontCamera);
      final conversionTime = DateTime.now().difference(conversionStart).inMilliseconds;
      if (conversionTime > 10) {
        print('Image conversion took ${conversionTime}ms (main thread)');
      }
      
      if (imageBytes.isEmpty) {
        print('Failed to convert camera image to bytes');
        _isProcessing = false;
        return;
      }

      // Run object detection
      final results = await _currentDetectionService?.processFrame(
        imageBytes,
        currentImage.height,
        currentImage.width,
      ) ?? [];

      setState(() {
        _lastDetections = results;
        _processedFrames++;
      });

      // Print detection results to console
      if (results.isNotEmpty) {
        print('  Detected ${results.length} objects:');
        for (final result in results) {
          print('    ${result.label}: ${(result.confidence * 100).toStringAsFixed(1)}%');
        }
      } else {
        print('  No objects detected');
      }

    } catch (e) {
      print('Error processing camera image: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    // Stop any running detection
    _stopDetectionTesting();
    
    // Safely dispose of all detection services
    try {
      _isolateYolov5Service?.dispose();
      _isolateAvmedService?.dispose();
    } 
    catch (e) {
      print("Error disposing detection services: $e");
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Camera Test'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Full-screen display (camera preview or ML input)
          Positioned.fill(
            child: _buildDisplayView(),
          ),
          
          // Enhanced overlay with camera and detection info
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Obx(() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Camera status
                  Row(
                    children: [
                      Icon(
                        _cameraController.isInitialized.value 
                          ? Icons.camera_alt 
                          : Icons.camera_alt_outlined,
                        color: _cameraController.isInitialized.value 
                          ? Colors.green 
                          : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Camera: ${_cameraController.isInitialized.value ? "Ready" : "Loading..."}',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Detection service status
                  Row(
                    children: [
                      Icon(
                        _isDetectionServiceReady ? Icons.check_circle : Icons.error,
                        color: _isDetectionServiceReady ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Detection: ${_isDetectionServiceReady ? "Ready" : "Loading..."}',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Detection running status
                  Row(
                    children: [
                      Icon(
                        _isDetectionRunning ? Icons.play_circle : Icons.pause_circle,
                        color: _isDetectionRunning ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Status: ${_isDetectionRunning ? "Running" : "Stopped"}',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  
                  if (_isDetectionRunning) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Processed: $_processedFrames frames',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      'Interval: ${_detectionInterval}ms (fixed)',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                  
                  // Camera details
                  const SizedBox(height: 8),
                  Text(
                    'Camera Type: ${_cameraController.isFrontCamera ? "Front" : "Back"}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (_cameraController.currentImage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Image Size: ${_cameraController.currentImage!.width}x${_cameraController.currentImage!.height}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ],
              )),
            ),
          ),
          
          // Detection results overlay
          Positioned(
            bottom: 200,
            left: 20,
            right: 20,
            child: _buildDetectionResults(),
          ),
          
          // Control buttons
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: _buildControlButtons(),
          ),
          
          // Camera switch button
          Positioned(
            top: 200,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _cameraController.switchCamera,
                icon: const Icon(
                  Icons.cameraswitch,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          
          // Model toggle button (AVMED/YOLOv5)
          Positioned(
            top: 260,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: _useAVMedModel 
                  ? Colors.purple.withValues(alpha: 0.8)
                  : Colors.blue.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: MaterialButton(
                onPressed: _toggleDetectionModel,
                minWidth: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _useAVMedModel ? Icons.science : Icons.visibility,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getCurrentModelName(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Inference timing widget
          Positioned(
            top: 320,
            right: 20,
            child: _buildTimingWidget(),
          ),
          
        ],
      ),
    );
  }

  Widget _buildDisplayView() {
    // Always show camera preview
    return CameraFeedView();
  }

  Widget _buildDetectionResults() {
    if (_lastDetections.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No detections',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detected Objects (${_lastDetections.length}):',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...(_lastDetections.take(5).map((detection) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  detection.label,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  '${(detection.confidence * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: detection.confidence > 0.7 ? Colors.green : Colors.orange,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )).toList()),
          if (_lastDetections.length > 5)
            Text(
              '... and ${_lastDetections.length - 5} more',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      children: [
        // Start/Stop Detection Button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isDetectionServiceReady 
              ? (_isDetectionRunning ? _stopDetectionTesting : _startDetectionTesting)
              : null,
            icon: Icon(_isDetectionRunning ? Icons.stop : Icons.play_arrow),
            label: Text(_isDetectionRunning ? 'Stop Detection' : 'Start Detection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isDetectionRunning ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  /// Build a simple frame counter widget instead of complex timing
  Widget _buildTimingWidget() {
    // Only show if we have processed frames
    if (_processedFrames == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white30, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.analytics,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Detection Stats (${_getCurrentModelName()})',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          Text(
            'Frames: $_processedFrames',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
          
          Text(
            'Interval: ${_detectionInterval}ms',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
          
          if (_lastDetections.isNotEmpty) ...[
            Text(
              'Objects: ${_lastDetections.length}',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

}
