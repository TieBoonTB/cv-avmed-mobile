import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../controllers/base_test_controller.dart';
import '../controllers/camera_feed_controller.dart';
import '../utils/test_controller_factory.dart';
import "../utils/adaptive_interval_calculator.dart";
import 'landing_page.dart';

/// Modern camera page using the new test controller architecture
/// Works with any implementation of BaseTestController
class CameraPage extends StatefulWidget {
  final String patientCode;
  final bool isTrial;
  final String testType; // 'mock' or 'objects' or custom

  const CameraPage({
    super.key,
    required this.patientCode,
    this.isTrial = false,
    this.testType = 'mock',
  });

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with TickerProviderStateMixin {
  // Controllers
  final CameraFeedController _cameraController = Get.put(CameraFeedController());
  BaseTestController? _testController;
  
  // Animation controllers for visual feedback
  late AnimationController _flashController;
  late AnimationController _progressController;
  Color _currentFlashColor = Colors.transparent;
  late AdaptiveIntervalCalculator _intervalCalculator; 
  
  // Video player for instructions
  VideoPlayerController? _videoController;
  String _currentVideoPath = '';
  bool _isVideoInitialized = false;
  
  // Frame processing
  Timer? _frameTimer;
  int _defaultFrameProcessingInterval = 1000;
  int _frameProcessingInterval = 1000; // Start with 200ms, will be adapted
  
  // UI state
  bool _isInitialized = false;
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeComponents();
    _intervalCalculator = AdaptiveIntervalCalculator();
  }

  void _setupAnimations() {
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  Future<void> _initializeComponents() async {
    try {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Initializing camera...';
      });
      
      // Initialize camera
      await _cameraController.initializeCamera();
      
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Setting up test controller...';
      });
      
      // Create appropriate test controller based on type
      _testController = _createTestController(widget.testType);
      await _testController!.initialize();
      
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Starting frame processing...';
      });
      
      // Initialize instruction video
      _updateInstructionVideo();
      
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _statusMessage = 'Ready';
      });
      
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Initialization failed: $e';
      });
      print('Error initializing components: $e');
    }
  }

  BaseTestController _createTestController(String testType) {
    return TestControllerFactory.createController(
      testType: testType,
      isTrial: widget.isTrial,
      onTestUpdate: _onTestUpdate,
      onTestComplete: _onTestComplete,
      onStepComplete: _onStepComplete,
    );
  }

  void _startFrameProcessing() {
    _startFrameTimer();
  }

  void _startFrameTimer() {
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(Duration(milliseconds: _frameProcessingInterval), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _processCurrentFrame();
    });
  }

  void _stopFrameProcessing() {
    _frameTimer?.cancel();
  }

  Future<void> _processCurrentFrame() async {
    if (!mounted || _testController == null || !_testController!.detectionService.isInitialized) {
      return;
    }
    
    final currentImage = _cameraController.currentImage;
    if (currentImage != null) {
      // Start timing the frame processing
      _intervalCalculator.startTiming();
      
      try {
        await _testController!.processCameraFrame(currentImage, isFrontCamera: _cameraController.isFrontCamera);
        
        // Stop timing and check if we should adjust interval
        _intervalCalculator.stopTiming();
        
        final newInterval = _intervalCalculator.calculateNewInterval(_frameProcessingInterval);
        if (newInterval != _frameProcessingInterval) {
          _frameProcessingInterval = newInterval;
          _startFrameTimer(); // Restart with new interval
        }
      } catch (e) {
        // Still stop timing even if there was an error
        _intervalCalculator.stopTiming();
        rethrow;
      }
    }
  }

  void _onTestUpdate() {
    if (!mounted) return; // Add mounted check
    setState(() {});
    _updateInstructionVideo();
    _updateProgress();
  }

  void _onTestComplete() {
    if (!mounted) return; // Add mounted check
    _stopFrameProcessing();
    _showCompletionDialog();
  }

  void _onStepComplete(bool isSuccess) {
    if (!mounted) return; // Add mounted check
    if (isSuccess) {
      _flashGreen();
    } else {
      _flashRed();
    }
  }

  void _updateProgress() {
    final currentStep = _testController?.currentStep;
    if (currentStep != null) {
      _progressController.animateTo(currentStep.progress);
    }
  }

  Future<void> _updateInstructionVideo() async {
    final currentStep = _testController?.currentStep;
    if (currentStep == null || currentStep.videoPath == null) {
      return;
    }
    
    final videoPath = currentStep.videoPath!;
    if (videoPath != _currentVideoPath) {
      await _initializeVideo(videoPath);
    }
  }

  Future<void> _initializeVideo(String videoPath) async {
    if (videoPath.isEmpty || videoPath == _currentVideoPath) return;
    
    try {
      // Dispose existing controller
      await _videoController?.dispose();
      
      // Initialize new video
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
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
        });
      }
    }
  }

  void _flashGreen() {
    _currentFlashColor = Colors.green.withValues(alpha: 0.3);
    _flashController.forward().then((_) {
      _flashController.reverse();
      _currentFlashColor = Colors.transparent;
    });
  }

  void _flashRed() {
    _currentFlashColor = Colors.red.withValues(alpha: 0.3);
    _flashController.forward().then((_) {
      _flashController.reverse();
      _currentFlashColor = Colors.transparent;
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Test Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(_getCompletionMessage()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetTest();
            },
            child: const Text('Run Again'),
          ),
          ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LandingPage(),
                  ),
                );
              },
              child: const Text('Finish'),
            ),
        ],
      ),
    );
  }

  String _getCompletionMessage() {
    final testSteps = _testController?.testSteps ?? [];
    final successfulSteps = testSteps.where((step) => step.isSuccess).length;
    final totalSteps = testSteps.length;
    
    return 'Completed $successfulSteps out of $totalSteps steps successfully.';
  }

  void _resetTest() {
    _testController?.resetTest();
    _updateInstructionVideo();
  }

  void _startTest() {
    if (_testController != null && _isInitialized) {
      _testController!.startTest();
    }
    
    // Reset adaptive interval calculator for new test session
    _intervalCalculator.reset();
    _frameProcessingInterval = _defaultFrameProcessingInterval; // Reset to starting interval
    
    _startFrameProcessing();
  }

  void _forceStop() {
    _testController?.forceStopTest();
    _stopFrameProcessing();
  }

  @override
  void dispose() {
    // Stop frame processing first to prevent any ongoing operations
    _stopFrameProcessing();
    
    // Dispose animation controllers
    _flashController.dispose();
    _progressController.dispose();
    
    // Dispose video controller
    _videoController?.dispose();
    
    // Dispose test controller (this should also stop any ongoing detection)
    _testController?.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera feed
          _buildCameraFeed(),
          
          // Flash overlay
          AnimatedBuilder(
            animation: _flashController,
            builder: (context, child) => Container(
              color: _currentFlashColor.withValues(alpha: _flashController.value),
            ),
          ),
          
          // UI overlay
          _buildUIOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraFeed() {
    return Positioned.fill(
      child: Obx(() {
        if (_cameraController.isInitialized.value) {
          return FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _cameraController.cameraController!.value.previewSize!.height,
              height: _cameraController.cameraController!.value.previewSize!.width,
              child: _cameraController.cameraController!.buildPreview(),
            ),
          );
        } else {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
      }),
    );
  }

  Widget _buildUIOverlay() {
    return SafeArea(
      child: Column(
        children: [
          // Top bar
          _buildTopBar(),
          
          // Middle spacer
          const Expanded(child: SizedBox()),
          
          // Instruction video
          _buildInstructionVideo(),
          
          // Bottom controls
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          
          // Title and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTestTitle(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getStatusText(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Camera switch button
          IconButton(
            onPressed: _cameraController.switchCamera,
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
          ),
        ],
      ),
    );
  }

  String _getTestTitle() {
    return TestControllerFactory.getTestDisplayName(widget.testType);
  }

  String _getStatusText() {
    if (_testController == null) return 'Initializing...';
    
    final testSteps = _testController!.testSteps;
    final currentStepIndex = _testController!.currentStepIndex;
    
    if (!_testController!.hasTestStarted) {
      return 'Ready to start';
    } else if (_testController!.isCompleted) {
      return 'Test completed';
    } else if (currentStepIndex < testSteps.length) {
      return 'Step ${currentStepIndex + 1}/${testSteps.length}: ${testSteps[currentStepIndex].label}';
    }
    
    return 'In progress';
  }

  Widget _buildInstructionVideo() {
    if (!_isVideoInitialized || _videoController == null) {
      return const SizedBox();
    }
    
    return Container(
      margin: const EdgeInsets.all(16),
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress indicator
          if (_testController?.currentStep != null)
            _buildProgressIndicator(),
          
          const SizedBox(height: 16),
          
          // Detection info
          _buildDetectionInfo(),
          
          const SizedBox(height: 16),
          
          // Control buttons
          _buildControlButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final currentStep = _testController!.currentStep!;
    
    return Column(
      children: [
        Text(
          currentStep.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _progressController,
          builder: (context, child) => LinearProgressIndicator(
            value: _progressController.value,
            backgroundColor: Colors.white30,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(currentStep.progress * 100).toStringAsFixed(0)}% complete',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDetectionInfo() {
    if (_testController == null) return const SizedBox();
    
    final detections = _testController!.detectionService.lastDetections;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Latest Detections:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          if (detections.isEmpty)
            const Text(
              'No detections',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            )
          else
            ...detections.take(3).map((detection) => Text(
              '${detection.label}: ${(detection.confidence * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            )),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      children: [
        // Start/Stop button
        Expanded(
          child: ElevatedButton(
            onPressed: _testController?.hasTestStarted == true
                ? _forceStop
                : _startTest,
            style: ElevatedButton.styleFrom(
              backgroundColor: _testController?.isTestRunning == true
                  ? Colors.red
                  : Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              _testController?.isTestRunning == true ? 'Stop Test' : 'Start Test',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Reset button
        ElevatedButton(
          onPressed: _resetTest,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          ),
          child: const Text('Reset'),
        ),
      ],
    );
  }
}
