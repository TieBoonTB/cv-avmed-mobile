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
  avmed,
  mediapipe,
  mlkit,
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

  static const ModelInfo avmed = ModelInfo(
    name: 'AVMED Dual Model',
    version: '16-12-24',
    supportedLabels: [
      "pill", "pill on tongue", "no pill on tongue", "drink water", 
      "please use transparent cup", "mouth covered", "no pill under tongue"
    ],
    defaultConfidenceThreshold: 0.5, // Based on AVMED pipeline plan
    inputWidth: 224, 
    inputHeight: 224,
    modelPath: 'assets/models/av_med_16-12-24_f16.tflite',
  );
  
  static const ModelInfo mediapipe = ModelInfo(
    name: 'MediaPipe Pose Landmark Full',
    version: '1.0.0',
    supportedLabels: [
      'nose', 'left_eye_inner', 'left_eye', 'left_eye_outer', 'right_eye_inner', 'right_eye',
      'right_eye_outer', 'left_ear', 'right_ear', 'mouth_left', 'mouth_right',
      'left_shoulder', 'right_shoulder', 'left_elbow', 'right_elbow', 'left_wrist', 'right_wrist',
      'left_pinky', 'right_pinky', 'left_index', 'right_index', 'left_thumb', 'right_thumb',
      'left_hip', 'right_hip', 'left_knee', 'right_knee', 'left_ankle', 'right_ankle',
      'left_heel', 'right_heel', 'left_foot_index', 'right_foot_index'
    ],
    defaultConfidenceThreshold: 0.3,
    inputWidth: 256,
    inputHeight: 256,
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

  static const ModelInfo mlkit = ModelInfo(
    name: 'ML Kit Pose Detection',
    version: '1.0.0',
    supportedLabels: [
      'nose', 'left_eye_inner', 'left_eye', 'left_eye_outer', 'right_eye_inner', 'right_eye',
      'right_eye_outer', 'left_ear', 'right_ear', 'mouth_left', 'mouth_right',
      'left_shoulder', 'right_shoulder', 'left_elbow', 'right_elbow', 'left_wrist', 'right_wrist',
      'left_pinky', 'right_pinky', 'left_index', 'right_index', 'left_thumb', 'right_thumb',
      'left_hip', 'right_hip', 'left_knee', 'right_knee', 'left_ankle', 'right_ankle',
      'left_heel', 'right_heel', 'left_foot_index', 'right_foot_index'
    ],
    defaultConfidenceThreshold: 0.5,
    inputWidth: 0, // ML Kit handles dynamic input sizes
    inputHeight: 0,
    modelPath: '', // handled by mlkit library
  );

  static ModelInfo getModelInfo(ModelType type) {
    switch (type) {
      case ModelType.yolov5s:
        return yolov5s;
      case ModelType.avmed:
        return avmed;
      case ModelType.mediapipe:
        return mediapipe;
      case ModelType.mlkit:
        return mlkit;
      case ModelType.sppbAnalysis:
        return sppbAnalysis;
    }
  }
}
