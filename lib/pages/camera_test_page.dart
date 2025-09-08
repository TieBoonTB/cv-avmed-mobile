import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../controllers/camera_feed_controller.dart';
import '../services/yolov5_detection_service.dart';
import '../services/avmed_detection_service.dart';
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
  
  // Detection services
  YOLOv5DetectionService? _yolov5Service;
  AVMedDetectionService? _avmedService;
  BaseDetectionService? _currentDetectionService;
  bool _useAVMedModel = false; // Start with YOLOv5 by default
  bool _isDetectionServiceReady = false;
  
  // Detection testing variables
  bool _isDetectionRunning = false;
  Timer? _detectionTimer;
  List<DetectionResult> _lastDetections = [];
  int _processedFrames = 0;
  int _detectionInterval = 1000; // milliseconds
  
  // Timing tracking variables
  int _lastInferenceTimeMs = 0;
  int _averageInferenceTimeMs = 0;
  int _minInferenceTimeMs = 0;
  int _maxInferenceTimeMs = 0;
  List<int> _recentInferenceTimes = [];
  final int _maxRecentTimes = 10; // Keep last 10 inference times for averaging
  
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
    try {
      // Initialize both detection services
      _yolov5Service = YOLOv5DetectionService();
      _avmedService = AVMedDetectionService();
      
      // Initialize YOLOv5 service
      try {
        await _yolov5Service?.initialize();
      } catch (e) {
        rethrow; // Re-throw to trigger outer catch
      }
      
      // Initialize AVMED service
      try {
        await _avmedService?.initialize();
      } catch (e) {
        rethrow; // Re-throw to trigger outer catch
      }
      
      // Set current service based on toggle (default to YOLOv5)
      _currentDetectionService = _useAVMedModel ? _avmedService : _yolov5Service;
      
      setState(() {
        _isDetectionServiceReady = true;
      });
    } catch (e) {
      _showMessage('Failed to initialize detection models. Please try restarting the page.');
      
      // Ensure partial services are cleaned up
      try {
        _yolov5Service?.dispose();
      } catch (_) {}
      try {
        _avmedService?.dispose();
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
      _currentDetectionService = _useAVMedModel ? _avmedService : _yolov5Service;
      
      // Reset statistics when switching models
      _lastInferenceTimeMs = 0;
      _averageInferenceTimeMs = 0;
      _minInferenceTimeMs = 0;
      _maxInferenceTimeMs = 0;
      _recentInferenceTimes.clear();
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
      // Reset timing statistics
      _lastInferenceTimeMs = 0;
      _averageInferenceTimeMs = 0;
      _minInferenceTimeMs = 0;
      _maxInferenceTimeMs = 0;
      _recentInferenceTimes.clear();
    });

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

  }

  /// Process current camera image for object detection
  Future<void> _processCurrentCameraImage() async {
    final currentImage = _cameraController.currentImage;
    
    if (currentImage == null) {
      print('No camera image available');
      return;
    }

    // Start timing the inference
    final stopwatch = Stopwatch()..start();

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
      final results = await _currentDetectionService?.processFrame(
        imageBytes,
        currentImage.height,
        currentImage.width,
      ) ?? [];

      // Stop timing and record the result
      stopwatch.stop();
      final inferenceTimeMs = stopwatch.elapsedMilliseconds;
      
      // Update timing statistics
      _updateTimingStatistics(inferenceTimeMs);

      setState(() {
        _lastDetections = results;
        _processedFrames++;
        _processedImageWidget = processedWidget;
      });

      // Print detection results and timing to console
      if (results.isNotEmpty) {
        print('  Detected ${results.length} objects:');
        for (final result in results) {
          print('    ${result.label}: ${(result.confidence * 100).toStringAsFixed(1)}%');
        }
      } else {
        print('  No objects detected');
      }

    } catch (e) {
      stopwatch.stop();
    }
  }

  /// Update timing statistics for inference performance tracking
  void _updateTimingStatistics(int inferenceTimeMs) {
    _lastInferenceTimeMs = inferenceTimeMs;
    
    // Add to recent times list
    _recentInferenceTimes.add(inferenceTimeMs);
    if (_recentInferenceTimes.length > _maxRecentTimes) {
      _recentInferenceTimes.removeAt(0);
    }
    
    // Calculate average of recent times
    if (_recentInferenceTimes.isNotEmpty) {
      _averageInferenceTimeMs = (_recentInferenceTimes.reduce((a, b) => a + b) / _recentInferenceTimes.length).round();
    }
    
    // Update min and max
    if (_processedFrames == 1) {
      _minInferenceTimeMs = inferenceTimeMs;
      _maxInferenceTimeMs = inferenceTimeMs;
    } else {
      if (inferenceTimeMs < _minInferenceTimeMs) {
        _minInferenceTimeMs = inferenceTimeMs;
      }
      if (inferenceTimeMs > _maxInferenceTimeMs) {
        _maxInferenceTimeMs = inferenceTimeMs;
      }
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
    
    // Safely dispose of both detection services
    try {
      _yolov5Service?.dispose();
      _avmedService?.dispose();
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
          
          // Display mode toggle button
          Positioned(
            top: 320,
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
          
          // Inference timing widget
          Positioned(
            top: 380,
            right: 20,
            child: _buildTimingWidget(),
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
        return SizedBox(
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

  /// Build the inference timing widget
  Widget _buildTimingWidget() {
    // Only show timing widget if we have processed frames
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
                Icons.timer,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Inference Timing (${_getCurrentModelName()})',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Last inference time
          _buildTimingRow(
            'Last:',
            '${_lastInferenceTimeMs}ms',
            _getTimingColor(_lastInferenceTimeMs),
          ),
          
          // Average inference time (if we have multiple samples)
          if (_recentInferenceTimes.length > 1) ...[
            _buildTimingRow(
              'Avg:',
              '${_averageInferenceTimeMs}ms',
              _getTimingColor(_averageInferenceTimeMs),
            ),
            _buildTimingRow(
              'Min/Max:',
              '$_minInferenceTimeMs/$_maxInferenceTimeMs ms',
              Colors.white70,
            ),
          ],
          
          // Estimated FPS based on average
          if (_averageInferenceTimeMs > 0) ...[
            const SizedBox(height: 4),
            _buildTimingRow(
              'Est. FPS:',
              (1000 / _averageInferenceTimeMs).toStringAsFixed(1),
              _getFPSColor((1000 / _averageInferenceTimeMs)),
            ),
          ],
          
          // Frame count
          const SizedBox(height: 4),
          Text(
            'Frames: $_processedFrames',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a timing info row
  Widget _buildTimingRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Get color based on inference timing (green = fast, red = slow)
  Color _getTimingColor(int timeMs) {
    if (timeMs <= 33) {
      return Colors.green; // 30+ FPS capable
    } else if (timeMs <= 66) {
      return Colors.lightGreen; // 15-30 FPS
    } else if (timeMs <= 100) {
      return Colors.yellow; // 10-15 FPS
    } else if (timeMs <= 200) {
      return Colors.orange; // 5-10 FPS
    } else {
      return Colors.red; // <5 FPS
    }
  }

  /// Get color based on FPS (green = high FPS, red = low FPS)
  Color _getFPSColor(double fps) {
    if (fps >= 30) {
      return Colors.green;
    } else if (fps >= 15) {
      return Colors.lightGreen;
    } else if (fps >= 10) {
      return Colors.yellow;
    } else if (fps >= 5) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
