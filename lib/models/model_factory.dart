import 'base_model.dart';
import 'mock_model.dart';
import 'yolov5s_model.dart';
import '../config/model_config.dart';

/// Factory for creating model instances
class ModelFactory {
  static BaseModel createModel(ModelType type) {
    switch (type) {
      case ModelType.yolov5s:
        return YOLOv5sModel();
      case ModelType.mock:
        return MockModel();
    }
  }
}
