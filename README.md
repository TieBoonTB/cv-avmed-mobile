# AV-MED Mobile

**A**dvanced **V**ideo Analytics for **Med**ication Adherence (AV-MED) Mobile is a Flutter application that detects if a patient has properly ingested medication using real-time computer vision and camera analysis.

## Features

- **Real-time Detection**: Uses device camera to monitor medication intake
- **Step-by-Step Guidance**: Interactive video guides for proper medication administration
- **Multi-step Verification**: Comprehensive 5-step verification process:
  1. Holding Pill
  2. Pill on Tongue
  3. Drink Water
  4. No Pill on Tongue
  5. No Pill under Tongue
- **Trial Mode**: Practice mode for users to familiarize themselves with the process
- **Cross-platform**: Runs on iOS and Android devices
- **Offline Capable**: Core functionality works without internet connection

## Development

### Requirements

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.0.0 or higher)
- [Dart SDK](https://dart.dev/get-dart) (3.0.0 or higher)
- [Android Studio](https://developer.android.com/studio) or [Xcode](https://developer.apple.com/xcode/) (for iOS development)
- A physical device or emulator with camera support

### Getting Started

1. **Clone the repository:**
   ```bash
   git clone https://github.com/chiangqinkang/avmed-mobile.git
   cd avmed-mobile
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify Flutter installation:**
   ```bash
   flutter doctor
   ```
4. **Launch Your Device Emulator:**

    Open Visual Studio Code and navigate to the bottom right of your screen. Select your desired device. If developing on MacOS, this should launch the simulator, and the selected device.
 
5. **Run the application:**
   ```bash
   # For development with hot reload
   flutter run

   # For release build
   flutter run --release
   ```

### Project Structure

```
lib/
├── controllers/
│   ├── base_test_controller.dart          # Abstract base for all test controllers
│   ├── mock_test_controller.dart          # Mock test implementation
│   ├── object_detection_test_controller.dart # Real object detection test
│   └── camera_feed_controller.dart        # Camera management
├── services/
│   ├── base_detection_service.dart        # Abstract detection service
│   ├── mock_detection_service.dart        # Mock detection for testing
│   └── yolov5_detection_service.dart      # Real YOLO detection
├── models/
│   ├── base_model.dart                    # Abstract ML model interface
│   ├── mock_model.dart                    # Mock model for testing
│   ├── yolov5s_model.dart                 # YOLOv5 TensorFlow Lite model
│   └── model_factory.dart                 # Factory for creating models
├── pages/
│   ├── landing_page.dart                  # Welcome screen
│   ├── guide_page.dart                    # Video instructions and survey
│   ├── camera_page.dart                   # Universal camera interface
│   ├── test_launcher_page.dart            # Developer test interface
│   └── camera_test_page.dart              # Camera testing utilities
├── utils/
│   └── test_controller_factory.dart       # Factory for creating test controllers
├── widgets/
│   └── pretest_survey_widget.dart         # Patient information form
├── types/
│   └── detection_types.dart               # Detection result data structures
├── config/
│   └── model_config.dart                  # ML model configurations
└── main.dart                              # Application entry point

assets/
├── models/
│   └── yolov5s_f16.tflite                 # YOLOv5 TensorFlow Lite model
├── images/                                # Logo and icon assets
├── videos/                                # Instructional videos
├── audios/                                # Audio feedback files
└── instructions/                          # Step-by-step video guides
```

## Architecture

### Overview

AV-MED Mobile uses a modern, extensible architecture based on abstract classes and factory patterns. This design allows for easy addition of new test types and detection services without modifying existing code.

### Architecture Layers

#### 1. **Abstract Layer**
- **BaseTestController**: Abstract base for all test implementations
- **BaseDetectionService**: Abstract interface for detection services  
- **BaseModel**: Abstract interface for ML models

#### 2. **Implementation Layer**
- **MockTestController**: Test implementation using mock detection
- **ObjectDetectionTestController**: Test using real object detection
- **MockDetectionService**: Simulated detection for development
- **YOLOv5DetectionService**: Real AI-powered object detection

#### 3. **Factory Layer**
- **TestControllerFactory**: Creates appropriate test controllers
- **ModelFactory**: Creates ML model instances

### Test Types

#### Mock Test
- **Purpose**: Development and testing with simulated results
- **Controller**: MockTestController
- **Service**: MockDetectionService  
- **Model**: MockModel
- **Use Case**: UI development, testing workflows, demonstrations

#### Object Detection Test (YOLOv5)
- **Purpose**: Real object detection using machine learning
- **Controller**: ObjectDetectionTestController
- **Service**: YOLOv5DetectionService
- **Model**: YOLOv5sModel (TensorFlow Lite)
- **Use Case**: Production detection of common objects

### Component Interactions

```
┌─────────────────────────────────────────────────┐
│                CameraPage                       │
│  (Universal Interface)                          │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│           TestControllerFactory                 │
│  Creates appropriate test controller            │
└─────────────────┬───────────────────────────────┘
                  │
        ┌─────────▼─────────┐    ┌─────────▼─────────┐
        │ MockTestController│    │ObjectDetectionTest│
        │                   │    │    Controller     │
        └─────────┬─────────┘    └─────────┬─────────┘
                  │                        │
    ┌─────────────▼─────────────┐ ┌────────▼──────────┐
    │  MockDetectionService     │ │YOLOv5DetectionSvce│
    └─────────────┬─────────────┘ └────────┬──────────┘
                  │                        │
        ┌─────────▼─────────┐    ┌─────────▼─────────┐
        │    MockModel      │    │  YOLOv5sModel     │
        └───────────────────┘    └───────────────────┘
```

### Adding New Test Types

1. **Create Test Controller**:
   ```dart
   class NewTestController extends BaseTestController {
     // Implement abstract methods
   }
   ```

2. **Create Detection Service** (if needed):
   ```dart
   class NewDetectionService extends BaseDetectionService {
     // Implement detection logic
   }
   ```

3. **Update Factory**:
   ```dart
   // Add to TestControllerFactory
   case 'newTest':
     return NewTestController(/* params */);
   ```

4. **Add to Configuration**:
   ```dart
   // Add test type constant and display info
   static const String newTest = 'newTest';
   ```

### Development Commands

```bash
# Install dependencies
flutter pub get

# Run code analysis
flutter analyze

# Run tests
flutter test

# Build for Android
flutter build apk

# Build for iOS
flutter build ios

# Clean build cache
flutter clean
```

## Configuration

### Assets

The application uses several asset types that need to be properly configured in `pubspec.yaml`:

- **Videos**: Instructional content stored in `assets/videos/`
- **Audio**: Feedback sounds in `assets/audios/`
- **Images**: Logos and icons in `assets/images/`
- **Instructions**: Step-specific guidance videos in `assets/instructions/`

### Camera Permissions

The app requires camera permissions to function properly. These are automatically configured in:

- **Android**: `android/app/src/main/AndroidManifest.xml`
- **iOS**: `ios/Runner/Info.plist`

## Building and Deployment

### Android

```bash
# Debug build
flutter build apk --debug

# Release build
flutter build apk --release

# App Bundle for Play Store
flutter build appbundle --release
```

### iOS

```bash
# Debug build
flutter build ios --debug

# Release build
flutter build ios --release
```

## Testing

### Test Types Available

#### 1. **Mock Detection Test**
- **Purpose**: Development and testing with simulated results
- **Access**: Test Launcher (Dev) → Mock Detection Test
- **Features**:
  - Predictable detection results
  - Fast execution (no ML processing)
  - Consistent UI testing scenarios
  - No camera processing required

#### 2. **Object Detection Test (YOLOv5)**
- **Purpose**: Real AI-powered object detection
- **Access**: Test Launcher (Dev) → Object Detection Test
- **Features**:
  - Real YOLOv5 model inference
  - Detects 80 COCO dataset objects
  - Camera-based live detection
  - Production-ready detection pipeline

## Troubleshooting

### Common Issues

1. **Camera Not Working:**
   - Ensure camera permissions are granted
   - Test on a physical device (emulator cameras may not work properly)
   - Check that no other apps are using the camera

2. **Asset Loading Issues:**
   - Run `flutter pub get` after adding new assets
   - Verify asset paths in `pubspec.yaml`
   - Clean and rebuild: `flutter clean && flutter pub get`

3. **Build Failures:**
   - Update Flutter: `flutter upgrade`
   - Clear cache: `flutter clean`
   - Delete `pubspec.lock` and run `flutter pub get`

4. **Performance Issues:**
   - Test on release build: `flutter run --release`
   - Close other resource-intensive apps
   - Ensure adequate device storage

### Platform-Specific Issues

**Android:**
- Minimum SDK version: Check `android/app/build.gradle`
- ProGuard issues: Configure in `android/app/proguard-rules.pro`

**iOS:**
- Deployment target: Check `ios/Runner.xcodeproj/project.pbxproj`
- Code signing: Ensure proper certificates in Xcode

## Implementation Details

### Architecture

The application follows a clean architecture pattern:

- **Controllers**: Business logic and state management
- **Services**: Data processing and external integrations
- **Pages**: UI screens and user interactions
- **Widgets**: Reusable UI components

### State Management

Uses Flutter's built-in `setState` pattern with:
- **TestController**: Manages test progression and step validation
- **AnimationController**: Handles UI animations and visual feedback
- **Stream-based updates**: Real-time detection result processing

### Detection Flow

1. **Initialization**: Camera setup and test controller preparation
2. **Step Execution**: Sequential validation of medication intake steps
3. **Real-time Processing**: Continuous frame analysis (mocked)
4. **Result Validation**: Step completion verification
5. **Progress Tracking**: Visual feedback and step advancement

### Navigation Flow

```
LandingPage → GuidePage → PretestSurveyWidget → CameraPage
     ↑                                              ↓
     ←─────────────── Completion/Exit ──────────────
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Commit changes: `git commit -am 'Add feature'`
4. Push to branch: `git push origin feature-name`
5. Submit a pull request

## License

This project is developed for healthcare medication adherence monitoring. Please ensure compliance with relevant healthcare data regulations when deploying in production environments.

## Support

For technical support or questions:
- Create an issue in the repository
- Check Flutter documentation: [https://flutter.dev/docs](https://flutter.dev/docs)
- Review troubleshooting section above
