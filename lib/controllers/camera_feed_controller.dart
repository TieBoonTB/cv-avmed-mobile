import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';

class CameraFeedController extends GetxController {
  CameraController? cameraController;
  final RxBool isInitialized = false.obs;
  final Rx<CameraImage?> lastImage = Rx<CameraImage?>(null);
  bool _isFrontCamera = true;
  List<CameraDescription> _cameras = [];
  bool _isSwitching = false;

  bool get isFrontCamera => _isFrontCamera;
  
  /// Get the current camera image for external processing
  CameraImage? get currentImage => lastImage.value;

  Future<void> initializeCamera() async {
    _cameras = await availableCameras();
    await _initController(_isFrontCamera);
  }

  Future<void> _initController(bool useFront) async {
    debugPrint('Initializing camera controller (useFront: $useFront)');
    
    try {
      // Make sure we're in the right state before starting
      isInitialized.value = false;
      
      // Make sure camera list is not empty
      if (_cameras.isEmpty) {
        debugPrint('No cameras available');
        return;
      }
      
      // Select the appropriate camera with better error handling
      CameraDescription camera;
      try {
        if (useFront) {
          // Try to find front camera, fall back to first camera
          camera = _cameras.firstWhere(
            (cam) => cam.lensDirection == CameraLensDirection.front,
            orElse: () => _cameras.first
          );
        } else {
          // Try to find back camera, fall back to last camera
          camera = _cameras.firstWhere(
            (cam) => cam.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras.last
          );
        }
        debugPrint('Selected camera: ${camera.name}, direction: ${camera.lensDirection}');
      } catch (e) {
        debugPrint('Error selecting camera: $e');
        // Fall back to first camera in the list
        camera = _cameras.first;
      }
      
      // Create the new controller
      cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      
      // Initialize the controller
      debugPrint('Initializing camera controller...');
      await cameraController!.initialize();
      debugPrint('Camera controller initialized');
      
      // Mark as initialized BEFORE starting the stream
      isInitialized.value = true;
      
      // Start the image stream with error handling
      try {
        debugPrint('Starting image stream...');
        await cameraController!.startImageStream((image) {
          lastImage.value = image;
        });
        debugPrint('Image stream started');
      } catch (e) {
        debugPrint('Warning: Failed to start image stream: $e');
        // Don't set isInitialized to false - we can still use the camera preview
        // even if the image stream fails
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      isInitialized.value = false;
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2 || _isSwitching) return;
    
    _isSwitching = true;
    debugPrint('Switching camera...');
    
    try {
      // Set state before anything else to prevent UI from trying to use the controller during transition
      isInitialized.value = false;
      
      // Store current camera direction
      final wasFront = _isFrontCamera;
      _isFrontCamera = !wasFront;
      
      // Important: First stop the image stream before doing anything else
      if (cameraController != null) {
        if (cameraController!.value.isStreamingImages) {
          try {
            await cameraController!.stopImageStream();
            debugPrint('Image stream stopped');
          } catch (e) {
            debugPrint('Error stopping image stream: $e');
            // Continue anyway
          }
        }
      }
      
      // Use a local variable for the old controller and set instance to null
      // This ensures any other async operations won't try to use the old controller
      final oldController = cameraController;
      cameraController = null;
      
      // Dispose the old controller with proper error handling
      if (oldController != null) {
        try {
          await oldController.dispose();
          debugPrint('Old camera controller disposed');
        } catch (e) {
          debugPrint('Error disposing old camera controller: $e');
          // Continue anyway - we need to create a new controller
        }
      }
      
      // Small delay to ensure complete disposal
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Initialize the new camera
      await _initController(_isFrontCamera);
    } catch (e) {
      debugPrint('Failed to switch camera: $e');
      _isFrontCamera = !_isFrontCamera; // Revert the camera direction change
      
      // Try to initialize with the original camera as fallback
      try {
        await _initController(_isFrontCamera);
      } catch (fallbackError) {
        debugPrint('Failed to initialize fallback camera: $fallbackError');
        isInitialized.value = false;
      }
    } finally {
      _isSwitching = false;
    }
  }

  @override
  void onClose() {
    cameraController?.dispose();
    super.onClose();
  }
}

class CameraFeedView extends StatefulWidget {
  const CameraFeedView({super.key});
  
  @override
  State<CameraFeedView> createState() => _CameraFeedViewState();
}

class _CameraFeedViewState extends State<CameraFeedView> {
  late final CameraFeedController controller;
  bool _hasAttemptedInitialization = false;
  
  @override
  void initState() {
    super.initState();
    controller = Get.put(CameraFeedController());
    
    // Add a small delay before initializing to ensure the widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
  }
  
  Future<void> _initializeCamera() async {
    if (!_hasAttemptedInitialization) {
      _hasAttemptedInitialization = true;
      debugPrint('Initializing camera from CameraFeedView');
      await controller.initializeCamera();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // If not initialized and not yet attempted, try to initialize
      if (!controller.isInitialized.value && !_hasAttemptedInitialization) {
        _hasAttemptedInitialization = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.initializeCamera();
        });
      }
      
      // Show loading indicator if not initialized
      if (!controller.isInitialized.value) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Setting up camera...', 
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              SizedBox(height: 8),
              if (_hasAttemptedInitialization)
                TextButton(
                  onPressed: () {
                    _hasAttemptedInitialization = false;
                    _initializeCamera();
                  },
                  child: Text('Retry', style: TextStyle(color: Colors.blue)),
                ),
            ],
          ),
        );
      }
      
      // Handle null controller
      if (controller.cameraController == null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography, size: 48, color: Colors.white70),
              SizedBox(height: 16),
              Text(
                'Camera not available',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _hasAttemptedInitialization = false;
                  _initializeCamera();
                },
                child: Text('Retry', style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
        );
      }
      
      // Try to create the camera preview with error handling
      try {
        if (!controller.cameraController!.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        return FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.cameraController!.value.previewSize!.height,
              height: controller.cameraController!.value.previewSize!.width,
              child: controller.cameraController!.buildPreview(),
            ));
      } catch (e) {
        debugPrint('Error creating CameraPreview widget: $e');
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              SizedBox(height: 16),
              Text('Camera Error', style: TextStyle(color: Colors.white, fontSize: 18)),
              SizedBox(height: 8),
              Text(
                e.toString(),
                style: TextStyle(color: Colors.white70, fontSize: 12),
                maxLines: 3,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _hasAttemptedInitialization = false;
                  _initializeCamera();
                },
                child: Text('Retry', style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
        );
      }
    });
  }
}