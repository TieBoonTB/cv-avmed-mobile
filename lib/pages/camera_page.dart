import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../controllers/base_test_controller.dart';
import '../controllers/camera_feed_controller.dart';
import '../types/detection_types.dart';
import '../widgets/pose_mlkit_painter.dart';
import '../utils/test_controller_factory.dart';
import "../utils/adaptive_interval_calculator.dart";
import 'landing_page.dart';

/// Modern camera page using the new test controller architecture
/// Works with any implementation of BaseTestController
class CameraPage extends StatefulWidget {
  final String patientCode;
  final bool isTrial;
  final TestType testType;

  const CameraPage({
    super.key,
    required this.patientCode,
    this.isTrial = false,
    this.testType = TestType.objectDetector,
  });

  @override
  State<CameraPage> createState() => _CameraPageState();
}

/// A small draggable wrapper which displays [child] and allows the user to
/// drag it around the screen. The position is clamped to the available
/// canvas so it doesn't go fully off-screen.
class DraggableInstructionVideo extends StatefulWidget {
  final Widget child;
  final Offset initialPosition;

  const DraggableInstructionVideo({required this.child, this.initialPosition = const Offset(16, 200), Key? key}) : super(key: key);

  @override
  State<DraggableInstructionVideo> createState() => _DraggableInstructionVideoState();
}

class _DraggableInstructionVideoState extends State<DraggableInstructionVideo> {
  late Offset _pos;

  @override
  void initState() {
    super.initState();
    _pos = widget.initialPosition;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Calculate top right position when we have access to MediaQuery
    final screenSize = MediaQuery.of(context).size;
    final videoWidth = 200.0; // Approximate video width
    final padding = 16.0; // Padding from screen edges
    
    // Position at top right with some padding
    final topRightX = screenSize.width - videoWidth - padding;
    final topRightY = padding + 60.0; // Account for status bar and some spacing
    
    // Only update position if using default initial position
    if (widget.initialPosition == const Offset(16, 200)) {
      _pos = Offset(topRightX, topRightY);
    }
  }

  void _onPanUpdate(DragUpdateDetails details, Size parentSize) {
    final newX = (_pos.dx + details.delta.dx).clamp(0.0, parentSize.width - 200.0);
    final newY = (_pos.dy + details.delta.dy).clamp(0.0, parentSize.height - 120.0);
    setState(() {
      _pos = Offset(newX, newY);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: GestureDetector(
        onPanUpdate: (details) => _onPanUpdate(details, screenSize),
        child: widget.child,
      ),
    );
  }
}

class _CameraPageState extends State<CameraPage> with TickerProviderStateMixin {
  // Controllers
  final CameraFeedController _cameraController =
      Get.put(CameraFeedController());
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
  // Timer to update time-remaining UI independently of detection updates
  Timer? _timeRemainingTimer;
  int _defaultFrameProcessingInterval = 1000;
  int _frameProcessingInterval = 1000; // Will be adapted; initial value overwritten by controller when available

  // UI state
  bool _isInitialized = false;
  String _statusMessage = 'Initializing...';
  // Temporary centered message state (set when controller pushes a message)
  String? _centerMessage;
  Timer? _centerMessageTimer;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initComponents();
    _intervalCalculator = AdaptiveIntervalCalculator();
  }

  void _initAnimations() {
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  Future<void> _initComponents() async {
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
      _testController = TestControllerFactory.createController(
        type: widget.testType,
        onTestUpdate: _onTestUpdate,
        onTestComplete: _onTestComplete,
        onStepComplete: _onStepComplete,
      );

      await _testController!.initialize();

      // Align our frame interval with the controller's preferred value
      _frameProcessingInterval = _testController!.frameProcessingIntervalMs.round();

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

  void _startFrameTimer() {
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(
        Duration(milliseconds: _frameProcessingInterval), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _processCurrentFrame();
    });
  }

  void _stopFrameTimer() {
    _frameTimer?.cancel();
  }

  Future<void> _processCurrentFrame() async {
    if (!mounted || _testController == null) {
      return;
    }

    final currentImage = _cameraController.currentImage;
    if (currentImage != null) {
      // Start timing the frame processing
      _intervalCalculator.startTiming();

      try {
    await _testController!.processCurrentFrame(currentImage,
      isFrontCamera: _cameraController.isFrontCamera);

        setState(() {});

        // Stop timing and check if we should adjust interval
        _intervalCalculator.stopTiming();

        final newInterval =
            _intervalCalculator.calculateNewInterval(_frameProcessingInterval);
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
    // If the test controller pushed a display message, show it for 1.5s
    final msg = _testController?.displayMessage;
    if (msg != null && msg.isNotEmpty) {
      showCenterMessage(msg, duration: const Duration(milliseconds: 1500));
      // Clear the controller's message so we don't show it again
      _testController?.popDisplayMessage();
    }
  }

  void _onTestComplete() {
    if (!mounted) return; // Add mounted check
    _stopFrameTimer();
    // Stop the time remaining refresher when test completes
    _timeRemainingTimer?.cancel();
    _timeRemainingTimer = null;
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
    if (currentStep != null && mounted) {
      // Animate to the current step's progress
      _progressController.animateTo(
        currentStep.progress,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
    final message = _getCompletionMessage();

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
            Text(message),
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

  /// Temporarily shows a centered message on screen.
  /// Example: showCenterMessage('Hold the pill', duration: Duration(seconds: 2));
  void showCenterMessage(String message, {Duration duration = const Duration(seconds: 2)}) {
    // Cancel any existing timer so messages don't overlap
    _centerMessageTimer?.cancel();

    if (!mounted) return;

    setState(() {
      _centerMessage = message;
    });

    _centerMessageTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() {
        _centerMessage = null;
      });
    });
  }

  String _getCompletionMessage() {
    if (_testController == null) return 'Test completed.';

    final testSteps = _testController!.testSteps;
    // Compute summary stats from the TestStep objects
    final totalSteps = testSteps.length;
    final successfulSteps = testSteps.where((s) => s.isSuccess).length;
    final completedSteps = testSteps.where((s) => !s.isActive && (s.isSuccess || s.detectionsCount>0)).length;
    final overallProgress = testSteps.isEmpty
      ? 0.0
      : testSteps.map((s) => s.progress).reduce((a, b) => a + b) / testSteps.length;

    String message;
    if (successfulSteps == totalSteps) {
      message = 'Excellent! All $totalSteps steps completed successfully!';
    } else if (successfulSteps > 0) {
      message =
          'Completed $successfulSteps out of $totalSteps steps successfully.';
      message += '\nOverall progress: ${(overallProgress * 100).toInt()}%';
    } else {
      message = 'Test completed. Please try again for better results.';
      message += '\nOverall progress: ${(overallProgress * 100).toInt()}%';
    }

    // Add step details if some failed
        if (successfulSteps < totalSteps && completedSteps > 0) {
      message += '\n\nStep Details:';
      for (int i = 0; i < testSteps.length; i++) {
        final step = testSteps[i];
            final status = step.isSuccess
                ? '✅'
                : (!step.isActive && step.detectionsCount>0)
                    ? '⚠️'
                    : '❌';
        final progress = (step.progress * 100).toInt();
        message += '\n$status Step ${i + 1}: ${step.label} ($progress%)';
      }
    }

    return message;
  }

  String _getTestTitle() {
    return TestControllerFactory.getTestDisplayName(widget.testType);
  }

  String _getStatusText() {
    if (_testController == null) return 'Initializing...';

    final testSteps = _testController!.testSteps;
    final currentStepIndex = _testController!.currentStepIndex;

    if (!_testController!.isTestRunning && !_testController!.isTestComplete) {
      return 'Ready to start • ${testSteps.length} steps';
    } else if (_testController!.isTestComplete) {
      return 'Test completed successfully';
    } else if (currentStepIndex < testSteps.length) {
      final currentStep = testSteps[currentStepIndex];
      final progress = (currentStep.progress * 100).toInt();
      return 'Step ${currentStepIndex + 1}/${testSteps.length} • $progress% • ${currentStep.label}';
    }

    return 'Test in progress...';
  }

  void _resetTest() {
    _testController?.stopTest();
    // Reset steps
    _testController?.testSteps.forEach((s) => s.reset());
    _updateInstructionVideo();
  }

  void _startTest() {
    if (_testController != null && _isInitialized) {
      _testController!.startTest();
    }

    // Reset adaptive interval calculator for new test session
    _intervalCalculator.reset();
    _frameProcessingInterval =
        _defaultFrameProcessingInterval; // Reset to starting interval

    _startFrameTimer();
    // Start a timer to refresh time-remaining UI frequently (smooth countdown)
    _timeRemainingTimer?.cancel();
    _timeRemainingTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (timer) {
        if (!mounted) return;
        final step = _testController?.currentStep;
        if (step != null && step.timeRemainingPercent() >= 0 && step.isActive) {
          // Only update UI when there's an active timed step to avoid unnecessary rebuilds
          setState(() {});
        }
      },
    );
  }

  void _stopTest() {
    _testController?.stopTest();
    _stopFrameTimer();
    // Stop the time remaining refresher
    _timeRemainingTimer?.cancel();
    _timeRemainingTimer = null;
  }

  @override
  void dispose() {
    // Stop frame processing first to prevent any ongoing operations
    _stopFrameTimer();

    // Cancel time remaining timer
    _timeRemainingTimer?.cancel();
    _timeRemainingTimer = null;

    // Dispose animation controllers
    _flashController.dispose();
    _progressController.dispose();

    // Dispose video controller
    _videoController?.dispose();

    // Dispose test controller (this should also stop any ongoing detection)
    _testController?.dispose();

    // Cancel any pending center message timer
    _centerMessageTimer?.cancel();

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
              color:
                  _currentFlashColor.withValues(alpha: _flashController.value),
            ),
          ),
          // Detection overlays (landmarks only - no bounding boxes for objects)
          _buildDetectionOverlays(),
          // Centered temporary message (from controller)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _centerMessage == null,
              child: AnimatedOpacity(
                opacity: _centerMessage == null ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Center(
                  child: _centerMessage == null
                      ? const SizedBox.shrink()
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            _centerMessage ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
              ),
            ),
          ),
          // UI overlay
          _buildUIOverlay(),
          // Draggable instruction video (renders above UI overlay so user can move it)
          DraggableInstructionVideo(
            child: _buildInstructionVideo(),
          ),
        ],
      ),
    );
  }

  /// Helper to wrap content in camera preview sizing
  Widget _buildCameraContainer({required Widget child}) {
    return Positioned.fill(
      child: Obx(() {
        if (!_cameraController.isInitialized.value ||
            _cameraController.cameraController == null ||
            !_cameraController.cameraController!.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final previewSize =
            _cameraController.cameraController!.value.previewSize;
        if (previewSize == null) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewSize.height, // Rotated for camera orientation
            height: previewSize.width,
            child: child,
          ),
        );
      }),
    );
  }

  Widget _buildCameraFeed() {
    return _buildCameraContainer(
      child: Builder(
        builder: (context) {
          final controller = _cameraController.cameraController;
          if (controller == null || !controller.value.isInitialized) {
            return Container(color: Colors.black);
          }
          return controller.buildPreview();
        },
      ),
    );
  }

  /// Builds detection overlays based on detection type
  /// - Pose landmarks: skeleton painter
  /// - Objects: no overlay (as requested)
  Widget _buildDetectionOverlays() {
    if (_testController == null) return const SizedBox.shrink();

    final poseDetections = _testController!.getDetections('pose');

    // Show skeleton for pose detections
    if (poseDetections.isNotEmpty) {
      return _buildCameraContainer(
        child: CustomPaint(
          painter: MLKitPainter(
            landmarks: poseDetections,
            showLabels: false,
            minConfidence: 0.2,
          ),
        ),
      );
    }

    // No overlay for other detection types (objects, analysis, etc.)
    return const SizedBox.shrink();
  }

  Widget _buildUIOverlay() {
    return SafeArea(
      child: Column(
        children: [
          // Top bar
          _buildTopBar(),

          // Middle spacer
          const Expanded(child: SizedBox()),

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
          if (_testController?.currentStep != null) _buildProgressIndicator(),

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
        // Step label
        Text(
          currentStep.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Optional instruction subtitle
        if (currentStep.instruction != null &&
            currentStep.instruction!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            currentStep.instruction!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _progressController,
          builder: (context, child) => LinearProgressIndicator(
            value: _progressController.value,
            backgroundColor: Colors.white30,
            valueColor: AlwaysStoppedAnimation<Color>(currentStep.isActive
                ? Colors.blue
                : currentStep.isSuccess
                    ? Colors.green
                    : Colors.orange),
          ),
        ),
        const SizedBox(height: 6),
        // Time-remaining bar when the step is timed
        Builder(builder: (context) {
          final timePercent = currentStep.timeRemainingPercent();
          if (timePercent < 0) return const SizedBox.shrink();

          // Convert percent (0.0-100.0) to 0.0-1.0 for LinearProgressIndicator
          final progress = (timePercent / 100.0).clamp(0.0, 1.0);
          final secondsLeft = (currentStep.maxTime - currentStep.elapsedTime).clamp(0.0, double.infinity);

          return Column(
            children: [
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                    progress > 0.5 ? Colors.green : (progress > 0.2 ? Colors.orange : Colors.red)),
                minHeight: 6,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${secondsLeft.toStringAsFixed(1)}s left',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '${timePercent.toStringAsFixed(0)}% time',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          );
        }),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(currentStep.progress * 100).toStringAsFixed(0)}% complete',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              '${currentStep.detectionsCount}/${currentStep.detectionsRequired} detections',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetectionInfo() {
    if (_testController == null) return const SizedBox();

    final currentStep = _testController!.currentStep;

    // Use the new multi-service API to get different detection types
    final objectDetections = _testController!.getDetections('objects');
    final analysisDetections = _testController!.getDetections('analysis');

    // Choose a single detection list to display. Prefer objects over analysis.
    final List<DetectionResult> displayDetections = objectDetections.isNotEmpty ? objectDetections : analysisDetections;
    final bool isAnalysis = objectDetections.isEmpty && analysisDetections.isNotEmpty;
    final IconData detectionIcon = isAnalysis ? Icons.analytics : Icons.category;
    final Color detectionColor = isAnalysis ? Colors.purple : Colors.orange;

    // Show detection info if any detections are available
    if (displayDetections.isNotEmpty) {
      // Header
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: detectionColor.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(detectionIcon, color: detectionColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  objectDetections.isNotEmpty ? 'Objects' : 'Analysis',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (currentStep != null)
                  Text('Target: ${currentStep.targetLabel}',
                      style: const TextStyle(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 8),

            // For analysis: show label-only items (no confidence)
            if (isAnalysis) ...[
              ...displayDetections.take(6).map((d) {
                // Show simple label rows; remove confidence display
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        d.label == currentStep?.targetLabel
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: d.label == currentStep?.targetLabel
                            ? Colors.green
                            : Colors.white70,
                        size: 12,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          d.label,
                          style: TextStyle(
                            color: d.label == currentStep?.targetLabel
                                ? Colors.green
                                : Colors.white70,
                            fontSize: 12,
                            fontWeight: d.label == currentStep?.targetLabel
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ] else ...[
              // For objects: show label + confidence as percentage
              ...displayDetections.take(6).map((detection) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          detection.label == currentStep?.targetLabel
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: detection.label == currentStep?.targetLabel
                              ? Colors.green
                              : Colors.white70,
                          size: 12,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${detection.label}: ${(detection.confidence * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: detection.label == currentStep?.targetLabel
                                  ? Colors.green
                                  : Colors.white70,
                              fontSize: 12,
                              fontWeight:
                                  detection.label == currentStep?.targetLabel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      );
    }

    // Show status when no detections are available but controller is ready
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
          _testController!.availableServiceKeys.isNotEmpty
                    ? Icons.visibility_off
                    : Icons.hourglass_empty,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
        _testController!.availableServiceKeys.isNotEmpty
          ? 'No detections'
          : 'Initializing...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (currentStep != null) ...[
                const Spacer(),
                Text(
                  'Target: ${currentStep.targetLabel}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
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
            onPressed: _testController?.isTestRunning == true
                ? _stopTest
                : _startTest,
            style: ElevatedButton.styleFrom(
              backgroundColor: _testController?.isTestRunning == true
                  ? Colors.red
                  : Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              _testController?.isTestRunning == true
                  ? 'Stop Test'
                  : 'Start Test',
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
