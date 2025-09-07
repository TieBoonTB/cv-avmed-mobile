import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../widgets/pretest_survey_widget.dart';
import 'camera_page.dart';

class GuidePage extends StatefulWidget {
  @override
  GuidePageState createState() => GuidePageState();
}

class GuidePageState extends State<GuidePage> with WidgetsBindingObserver {
  bool showSurvey = false;
  bool shouldCheckIn = true; // This would come from your settings service
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  bool _hasVideoEnded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
  }

  void _initializeVideo() {
    _videoController = VideoPlayerController.asset('assets/videos/sample_video.mp4')
      ..initialize().then((_) {
        setState(() {
          _isVideoInitialized = true;
        });
        // Auto-play the video once (no looping)
        _videoController.play();
        print('Video initialized successfully');
        
        // Listen for video completion
        _videoController.addListener(_videoListener);
      }).catchError((error) {
        print('Video initialization error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Video loading error: $error')),
          );
        }
      });
  }

  void _videoListener() {
    // Check if video has ended
    if (_videoController.value.position >= _videoController.value.duration) {
      setState(() {
        _hasVideoEnded = true;
      });
    } else if (_hasVideoEnded && _videoController.value.isPlaying) {
      // Reset the ended state if video starts playing again
      setState(() {
        _hasVideoEnded = false;
      });
    }
  }

  void _replayVideo() {
    _videoController.seekTo(Duration.zero);
    _videoController.play();
    setState(() {
      _hasVideoEnded = false;
    });
  }

  void _toggleVideoPlayback() {
    if (_hasVideoEnded) {
      _replayVideo();
    } else if (_videoController.value.isPlaying) {
      _videoController.pause();
    } else {
      _videoController.play();
    }
    setState(() {});
  }

  void _showPretestSurvey() {
    setState(() {
      showSurvey = true;
    });
  }

  void _showWarning() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Safety Precaution',
            style: TextStyle(
              color: Color(0xFFA855F7), // Purple
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'For your own safety, you are not allowed to proceed to take the medications prescribed. Please call the helpline at +65 12345678 or consult a doctor.',
            style: TextStyle(
              color: Color(0xFF1F2937), // Dark gray
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFFA855F7), // Purple
                backgroundColor: Color(0xFFA855F7).withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToCamera(String patientCode) {
    // Navigate to camera page with patient code
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraPage(
          patientCode: patientCode,
          isTrial: false, // Set to true for trial mode
          testType: 'medication', // Default to medication test
        ),
      ),
    );
  }

  void _handleSurveySubmit(Map<String, dynamic> survey) {
    final patientCode = survey['patientCode'] as String;
    final checkIn = survey['checkIn'] as Map<String, bool>?;

    final canProceed = shouldCheckIn &&
        checkIn != null &&
        !(checkIn['isFeelingWell'] == true && checkIn['hasAdverseRxn'] != true);

    if (canProceed) {
      _showWarning();
      return;
    }

    _navigateToCamera(patientCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Guide'),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              
              const SizedBox(height: 32),
              
              // Video player (mobile-friendly)
              SizedBox(
                width: double.infinity,
                height: 200, // Reduced height for mobile
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _isVideoInitialized
                      ? GestureDetector(
                          onTap: _toggleVideoPlayback,
                          child: Stack(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: double.infinity,
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: _videoController.value.size.width,
                                    height: _videoController.value.size.height,
                                    child: VideoPlayer(_videoController),
                                  ),
                                ),
                              ),
                              // Play/Pause/Replay overlay
                              if (!_videoController.value.isPlaying || _hasVideoEnded)
                                Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  color: Colors.black.withValues(alpha: 0.3),
                                  child: Center(
                                    child: _hasVideoEnded
                                        ? Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.replay,
                                                size: 60,
                                                color: Colors.white,
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Replay',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Icon(
                                            Icons.play_arrow,
                                            size: 60,
                                            color: Colors.white,
                                          ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFFA855F7), // Purple instead of orange
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Loading Video...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'assets/videos/sample_video.mp4',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action button (mobile-friendly layout)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _showPretestSurvey,
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
                    'Start Test',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Survey component (conditionally shown)
              if (showSurvey)
                PretestSurveyWidget(
                  shouldCheckIn: shouldCheckIn,
                  onSurveySubmit: _handleSurveySubmit,
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController.removeListener(_videoListener);
    _videoController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Pause video when app goes to background
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_videoController.value.isPlaying) {
        _videoController.pause();
      }
    }
  }

  @override
  void deactivate() {
    // Pause video when navigating away from this page
    if (_videoController.value.isPlaying) {
      _videoController.pause();
    }
    super.deactivate();
  }
}
