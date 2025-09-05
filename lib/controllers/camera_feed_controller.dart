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

  Future<void> initializeCamera() async {
    _cameras = await availableCameras();
    await _initController(_isFrontCamera);
  }

  bool get isFrontCamera => _isFrontCamera;

  Future<void> _initController(bool useFront) async {
    try {
      isInitialized.value = false;
      // Stop image stream if active
      if (cameraController != null &&
          cameraController!.value.isStreamingImages) {
        await cameraController!.stopImageStream();
      }
      await cameraController?.dispose();
      final camera = useFront ? _cameras.first : _cameras.last;
      cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await cameraController!.initialize();
      isInitialized.value = true;
      cameraController!.startImageStream((image) {
        lastImage.value = image;
      });
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      isInitialized.value = false;
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2 || _isSwitching) return;
    _isSwitching = true;
    final wasFront = _isFrontCamera;
    _isFrontCamera = !wasFront;

    // Eject old controller so CameraPreview won't use it
    final oldController = cameraController;
    cameraController = null;
    isInitialized.value = false;
    try {
      await oldController?.dispose();
      await _initController(_isFrontCamera);
    } catch (e) {
      debugPrint('Failed to switch camera: $e');
      _isFrontCamera = wasFront;
      isInitialized.value = false;
    } finally {
      _isSwitching = false;
    }
  }

  Widget getCameraPreview() {
    if (cameraController == null || !isInitialized.value) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewAspectRatio = cameraController!.value.previewSize!.height / 
                                  cameraController!.value.previewSize!.width;
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final screenAspectRatio = screenHeight / screenWidth;
        
        // For portrait mode, crop sides if needed (like FaceTime)
        var scale = screenAspectRatio / previewAspectRatio;
        
        // Adjust scale to avoid too much cropping
        if (scale > 1.5) {
          scale = 1.5;  // Limit scale to prevent excessive zoom
        }
        
        return Container(
          color: Colors.black,
          child: Transform.scale(
            scale: scale,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1 / previewAspectRatio,
                child: CameraPreview(cameraController!),
              ),
            ),
          ),
        );
      }
    );
  }

  @override
  void onClose() {
    cameraController?.dispose();
    super.onClose();
  }
}

class CameraFeedView extends StatelessWidget {
  final CameraFeedController controller;

  CameraFeedView({super.key}) : controller = Get.put(CameraFeedController()) {
    // Initialize camera on first use
    if (!controller.isInitialized.value) {
      controller.initializeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isInitialized.value) {
        return const Center(child: CircularProgressIndicator());
      }
      return SizedBox.expand(
        child: controller.getCameraPreview(),
      );
    });
  }
}
