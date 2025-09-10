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
  avmed,
  yolov8n,
  mediapipe,
  sppbAnalysis,
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
    modelPath: 'assets/models/yolov5s_f16.tflite',
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

  static const ModelInfo avmed = ModelInfo(
    name: 'AVMED Dual Model',
    version: '16-12-24',
    supportedLabels: [
      'pill', 'mouth', 'hand', 'face', 'tongue', 'water', 'cup', 'person',
      'pill on tongue', 'no pill on tongue', 'drink water', 'no pill under tongue'
    ],
    defaultConfidenceThreshold: 0.7, // Based on AVMED pipeline plan
    inputWidth: 640, // Main model input - may need adjustment based on actual model
    inputHeight: 640,
    modelPath: 'assets/models/av_med_16-12-24_f16.tflite',
  );

  static const ModelInfo yolov8n = ModelInfo(
    name: 'YOLOv8n Chair Detection',
    version: '1.0.0',
    supportedLabels: ['chair', 'person', 'couch', 'dining table'],
    defaultConfidenceThreshold: 0.6,
    inputWidth: 320,
    inputHeight: 320,
    modelPath: 'assets/models/yolov8n_chair.tflite',
  );

  static const ModelInfo mediapipe = ModelInfo(
    name: 'MediaPipe Pose Landmark Full',
    version: '1.0.0',
    supportedLabels: [
      'left_hip', 'right_hip', 'left_knee', 'right_knee',
      'left_shoulder', 'right_shoulder', 'left_ankle', 'right_ankle',
      'nose', 'left_eye', 'right_eye', 'left_ear', 'right_ear',
      'left_wrist', 'right_wrist', 'left_elbow', 'right_elbow'
    ],
    defaultConfidenceThreshold: 0.5,
    inputWidth: 192,
    inputHeight: 192,
    modelPath: 'assets/models/pose_landmark_full.tflite',
  );

  static const ModelInfo sppbAnalysis = ModelInfo(
    name: 'SPPB Clinical Analysis',
    version: '1.0.0',
    supportedLabels: ['hip_angle', 'movement_phase', 'repetition_count'],
    defaultConfidenceThreshold: 0.7,
    inputWidth: 0, // Analysis model doesn't need image input
    inputHeight: 0,
    modelPath: '', // No model file needed for analysis
  );

  static ModelInfo getModelInfo(ModelType type) {
    switch (type) {
      case ModelType.yolov5s:
        return yolov5s;
      case ModelType.mock:
        return mock;
      case ModelType.avmed:
        return avmed;
      case ModelType.yolov8n:
        return yolov8n;
      case ModelType.mediapipe:
        return mediapipe;
      case ModelType.sppbAnalysis:
        return sppbAnalysis;
    }
  }
}
