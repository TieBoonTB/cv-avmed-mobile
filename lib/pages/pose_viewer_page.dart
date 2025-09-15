import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/isolate_detection_service.dart';
import '../types/detection_types.dart';
import 'dart:ui' as ui;
import '../widgets/pose_qualcomm_painter.dart';
import '../widgets/pose_mediapipe_painter.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import '../controllers/camera_feed_controller.dart';
import 'package:get/get.dart';
import '../utils/camera_image_utils.dart';

/// Simple page to run MediaPipe pose detection on an image asset and draw landmarks
class PoseViewerPage extends StatefulWidget {
  @override
  PoseViewerPageState createState() => PoseViewerPageState();
}

class PoseViewerPageState extends State<PoseViewerPage> {
  IsolateDetectionService? _service;
  ui.Image? _image;
  List<DetectionResult> _landmarks = [];
  String? _selectedAsset;
  bool _loading = false;
  bool _showLabels = true;
  double _labelScale = 1.0;
  final TransformationController _transformationController = TransformationController();
  double _currentScale = 1.0;
  bool _showCameraFeed = false;
  CameraController? _cameraController;
  late final CameraFeedController _cameraFeedController;
  Timer? _inferenceTimer;
  bool _isProcessing = false;
  
  // Model type selection
  String _selectedModelType = 'Qualcomm';
  final List<String> _modelTypes = ['Qualcomm', 'MediaPipe'];

  void _zoomBy(double factor) {
    final matrix = _transformationController.value;
    final currentScale = matrix.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(0.2, 10.0);

    // Compute focal point as center of the viewport
    final focal = Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2);

    // Translate to focal, scale, translate back
    final translationToFocal = Matrix4.identity()..translate(-focal.dx, -focal.dy);
    final scaleMatrix = Matrix4.identity()..scale(newScale / currentScale);
    final translationBack = Matrix4.identity()..translate(focal.dx, focal.dy);

    final newMatrix = translationBack * scaleMatrix * translationToFocal * matrix;
    _transformationController.value = newMatrix;
    setState(() => _currentScale = newScale);
  }

  final List<String> _assetOptions = [
    'assets/images/poseTest1.jpg',
    'assets/images/poseTest2.jpg',
    'assets/images/poseTest3.jpg',
  ];

  @override
  void initState() {
    super.initState();
    // Default to the first asset so the Run button is enabled on open
    _selectedAsset = _assetOptions.first;
    _initService();
    _cameraFeedController = Get.put(CameraFeedController());
    _cameraFeedController.initializeCamera();
  }

  Future<void> _initService() async {
    try {
      // Dispose existing service if any
      _service?.dispose();
      
      // Create the appropriate service based on selected model type
      if (_selectedModelType == 'MediaPipe') {
        _service = IsolateMediaPipePoseDetectionService();
      } else {
        _service = IsolateQualcommPoseDetectionService();
      }
      
      await _service!.initialize();
    } catch (e) {
      print('Failed to init pose service: $e');
    }
  }

  /// Get the appropriate painter based on selected model type
  CustomPainter _getPainter({required bool showLabels}) {
    if (_selectedModelType == 'MediaPipe') {
      return MediaPipePainter(landmarks: _landmarks, showLabels: showLabels);
    } else {
      return QualcommPainter(landmarks: _landmarks, showLabels: showLabels);
    }
  }

  /// Handle model type change
  Future<void> _onModelTypeChanged(String? newType) async {
    if (newType == null || newType == _selectedModelType) return;
    
    setState(() {
      _selectedModelType = newType;
      _loading = true;
    });
    
    // Reinitialize service with new model type
    await _initService();
    
    setState(() {
      _loading = false;
    });
  }

  Future<void> _loadAssetImage(String assetPath) async {
    setState(() => _loading = true);
    try {
      final bytes = await rootBundle.load(assetPath);
      final data = bytes.buffer.asUint8List();

      // Decode to ui.Image for drawing
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      _image = frame.image;

      // Run pose detection using service (expects JPEG/PNG bytes)
      final results = await _service?.processFrame(data, _image!.height, _image!.width) ?? [];
      setState(() {
        _landmarks = results;
        _selectedAsset = assetPath;
      });
    } catch (e) {
      print('Error loading asset image: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _startInferenceTimer() {
    if (_inferenceTimer != null && _inferenceTimer!.isActive) return;
    _inferenceTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!_showCameraFeed) return;
      if (_isProcessing) return; // skip if already processing

      final lastImage = _cameraFeedController.currentImage;
      if (lastImage == null) return;

      _isProcessing = true;
      try {
        final bytes = CameraImageUtils.convertCameraImageToBytes(lastImage, isFrontCamera: _cameraFeedController.isFrontCamera);
        if (bytes.isEmpty) return;

        final results = await _service?.processFrame(bytes, lastImage.height, lastImage.width) ?? [];
        setState(() {
          _landmarks = results;
        });
      } catch (e) {
        debugPrint('Inference error: $e');
      } finally {
        _isProcessing = false;
      }
    });
  }

  void _stopInferenceTimer() {
    _inferenceTimer?.cancel();
    _inferenceTimer = null;
    _isProcessing = false;
  }

  @override
  void dispose() {
    _stopInferenceTimer();
    _cameraController?.dispose();
    _service?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pose Viewer'),
        actions: [
          IconButton(
            icon: Icon(_showCameraFeed ? Icons.image : Icons.camera_alt),
            onPressed: () async {
              final willShow = !_showCameraFeed;
              setState(() => _showCameraFeed = willShow);

              if (willShow) {
                // Ensure camera is initialized (initializeCamera is idempotent)
                await _cameraFeedController.initializeCamera();
                _startInferenceTimer();
              } else {
                // Stop updates so detections aren't overwritten while not viewing camera
                _stopInferenceTimer();
              }
            },
          ),
          // Camera switch button
          IconButton(
            icon: Icon(_cameraFeedController.isFrontCamera ? Icons.camera_front : Icons.camera_rear),
            onPressed: () async {
              // If camera view not visible, just toggle the controller state so next open uses the other camera
              if (!_showCameraFeed) {
                await _cameraFeedController.switchCamera();
                return;
              }

              // If camera view is visible, stop updates, switch camera, then restart
              _stopInferenceTimer();
              await _cameraFeedController.switchCamera();
              // Small delay to allow camera controller to initialize
              await Future.delayed(const Duration(milliseconds: 300));
              _startInferenceTimer();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _showCameraFeed ? _buildCameraFeedView() : _buildPoseViewerWithImage(),
      ),
    );
  }

  Widget _buildCameraFeedView() {
    // If camera controller from CameraFeedController is available, show CameraPreview
    final camCtrl = _cameraFeedController.cameraController;
    if (camCtrl == null || !camCtrl.value.isInitialized) {
      return const Center(child: Text('Camera not ready'));
    }

    return Stack(
      children: [
        CameraPreview(camCtrl), // Live camera feed (not the saved image)
        // Overlay landmarks using the appropriate painter
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _getPainter(showLabels: false),
            ),
          ),
        ),
      ],
    );
  }

  Column _buildPoseViewerWithImage() {
    return Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedModelType,
                    items: _modelTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                    onChanged: _onModelTypeChanged,
                    decoration: const InputDecoration(labelText: 'Model Type'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _selectedAsset,
                    items: _assetOptions.map((a) => DropdownMenuItem(value: a, child: Text(a.split('/').last))).toList(),
                    onChanged: (v) => setState(() => _selectedAsset = v),
                    decoration: const InputDecoration(labelText: 'Test Image'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _selectedAsset == null || _loading ? null : () => _loadAssetImage(_selectedAsset!),
                  child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Run'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Show labels'),
                Switch(
                  value: _showLabels,
                  onChanged: (v) => setState(() => _showLabels = v),
                ),
                const SizedBox(width: 8),
                const Text('Size'),
                SizedBox(
                  width: 120,
                  child: Slider(
                    value: _labelScale,
                    min: 0.5,
                    max: 10.0,
                    divisions: 5,
                    label: _labelScale.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _labelScale = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _image == null
                    ? const Center(child: Text('No image loaded'))
                    : Stack(
                        children: [
                          InteractiveViewer(
                            transformationController: _transformationController,
                            panEnabled: true,
                            scaleEnabled: true,
                            minScale: 0.2,
                            maxScale: 10.0,
                            onInteractionUpdate: (details) {
                              // Update current scale for UI display
                              final matrix = _transformationController.value;
                              setState(() => _currentScale = matrix.getMaxScaleOnAxis());
                            },
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: _image!.width.toDouble(),
                                height: _image!.height.toDouble(),
                                child: GestureDetector(
                                  onDoubleTap: () {
                                    _transformationController.value = Matrix4.identity();
                                    setState(() => _currentScale = 1.0);
                                  },
                                  child: LayoutBuilder(builder: (context, constraints) {
                                    // Get image dimensions for RawImage widget
                                    final imgW = _image!.width.toDouble();
                                    final imgH = _image!.height.toDouble();

                                    return Stack(children: [
                                      // Draw the image at its pixel size so painter coords align
                                      Positioned.fill(
                                        child: FittedBox(
                                          fit: BoxFit.contain,
                                          child: SizedBox(width: imgW, height: imgH, child: RawImage(image: _image)),
                                        ),
                                      ),
                                      // Overlay pose painter
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: CustomPaint(
                                            painter: _getPainter(showLabels: _showLabels),
                                          ),
                                        ),
                                      ),
                                    ]);
                                  }),
                                ),
                              ),
                            ),
                          ),

                          // Zoom controls overlay
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Column(
                              children: [
                                FloatingActionButton.small(
                                  heroTag: 'zoom_in',
                                  child: const Icon(Icons.zoom_in),
                                  onPressed: () {
                                    _zoomBy(1.2);
                                  },
                                ),
                                const SizedBox(height: 8),
                                FloatingActionButton.small(
                                  heroTag: 'zoom_out',
                                  child: const Icon(Icons.zoom_out),
                                  onPressed: () {
                                    _zoomBy(1 / 1.2);
                                  },
                                ),
                                const SizedBox(height: 8),
                                FloatingActionButton.small(
                                  heroTag: 'reset_zoom',
                                  child: const Icon(Icons.refresh),
                                  onPressed: () {
                                    _transformationController.value = Matrix4.identity();
                                    setState(() => _currentScale = 1.0);
                                  },
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                                  child: Text('x${_currentScale.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
  }
}
