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
│   └── test_controller.dart     # Test logic and step management
├── pages/
│   ├── landing_page.dart        # Welcome screen
│   ├── guide_page.dart          # Video instructions and survey
│   └── camera_page.dart         # Main detection interface
├── services/
│   └── detection_service.dart   # Mock ML detection service
├── widgets/
│   └── pretest_survey_widget.dart # Patient information form
└── main.dart                    # Application entry point

assets/
├── images/                      # Logo and icon assets
├── videos/                      # Instructional videos
├── audios/                      # Audio feedback files
└── instructions/                # Step-by-step video guides
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

### Mock Detection

The application includes a mock detection service that simulates ML model responses for development and testing purposes. This allows for:

- Rapid prototyping without ML infrastructure
- Consistent testing scenarios
- UI/UX validation

### Test Steps Configuration

Detection steps are configured in `TestController` with adjustable parameters:

- **Target detection time**: 0.5 seconds (configurable)
- **Maximum step time**: 3.0 seconds (configurable)
- **Confidence thresholds**: 65-70% (per step)

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
