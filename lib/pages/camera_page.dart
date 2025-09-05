import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../controllers/test_controller.dart';
import '../controllers/camera_feed_controller.dart';
import '../services/detection_service.dart';
import '../config/model_config.dart';
import 'landing_page.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';

class CameraPage extends StatefulWidget {
  final String patientCode;
  final bool isTrial;

  const CameraPage({
    super.key, 
    required this.patientCode,
    this.isTrial = false,
  });

  @override
  CameraPageState createState() => CameraPageState();
}

class CameraPageState extends State<CameraPage> with TickerProviderStateMixin {
  // Camera controller
  final CameraFeedController _cameraFeedController = Get.put(CameraFeedController());
  
  // Test controller
  late TestController _testController;
  
  // Detection service
  late DetectionService _detectionService;
  
  // Animation controllers for flashing effects
  late AnimationController _flashController;
  Color _currentFlashColor = Colors.transparent;
  
  // Video player controllers
  VideoPlayerController? _videoController;
  String _currentVideoPath = '';
  bool _isVideoInitialized = false;
  bool _isDisposingVideo = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupDetectionService();
    _setupTestController();
  }

  void _setupAnimations() {
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  void _setupDetectionService() async {
    _detectionService = DetectionService();
    try {
      await _detectionService.initialize(modelType: ModelType.yolov5s);
      print('Detection service initialized with ${_detectionService.modelInfo?.name}');
    } catch (e) {
      print('Failed to initialize detection service: $e');
    }
  }

  void _setupTestController() {
    _testController = TestController(
      isTrial: widget.isTrial,
      onTestUpdate: () {
        setState(() {});
        _updateInstructionVideo();
      },
      onTestComplete: _showCompletionDialog,
      onStepComplete: (isSuccess) {
        if (isSuccess) {
          _flashGreen();
        } else {
          _flashRed();
        }
      },
    );
    _updateInstructionVideo();
  }

  String _getVideoPathForStep(TestStep step) {
    // Use the video path directly from the test step
    return step.videoPath ?? 'assets/instructions/holding-pill.mp4';
  }

  Future<void> _initializeVideo(String videoPath) async {
    if (_currentVideoPath == videoPath) return;
    if (videoPath.isEmpty) return;
    if (_isDisposingVideo) return;
    
    // Dispose existing controller safely
    if (_videoController != null && !_isDisposingVideo) {
      _isDisposingVideo = true;
      try {
        await _videoController!.dispose();
      } catch (e) {
        print('Error disposing video controller: $e');
      }
      _videoController = null;
      _isDisposingVideo = false;
    }
    
    try {
      _videoController = VideoPlayerController.asset(videoPath);
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.play();
      
      if (mounted) {
        setState(() {
          _currentVideoPath = videoPath;
          _isVideoInitialized = true;
        });
      }
      print('Video initialized successfully');
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
        });
      }
    }
  }

  void _updateInstructionVideo() {
    if (_testController.testSteps.isEmpty) return;
    
    final activeStep = _testController.isTestRunning 
        ? _testController.testSteps.firstWhere(
            (step) => step.isActive,
            orElse: () => _testController.testSteps.first,
          )
        : _testController.testSteps.first;
    
    final videoPath = _getVideoPathForStep(activeStep);
    if (videoPath.isNotEmpty) {
      _initializeVideo(videoPath);
    }
  }

  // To be replaced with Azure/AWS endpoint
  void _simulateDetectionResult(String detectedLabel, double confidence) {
    if (_testController.isTestRunning) {
      final activeStep = _testController.testSteps.firstWhere(
        (step) => step.isActive,
        orElse: () => _testController.testSteps.first,
      );
      
      _testController.processDetectionResult(
        detectedLabel: detectedLabel,
        confidence: confidence,
        currentStep: activeStep,
      );
    }
  }

  void _resetTest() {
    _testController.resetTest();
    setState(() {
      _currentFlashColor = Colors.transparent;
    });
  }

  void _switchModel() async {
    try {
      // Get current model type
      ModelType currentType = _detectionService.currentModelType == ModelType.yolov5s 
          ? ModelType.mock 
          : ModelType.yolov5s;
      
      ModelType newType = currentType == ModelType.yolov5s 
          ? ModelType.mock 
          : ModelType.yolov5s;
      
      // Switch the model
      await _detectionService.setModel(newType);
      
      // Show feedback to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${_detectionService.modelInfo?.name ?? 'Unknown'} model'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Model switch completed'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error switching model: $e');
    }
  }

  void _startTest() {
    _testController.startTest();
    _updateInstructionVideo();
  }

  void _confirmEndTest() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Compliance Test Incomplete',
            style: TextStyle(
              color: Color(0xFFA855F7), // Purple
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'You have yet to complete the compliance test key steps. Do you want to end the test now?',
            style: TextStyle(
              color: Color(0xFF1F2937), // Dark gray
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF6B7280), // Gray
                backgroundColor: Color(0xFF6B7280).withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _testController.endTest();
                // Navigate to landing page after ending incomplete test
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => LandingPage()),
                  (route) => false, // Remove all previous routes
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                backgroundColor: Colors.red.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'End test',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Test completed',
            style: TextStyle(
              color: Colors.green[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Good job on completing all the steps! You may end the session now or take another pill.',
            style: TextStyle(
              color: Color(0xFF1F2937), // Dark gray
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => LandingPage()),
                  (route) => false, // Remove all previous routes
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF6B7280), // Gray
                backgroundColor: Color(0xFF6B7280).withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'End session',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _resetTest(); // Reset and start new test
              },
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFFA855F7), // Purple
                backgroundColor: Color(0xFFA855F7).withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Take another pill',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _flashGreen() {
    setState(() {
      _currentFlashColor = Colors.green.withValues(alpha: 0.3);
    });
    _flashController.forward().then((_) {
      _flashController.reverse().then((_) {
        setState(() {
          _currentFlashColor = Colors.transparent;
        });
      });
    });
  }

  void _flashRed() {
    setState(() {
      _currentFlashColor = Colors.red.withValues(alpha: 0.3);
    });
    _flashController.forward().then((_) {
      _flashController.reverse().then((_) {
        setState(() {
          _currentFlashColor = Colors.transparent;
        });
      });
    });
  }

  Widget _buildFullScreenCamera() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          // Full-screen camera preview
          CameraFeedView(),
          // Positioned.fill(
          //   child: Container(
          //     color: Colors.black,
          //     child: Center(
          //       child: Column(
          //         mainAxisAlignment: MainAxisAlignment.center,
          //         children: [
          //           Icon(
          //             _cameraFeedController.isFrontCamera ? Icons.camera_front : Icons.camera_rear,
          //             size: 80,
          //             color: Colors.white.withValues(alpha: 0.7),
          //           ),
          //           const SizedBox(height: 16),
          //           Text(
          //             '${_cameraFeedController.isFrontCamera ? 'Front' : 'Rear'} Camera Feed',
          //             style: const TextStyle(
          //               color: Colors.white,
          //               fontSize: 18,
          //               fontWeight: FontWeight.w500,
          //             ),
          //           ),
          //           const SizedBox(height: 8),
          //           Text(
          //             'Patient: ${widget.patientCode}',
          //             style: const TextStyle(
          //               color: Colors.grey,
          //               fontSize: 14,
          //             ),
          //           ),
          //         ],
          //       ),
          //     ),
          //   ),
          // ),
          // Flash overlay
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: double.infinity,
            height: double.infinity,
            color: _currentFlashColor,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoInstructionsWindow() {
    final activeStep = _testController.isTestRunning 
        ? _testController.testSteps.firstWhere(
            (step) => step.isActive,
            orElse: () => _testController.testSteps.first,
          )
        : _testController.testSteps.first;

    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Video player
            if (_isVideoInitialized && _videoController != null)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              )
            else
              // Fallback when video is loading
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Color(0xFF1F2937),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Subtitle overlay
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  activeStep.label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            
            // Active step indicator
            if (_testController.isTestRunning && activeStep.isActive)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            
            // Video controls overlay (play/pause)
            if (_isVideoInitialized && _videoController != null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_videoController!.value.isPlaying) {
                        _videoController!.pause();
                      } else {
                        _videoController!.play();
                      }
                    });
                  },
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _videoController!.value.isPlaying ? 0.0 : 0.8,
                        duration: Duration(milliseconds: 300),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingControls() {
    return Column(
      children: [
        // Camera switch button
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: _cameraFeedController.switchCamera,
            icon: const Icon(
              Icons.cameraswitch,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Model switch button
        Container(
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: _switchModel,
            icon: const Icon(
              Icons.swap_horiz,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Debug detection button (for testing)
        if (_testController.isTestRunning)
          Container(
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () {
                final activeStep = _testController.testSteps.firstWhere(
                  (step) => step.isActive,
                  orElse: () => _testController.testSteps.first,
                );
                _simulateDetectionResult(activeStep.targetLabel, 0.8);
              },
              icon: const Icon(
                Icons.visibility,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton() {
    if (!_testController.hasTestStarted) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _startTest,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFFA855F7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
          child: const Text(
            'Start Test',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else if (!_testController.isCompleted) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.red[500],
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _confirmEndTest,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[500],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
          child: const Text(
            'End Test',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.green[500],
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _showCompletionDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[500],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
          child: const Text(
            'Test Complete',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Real Time Detection'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Full-screen camera feed
          _buildFullScreenCamera(),
          
          // Trial banner (top overlay)
          if (widget.isTrial)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.5), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info, color: Color(0xFF0EA5E9), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Trial Mode - No data will be saved',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Video instructions window (top-right corner, FaceTime style)
          Positioned(
            top: widget.isTrial ? 140 : MediaQuery.of(context).padding.top + 80,
            right: 16,
            child: _buildVideoInstructionsWindow(),
          ),
          
          // Floating controls (right side)
          Positioned(
            top: widget.isTrial ? 310 : MediaQuery.of(context).padding.top + 250,
            right: 16,
            child: _buildFloatingControls(),
          ),
          
          // Action button (bottom center)
          Positioned(
            bottom: 40,
            left: 16,
            right: 16,
            child: _buildActionButton(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _flashController.dispose();
    _detectionService.dispose();
    if (_videoController != null && !_isDisposingVideo) {
      _isDisposingVideo = true;
      try {
        _videoController!.dispose();
      } catch (e) {
        print('Error disposing video controller: $e');
      }
    }
    super.dispose();
  }
}
