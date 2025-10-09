import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../config/model_config.dart';
import '../services/isolate_detection_service.dart';
import '../services/mlkit_pose_detection_service.dart';
import '../controllers/camera_feed_controller.dart';
import '../services/base_detection_service.dart';
import '../utils/camera_image_utils.dart';
import '../types/detection_types.dart';
import '../widgets/pose_mlkit_painter.dart';
import '../widgets/detection_box_painter.dart';

enum DetectionModel { yolov5, avmed, poseDetection }

class CameraTestPage extends StatefulWidget {
  const CameraTestPage({super.key});

  @override
  State<CameraTestPage> createState() => _CameraTestPageState();
}

class _CameraTestPageState extends State<CameraTestPage> {
  // Camera controller
  final CameraFeedController _cameraController = Get.put(CameraFeedController());

  // Detection services stored in a map by key
  final Map<String, BaseDetectionService?> _detectionServicesMap = {};
  String _currentModelKey = 'yolov5'; // default key
  bool _isDetectionServiceReady = false;

  // Detection testing variables
  bool _isDetectionRunning = false;
  bool _isProcessing = false;
  Timer? _detectionTimer;
  List<DetectionResult> _lastDetections = [];
  int _detectionInterval = 500; // Fixed interval in ms (no longer adaptive)

  @override
  void initState() {
    super.initState();

    _setupDetectionService();
  }

  void _setupDetectionService() async {
    try {
      print('Initializing detection services...');
      // Initialize services map
      _detectionServicesMap['yolov5'] = IsolateDetectionService(ModelType.yolov5s);
      _detectionServicesMap['avmed'] = IsolateDetectionService(ModelType.avmed);
      _detectionServicesMap['face'] = IsolateDetectionService(ModelType.face_detection);
      _detectionServicesMap['pose'] = MLKitPoseDetectionService();

      final results = <String, bool>{};

      // Initialize each service and record success
      for (final entry in _detectionServicesMap.entries) {
        final key = entry.key;
        final service = entry.value;
        if (service == null) {
          results[key] = false;
          continue;
        }

        try {
          await service.initialize();
          results[key] = true;
          print('Initialized service: $key');
        } catch (e) {
          results[key] = false;
          print('Failed to initialize $key: $e');
        }
      }

      print('Service initialization results:');
      results.forEach((k, v) => print('  $k: ${v ? "✅" : "❌"}'));

      // Set initial current model key if the corresponding service is ready
      if (results[_currentModelKey] != true) {
        final firstReady = results.entries.firstWhere((e) => e.value, orElse: () => const MapEntry('', false));
        if (firstReady.key.isNotEmpty) {
          _currentModelKey = firstReady.key;
        }
      }

      setState(() {
        _isDetectionServiceReady = _detectionServicesMap[_currentModelKey]?.isInitialized ?? false;
      });

      print('Detection service setup complete. Ready: $_isDetectionServiceReady');
    } catch (e) {
      _showMessage(
          'Failed to initialize detection models. Please try restarting the page.');

      // Ensure partial services are cleaned up
      try {
        for (final s in _detectionServicesMap.values) {
          s?.dispose();
        }
      } catch (_) {}
    }
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
    });

    _startDetectionTimer();
  }

  /// Start or restart the detection timer with current interval
  void _startDetectionTimer() {
    _detectionTimer?.cancel();
    _detectionTimer =
        Timer.periodic(Duration(milliseconds: _detectionInterval), (timer) {
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
      // Convert camera image to bytes for ML processing
      final imageBytes = CameraImageUtils.convertCameraImageToBytes(
          currentImage,
          isFrontCamera: _cameraController.isFrontCamera);

      if (imageBytes.isEmpty) {
        print('Failed to convert camera image to bytes');
        _isProcessing = false;
        return;
      }

      // Run the currently selected service from the map
      final service = _detectionServicesMap[_currentModelKey];
      final results = await service?.processFrame(
            imageBytes,
            currentImage.height,
            currentImage.width,
          ) ??
          [];

      setState(() {
        _lastDetections = results;
      });
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
      for (final s in _detectionServicesMap.values) {
        s?.dispose();
      }
    } catch (e) {
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
                      // Detection running status
                      Row(
                        children: [
                          Icon(
                            _isDetectionRunning
                                ? Icons.play_circle
                                : Icons.pause_circle,
                            color: _isDetectionRunning
                                ? Colors.green
                                : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Status: ${_isDetectionRunning ? "Running" : "Stopped"}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),

                      // Camera details
                      const SizedBox(height: 8),
                      Text(
                        'Camera Type: ${_cameraController.isFrontCamera ? "Front" : "Back"}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                      if (_cameraController.currentImage != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Image Size: ${_cameraController.currentImage!.width}x${_cameraController.currentImage!.height}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Dropdown to choose active model
                      Row(
                        children: [
                          const Text('Model:', style: TextStyle(color: Colors.white70)),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            dropdownColor: Colors.black,
                            value: _currentModelKey,
                            items: _detectionServicesMap.keys.map((k) {
                              return DropdownMenuItem<String>(
                                value: k,
                                child: Text(k, style: const TextStyle(color: Colors.white)),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _currentModelKey = v;
                                _lastDetections.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  )),
            ),
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

          
        ],
      ),
    );
  }

  Widget _buildDisplayView() {
    // Always show camera preview
    return Stack(
      children: [
        Positioned.fill(child: CameraFeedView()),
        
        // Debug: Show processed image
        Positioned(
          top: 100,
          right: 10,
          child: _buildProcessedImageDebugView(),
        ),
        // If current model is poseDetection and we have detections, overlay MLKit painter
        if (_currentModelKey == 'pose')
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: MLKitPainter(
                  landmarks: _lastDetections,
                  showLabels: false,
                  minConfidence: 0.3,
                ),
              ),
            ),
          ),

        // For other detection models that output bounding boxes, overlay box painter
        if (_currentModelKey != 'pose' && _lastDetections.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(builder: (context, constraints) {
                // Use the actual camera image dimensions that ML processing uses
                Size imageSize = Size(1, 1);
                try {
                  // Always prefer the actual camera image dimensions used for ML processing
                  if (_cameraController.currentImage != null) {
                    final img = _cameraController.currentImage!;
                    imageSize = Size(img.width.toDouble(), img.height.toDouble());
                  }
                } catch (e) {
                  print('[COORDINATE DEBUG] Error getting image size: $e');
                }

                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: DetectionBoxPainter(
                    detections: _lastDetections,
                    imageSize: imageSize,
                    minConfidence: 0.2,
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }



  Widget _buildControlButtons() {
    return Row(
      children: [
        // Start/Stop Detection Button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isDetectionServiceReady
                ? (_isDetectionRunning
                    ? _stopDetectionTesting
                    : _startDetectionTesting)
                : null,
            icon: Icon(_isDetectionRunning ? Icons.stop : Icons.play_arrow),
            label: Text(
                _isDetectionRunning ? 'Stop Detection' : 'Start Detection'),
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

  /// Debug view to show the actual processed image that the model receives
  Widget _buildProcessedImageDebugView() {
    if (_cameraController.currentImage == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 150,
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.yellow, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: FutureBuilder<Widget?>(
          future: _buildProcessedImageWidget(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return snapshot.data!;
            }
            return Container(
              color: Colors.black26,
              child: const Center(
                child: Text(
                  'Processing...',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Create a widget showing the exact image data sent to the model
  Future<Widget?> _buildProcessedImageWidget() async {
    try {
      final currentImage = _cameraController.currentImage;
      if (currentImage == null) return null;

      // Get the exact same image bytes that are sent to the model
      final imageBytes = CameraImageUtils.convertCameraImageToBytes(
        currentImage,
        isFrontCamera: _cameraController.isFrontCamera,
      );

      if (imageBytes.isEmpty) return null;

      return Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.red.withOpacity(0.3),
            child: const Center(
              child: Text(
                'Image Error',
                style: TextStyle(color: Colors.white, fontSize: 8),
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('Debug image error: $e');
      return null;
    }
  }


}
