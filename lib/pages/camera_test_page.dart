import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../controllers/camera_feed_controller.dart';
import '../services/detection_service.dart';
import '../config/model_config.dart';
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
  
  // Detection service
  late DetectionService _detectionService;
  bool _isDetectionServiceReady = false;
  
  // Detection testing variables
  bool _isDetectionRunning = false;
  Timer? _detectionTimer;
  List<DetectionResult> _lastDetections = [];
  int _processedFrames = 0;
  int _detectionInterval = 1000; // milliseconds
  
  // Processed image display
  Widget? _processedImageWidget;
  
  // Display mode toggle (default to camera preview)
  bool _showProcessedImage = false;

  @override
  void initState() {
    super.initState();
    _setupDetectionService();
  }

  void _setupDetectionService() async {
    _detectionService = DetectionService();
    try {
      await _detectionService.initialize(modelType: ModelType.yolov5s);
      setState(() {
        _isDetectionServiceReady = true;
      });
      print('Detection service initialized with ${_detectionService.modelInfo?.name}');
    } catch (e) {
      print('Failed to initialize detection service: $e');
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
      _processedFrames = 0;
    });

    print('Starting detection testing with ${_detectionInterval}ms interval...');

    _detectionTimer = Timer.periodic(Duration(milliseconds: _detectionInterval), (timer) {
      _processCurrentCameraImage();
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
    
    print('Stopped detection testing. Processed $_processedFrames frames.');
  }

  /// Process current camera image for object detection
  Future<void> _processCurrentCameraImage() async {
    final currentImage = _cameraController.currentImage;
    
    if (currentImage == null) {
      print('No camera image available');
      return;
    }

    try {
      // Generate processed image widget for display
      final processedWidget = CameraImageUtils.convertCameraImageToWidget(currentImage);
      
      // Convert camera image to bytes for ML processing
      final imageBytes = CameraImageUtils.convertCameraImageToBytes(currentImage);
      
      if (imageBytes.isEmpty) {
        print('Failed to convert camera image to bytes');
        return;
      }

      // Run object detection
      final results = await _detectionService.processFrame(
        imageBytes,
        currentImage.height,
        currentImage.width,
      );

      setState(() {
        _lastDetections = results;
        _processedFrames++;
        _processedImageWidget = processedWidget;
      });

      // Print detection results to console
      if (results.isNotEmpty) {
        print('Frame $_processedFrames - Detected ${results.length} objects:');
        for (final result in results) {
          print('  ${result.label}: ${(result.confidence * 100).toStringAsFixed(1)}%');
        }
      } else {
        print('Frame $_processedFrames - No objects detected');
      }

    } catch (e) {
      print('Error processing frame $_processedFrames: $e');
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
    _stopDetectionTesting();
    if (_isDetectionServiceReady) {
      _detectionService.dispose();
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
                      'Interval: ${_detectionInterval}ms',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                  
                  // Camera details
                  const SizedBox(height: 8),
                  Text(
                    'Camera Type: ${_cameraController.isFrontCamera ? "Front" : "Back"}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Display Mode: ${_showProcessedImage ? "ML Input" : "Camera Preview"}',
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
          
          // Display mode toggle button
          Positioned(
            top: 260,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _showProcessedImage = !_showProcessedImage;
                  });
                },
                icon: Icon(
                  _showProcessedImage ? Icons.camera : Icons.image_search,
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
    // Switch between camera preview and processed image based on toggle
    if (_showProcessedImage) {
      // Show processed ML input image
      return _buildProcessedImageView();
    } else {
      // Show raw camera preview (default)
      return CameraFeedView();
    }
  }

  Widget _buildProcessedImageView() {
    // Check if camera is initialized
    return Obx(() {
      if (!_cameraController.isInitialized.value) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Setting up camera...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        );
      }

      // Show processed image if available
      if (_processedImageWidget != null) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          child: _processedImageWidget,
        );
      }

      // Fallback message when no processed image is available yet
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt, size: 48, color: Colors.white70),
            SizedBox(height: 16),
            Text(
              'Start detection to see processed image',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    });
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
        const SizedBox(width: 16),
        // Interval Control
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<int>(
            value: _detectionInterval,
            onChanged: _isDetectionRunning ? null : (value) {
              setState(() {
                _detectionInterval = value!;
              });
            },
            dropdownColor: Colors.black87,
            style: const TextStyle(color: Colors.white),
            underline: Container(),
            items: [5000, 2500, 2000, 1000].map((interval) {
              return DropdownMenuItem<int>(
                value: interval,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('${interval}ms'),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
