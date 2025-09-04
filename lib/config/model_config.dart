/// Model configuration information
class ModelInfo {
  final String name;
  final String version;
  final List<String> supportedLabels;
  final double defaultConfidenceThreshold;
  final int inputWidth;
  final int inputHeight;
  final String modelPath;

  const ModelInfo({
    required this.name,
    required this.version,
    required this.supportedLabels,
    required this.defaultConfidenceThreshold,
    required this.inputWidth,
    required this.inputHeight,
    required this.modelPath,
  });
}

/// Available model types
enum ModelType {
  yolov5s,
  mock,
}

/// Centralized model configurations
class ModelConfigurations {
  static const ModelInfo yolov5s = ModelInfo(
    name: 'YOLOv5s',
    version: '1.0.0',
    supportedLabels: [
      'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck', 'boat',
      'traffic light', 'fire hydrant', 'stop sign', 'parking meter', 'bench', 'bird', 'cat',
      'dog', 'horse', 'sheep', 'cow', 'elephant', 'bear', 'zebra', 'giraffe', 'backpack',
      'umbrella', 'handbag', 'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball',
      'kite', 'baseball bat', 'baseball glove', 'skateboard', 'surfboard', 'tennis racket',
      'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple',
      'sandwich', 'orange', 'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake',
      'chair', 'couch', 'potted plant', 'bed', 'dining table', 'toilet', 'tv', 'laptop',
      'mouse', 'remote', 'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink',
      'refrigerator', 'book', 'clock', 'vase', 'scissors', 'teddy bear', 'hair drier', 'toothbrush'
    ],
    defaultConfidenceThreshold: 0.5,
    inputWidth: 320,
    inputHeight: 320,
    modelPath: 'assets/models/yolov5s.tflite',
  );

  static const ModelInfo mock = ModelInfo(
    name: 'Mock Model',
    version: '1.0.0',
    supportedLabels: ['person', 'pill', 'hand'],
    defaultConfidenceThreshold: 0.8,
    inputWidth: 320,
    inputHeight: 320,
    modelPath: '', // No file needed for mock
  );

  static ModelInfo getModelInfo(ModelType type) {
    switch (type) {
      case ModelType.yolov5s:
        return yolov5s;
      case ModelType.mock:
        return mock;
    }
  }
}
