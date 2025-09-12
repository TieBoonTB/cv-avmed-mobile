import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/sppb_detection_services.dart';
import '../types/detection_types.dart';
import 'dart:ui' as ui;

/// Simple page to run MediaPipe pose detection on an image asset and draw landmarks
class PoseViewerPage extends StatefulWidget {
  @override
  PoseViewerPageState createState() => PoseViewerPageState();
}

class PoseViewerPageState extends State<PoseViewerPage> {
  final PoseDetectionService _service = PoseDetectionService();
  ui.Image? _image;
  List<DetectionResult> _landmarks = [];
  String? _selectedAsset;
  bool _loading = false;
  bool _showLabels = true;
  double _labelScale = 1.0;
  final TransformationController _transformationController = TransformationController();
  double _currentScale = 1.0;

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
    _initService();
  }

  Future<void> _initService() async {
    try {
      await _service.initialize();
    } catch (e) {
      print('Failed to init pose service: $e');
    }
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
      final results = await _service.processFrame(data, _image!.height, _image!.width);
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

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pose Viewer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedAsset ?? _assetOptions.first,
                    items: _assetOptions.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                    onChanged: (v) => setState(() => _selectedAsset = v),
                    decoration: const InputDecoration(labelText: 'Choose asset image'),
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
                                  child: CustomPaint(
                                    painter: _PosePainter(image: _image!, landmarks: _landmarks, showLabels: _showLabels, labelScale: _labelScale),
                                  ),
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
        ),
      ),
    );
  }
}

class _PosePainter extends CustomPainter {
  final ui.Image image;
  final List<DetectionResult> landmarks;
  final bool showLabels;
  final double labelScale;

  _PosePainter({required this.image, required this.landmarks, this.showLabels = true, this.labelScale = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the image
    final paint = Paint();
    canvas.drawImage(image, Offset.zero, paint);

  // Draw landmarks as circles
  final circlePaint = Paint()..color = Colors.red.withValues(alpha: 0.95);
  final textPainter = TextPainter(textDirection: TextDirection.ltr);

  // Scale sizes based on image size and labelScale
  final base = (image.width + image.height) / 2.0;
  final baseFont = (base / 600.0) * 12.0; // roughly 12 at mid sizes
  final double fontSize = (baseFont * labelScale).clamp(8.0, 200);
  final circleRadius = ((image.width + image.height) * 0.0025);

    for (final lm in landmarks) {
      final box = lm.box;
      final x = box.x * image.width;
      final y = box.y * image.height;
      canvas.drawCircle(Offset(x, y), circleRadius, circlePaint);

      if (showLabels) {
        final label = lm.label;
        final tp = TextSpan(text: label, style: TextStyle(color: Colors.white, fontSize: fontSize));
        textPainter.text = tp;
        textPainter.layout();

        // Draw small semi-opaque background rect for readability
        final padding = 4.0;
        final rect = Rect.fromLTWH(
          x + 6,
          y - textPainter.height / 2 - padding / 2,
          textPainter.width + padding,
          textPainter.height + padding,
        );
        final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), bgPaint);

        textPainter.paint(canvas, Offset(x + 8, y - textPainter.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
