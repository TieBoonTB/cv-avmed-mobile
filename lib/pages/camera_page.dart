import 'package:flutter/material.dart';
import '../controllers/test_controller.dart';
import 'landing_page.dart';

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
  bool _isCameraInitialized = true; // Simulated camera state
  bool _isFrontCamera = true; // Track camera direction
  
  // Test controller
  late TestController _testController;
  
  // Animation controllers for flashing effects
  late AnimationController _flashController;
  Color _currentFlashColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupTestController();
  }

  void _setupAnimations() {
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  void _setupTestController() {
    _testController = TestController(
      isTrial: widget.isTrial,
      onTestUpdate: () {
        setState(() {});
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

  void _switchCamera() {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    
    // Show feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to ${_isFrontCamera ? 'front' : 'rear'} camera'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _startTest() {
    _testController.startTest();
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

  Widget _buildTrialBanner() {
    if (!widget.isTrial) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: Color(0xFF0EA5E9), size: 24), // Sky blue
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This is a trial run. No information will be saved.',
              style: TextStyle(
                color: Color(0xFF1F2937), // Dark gray
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildCameraPreview() {
    if (!_isCameraInitialized) {
      return Container(
        height: 300,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          // Camera preview placeholder with flash overlay
          Container(
            width: double.infinity,
            height: 300,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // Placeholder camera preview
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
                        size: 60,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_isFrontCamera ? 'Front' : 'Rear'} Camera Preview',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Patient: ${widget.patientCode}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Flash overlay
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: _currentFlashColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
          // Camera switch button
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                onPressed: _switchCamera,
                icon: const Icon(
                  Icons.cameraswitch,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          // Debug detection button (for testing)
          if (_testController.isTestRunning)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
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
                    size: 24,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepsList() {
    return Column(
      children: _testController.testSteps.asMap().entries.map((entry) {
        TestStep step = entry.value;
        
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: step.isActive 
                ? Colors.white.withValues(alpha: 0.95)
                : step.isDone
                    ? (step.isSuccess ? Colors.white.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.85))
                    : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: step.isActive 
                ? Border.all(color: Color(0xFFA855F7), width: 2) // Purple border
                : step.isDone && step.isSuccess
                    ? Border.all(color: Colors.green, width: 2)
                    : step.isDone && !step.isSuccess
                        ? Border.all(color: Colors.red, width: 2)
                        : Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Step icon
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: step.isDone
                          ? (step.isSuccess ? Colors.green : Colors.red)
                          : step.isActive
                              ? Color(0xFFA855F7) // Purple
                              : Color(0xFF6B7280), // Gray
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      step.isDone
                          ? (step.isSuccess ? Icons.check : Icons.close)
                          : step.isActive
                              ? Icons.play_arrow
                              : Icons.circle,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Step label
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.label,
                          style: TextStyle(
                            color: step.isActive 
                                ? Color(0xFFA855F7) // Purple for active
                                : Color(0xFF1F2937), // Dark gray for others
                            fontSize: 15,
                            fontWeight: step.isActive ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Spinner for active step
                  if (step.isActive && step.targetFrameCount > 0) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA855F7)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButton() {
    if (!_testController.hasTestStarted) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _startTest,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFFA855F7), // Purple text
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.3),
          ),
          child: const Text(
            'Start',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else if (!_testController.isCompleted) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _confirmEndTest,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[500],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 8,
            shadowColor: Colors.red.withValues(alpha: 0.3),
          ),
          child: const Text(
            'End',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _showCompletionDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[500],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 8,
            shadowColor: Colors.green.withValues(alpha: 0.3),
          ),
          child: const Text(
            'Complete',
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
      body: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.5, -1.0),
            end: Alignment(0.5, 1.0),
            colors: [
              Color(0xFFEC4899), // pink-500
              Color(0xFFA855F7), // purple-500
              Color(0xFF0EA5E9), // sky-500
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
            child: Column(
              children: [
                // Trial banner
                _buildTrialBanner(),
                
                const SizedBox(height: 20),
                
                // Title
                Text(
                  'Real Time Detection',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black.withValues(alpha: 0.3),
                        offset: Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 20),
                
                // Camera preview (stacked vertically at top)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildCameraPreview(),
                ),
                
                const SizedBox(height: 20),
                
                // Steps list (below camera)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test Steps:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 8.0,
                              color: Colors.black.withValues(alpha: 0.3),
                              offset: Offset(1.0, 1.0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStepsList(),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Action button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildActionButton(),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
        ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }
}
