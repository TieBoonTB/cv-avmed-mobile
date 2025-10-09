import '../config/model_config.dart';
import 'isolate_detection_service.dart';

/// YOLOv5 detection service using isolates
class IsolateYOLOv5DetectionService extends IsolateDetectionService {
  IsolateYOLOv5DetectionService() : super(ModelType.yolov5s);
}

/// AVMED detection service using isolates
class IsolateAVMedDetectionService extends IsolateDetectionService {
  IsolateAVMedDetectionService() : super(ModelType.avmed);
}