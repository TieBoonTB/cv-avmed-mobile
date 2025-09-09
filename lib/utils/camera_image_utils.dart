import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class CameraImageUtils {
  /// Convert CameraImage to Image object for ML processing
  /// This creates a proper Image object that can be processed by ML models
  static img.Image? convertCameraImageToImage(CameraImage cameraImage) {
    try {
      // For YUV420 format (most common on mobile cameras)
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420ToImage(cameraImage);
      }
      // For other formats, try to decode directly
      else {
        final bytes = cameraImage.planes[0].bytes;
        return img.decodeImage(bytes);
      }
    } catch (e) {
      debugPrint('Error converting camera image to Image: $e');
      return null;
    }
  }

  /// Convert YUV420 CameraImage to RGB Image object
  static img.Image _convertYUV420ToImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    
    final yPlane = cameraImage.planes[0];
    final uPlane = cameraImage.planes[1];
    final vPlane = cameraImage.planes[2];
    
    // Create a new RGB image
    final image = img.Image(width: width, height: height);
    
    for (int h = 0; h < height; h++) {
      for (int w = 0; w < width; w++) {
        final int yIndex = h * yPlane.bytesPerRow + w;
        final int uvIndex = (h ~/ 2) * uPlane.bytesPerRow + (w ~/ 2) * uPlane.bytesPerPixel!;
        
        if (yIndex < yPlane.bytes.length && 
            uvIndex < uPlane.bytes.length && 
            uvIndex < vPlane.bytes.length) {
          
          final int y = yPlane.bytes[yIndex];
          final int u = uPlane.bytes[uvIndex];
          final int v = vPlane.bytes[uvIndex];
          
          // YUV to RGB conversion
          final int r = (y + 1.370705 * (v - 128)).clamp(0, 255).toInt();
          final int g = (y - 0.698001 * (v - 128) - 0.337633 * (u - 128)).clamp(0, 255).toInt();
          final int b = (y + 1.732446 * (u - 128)).clamp(0, 255).toInt();
          
          // Set pixel in image
          image.setPixelRgb(w, h, r, g, b);
        }
      }
    }
    
    return image;
  }

  /// Convert CameraImage directly to encoded bytes (JPEG) for ML processing
  /// This creates properly encoded image bytes that can be decoded by img.decodeImage()
  static Uint8List convertCameraImageToBytes(CameraImage cameraImage, {bool isFrontCamera = false}) {
    try {
      final image = convertCameraImageToImage(cameraImage);
      if (image == null) {
        debugPrint('Failed to convert CameraImage to Image');
        return Uint8List(0);
      }
      
      // Apply orientation correction based on camera type
      img.Image processedImage;
      if (isFrontCamera) {
        // Front cameras need special handling:
        // 1. Rotate 270 degrees clockwise (or -90 degrees) to correct orientation
        // 2. Flip horizontally to correct the mirror effect
        final rotatedImage = img.copyRotate(image, angle: 270);
        processedImage = img.flipHorizontal(rotatedImage);
      } else {
        // Back cameras need 90 degrees clockwise rotation only
        processedImage = img.copyRotate(image, angle: 90);
      }
      
      // Encode as JPEG
      final jpegBytes = img.encodeJpg(processedImage);
      return Uint8List.fromList(jpegBytes);
    } catch (e) {
      debugPrint('Error converting camera image to bytes: $e');
      return Uint8List(0);
    }
  }

  /// Simple YUV420 to grayscale conversion (much faster than RGB)
  /// Most ML models can work with grayscale images
  static Uint8List convertToGrayscale(CameraImage cameraImage) {
    try {
      // For YUV420 format, the Y plane is already grayscale
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return cameraImage.planes[0].bytes;
      }
      // For other formats, just return the first plane's bytes
      else {
        return cameraImage.planes[0].bytes;
      }
    } catch (e) {
      debugPrint('Error converting to grayscale: $e');
      return Uint8List(0);
    }
  }

  /// Get image dimensions from CameraImage
  static Map<String, int> getImageDimensions(CameraImage cameraImage) {
    return {
      'width': cameraImage.width,
      'height': cameraImage.height,
    };
  }

  /// Convert CameraImage to a displayable Widget
  /// This shows exactly what the ML model sees after processing
  static Widget? convertCameraImageToWidget(CameraImage cameraImage, {bool isFrontCamera = false}) {
    try {
      final imageBytes = convertCameraImageToBytes(cameraImage, isFrontCamera: isFrontCamera);
      if (imageBytes.isEmpty) {
        return null;
      }
      
      return Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    } catch (e) {
      debugPrint('Error converting camera image to widget: $e');
      return null;
    }
  }
}
