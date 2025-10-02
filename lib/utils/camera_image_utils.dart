import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io' show Platform;

class CameraImageUtils {
  /// Convert CameraImage to Image object for ML processing
  /// This creates a proper Image object that can be processed by ML models
  static img.Image? convertCameraImageToImage(CameraImage cameraImage) {
    try {
      // For YUV420 format (most common on mobile cameras)
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return convertYUV420ToImage(cameraImage);
      }
      // For NV21 format (Android specific)
      else if (cameraImage.format.group == ImageFormatGroup.nv21) {
        return convertNV21ToImage(cameraImage);
      }
      // For BGRA8888 format (iOS specific)
      else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        return convertBGRA8888ToImage(cameraImage);
      }
      // For other formats, try to decode directly
      else {
        debugPrint('Unknown format, trying direct decode...');
        final bytes = cameraImage.planes[0].bytes;
        return img.decodeImage(bytes);
      }
    } catch (e) {
      debugPrint('Error converting camera image to Image: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Convert YUV420 CameraImage to RGB Image object
  static img.Image convertYUV420ToImage(CameraImage cameraImage) {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;

      if (cameraImage.planes.length < 3) {
        debugPrint('YUV420 conversion failed: insufficient planes (${cameraImage.planes.length})');
        throw Exception('YUV420 requires 3 planes');
      }

      final yPlane = cameraImage.planes[0];
      final uPlane = cameraImage.planes[1];
      final vPlane = cameraImage.planes[2];

      // Create a new RGB image
      final image = img.Image(width: width, height: height);

      for (int h = 0; h < height; h++) {
        for (int w = 0; w < width; w++) {
          final int yIndex = h * yPlane.bytesPerRow + w;
          final int uvIndex = (h ~/ 2) * uPlane.bytesPerRow + (w ~/ 2) * (uPlane.bytesPerPixel ?? 1);

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
    } catch (e) {
      debugPrint('YUV420 conversion error: $e');
      throw e;
    }
  }

  /// Convert BGRA8888 CameraImage to RGB Image object (iOS format)
  static img.Image convertBGRA8888ToImage(CameraImage cameraImage) {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;
      final bytes = cameraImage.planes[0].bytes;
      
      debugPrint('BGRA8888 conversion: ${width}x${height}, bytes: ${bytes.length}');
      
      // Create a new RGB image
      final image = img.Image(width: width, height: height);
      
      // BGRA8888 has 4 bytes per pixel
      for (int h = 0; h < height; h++) {
        for (int w = 0; w < width; w++) {
          final int pixelIndex = (h * width + w) * 4;
          
          if (pixelIndex + 3 < bytes.length) {
            final int b = bytes[pixelIndex];
            final int g = bytes[pixelIndex + 1];
            final int r = bytes[pixelIndex + 2];
            
            // Set pixel in image (convert BGRA to RGB)
            image.setPixelRgb(w, h, r, g, b);
          }
        }
      }
      
      return image;
    } catch (e) {
      debugPrint('BGRA8888 conversion error: $e');
      throw e;
    }
  }

  /// Convert NV21 CameraImage to RGB Image object (Android format)
  static img.Image convertNV21ToImage(CameraImage cameraImage) {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;
      
      final yPlane = cameraImage.planes[0];
      final uvPlane = cameraImage.planes[1];
      
      debugPrint('NV21 conversion: ${width}x${height}');
      
      // Create a new RGB image
      final image = img.Image(width: width, height: height);
      
      for (int h = 0; h < height; h++) {
        for (int w = 0; w < width; w++) {
          final int yIndex = h * yPlane.bytesPerRow + w;
          final int uvIndex = (h ~/ 2) * uvPlane.bytesPerRow + (w ~/ 2) * 2;
          
          if (yIndex < yPlane.bytes.length && 
              uvIndex + 1 < uvPlane.bytes.length) {
            
            final int y = yPlane.bytes[yIndex];
            final int v = uvPlane.bytes[uvIndex]; // NV21 has V first
            final int u = uvPlane.bytes[uvIndex + 1];
            
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
    } catch (e) {
      debugPrint('NV21 conversion error: $e');
      throw e;
    }
  }





  /// Convert CameraImage to encoded bytes (JPEG) for ML processing
  /// This creates properly encoded image bytes that can be decoded by img.decodeImage()
  static Uint8List convertCameraImageToBytes(CameraImage cameraImage, {bool isFrontCamera = false}) {
    try {
      // Try primary conversion method
      var image = convertCameraImageToImage(cameraImage);
      
      // Fallback methods if primary fails
      if (image == null) {
        debugPrint('Primary conversion failed, trying fallback methods...');
        image = _tryFallbackConversion(cameraImage);
      }
      
      if (image == null) {
        debugPrint('All conversion methods failed');
        return Uint8List(0);
      }
      
      // Apply platform-specific orientation correction
      img.Image processedImage;
      
      if (Platform.isIOS) {
        // iOS camera orientation handling
        if (isFrontCamera) {
          // iOS front camera: Flip horizontally first, then rotate appropriately
          final flippedImage = img.flipHorizontal(image);
          processedImage = flippedImage; // No rotation needed for iOS front camera
        } else {
          // iOS back camera: Currently rotated 90° right, need to counter-rotate
          // Rotate 270 degrees (or -90 degrees) to correct the 90° right rotation
          processedImage = img.copyRotate(image, angle: 270);
        }
      } else {
        // Android camera orientation handling (existing logic)
        if (isFrontCamera) {
          // Android front cameras: Rotate 270 degrees and flip horizontally
          final rotatedImage = img.copyRotate(image, angle: 270);
          processedImage = img.flipHorizontal(rotatedImage);
        } else {
          // Android back cameras: Rotate 90 degrees clockwise
          processedImage = img.copyRotate(image, angle: 90);
        }
      }
      
      // Encode as JPEG
      final jpegBytes = img.encodeJpg(processedImage);
      return Uint8List.fromList(jpegBytes);
    } catch (e) {
      debugPrint('Error converting camera image to bytes: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return Uint8List(0);
    }
  }

  /// Fallback conversion methods for problematic camera formats
  static img.Image? _tryFallbackConversion(CameraImage cameraImage) {
    try {
      // Method 1: Try treating first plane as RGB
      if (cameraImage.planes.isNotEmpty) {
        debugPrint('Trying fallback method 1: Direct plane decode');
        final bytes = cameraImage.planes[0].bytes;
        var decoded = img.decodeImage(bytes);
        if (decoded != null) {
          debugPrint('Fallback method 1 succeeded');
          return decoded;
        }
      }

      // Method 2: Try creating RGB image manually from Y plane (grayscale)
      if (cameraImage.planes.isNotEmpty) {
        debugPrint('Trying fallback method 2: Grayscale from Y plane');
        final yPlane = cameraImage.planes[0];
        final width = cameraImage.width;
        final height = cameraImage.height;
        
        final image = img.Image(width: width, height: height);
        
        for (int h = 0; h < height; h++) {
          for (int w = 0; w < width; w++) {
            final int yIndex = h * yPlane.bytesPerRow + w;
            if (yIndex < yPlane.bytes.length) {
              final int y = yPlane.bytes[yIndex];
              // Create grayscale RGB
              image.setPixelRgb(w, h, y, y, y);
            }
          }
        }
        
        debugPrint('Fallback method 2 succeeded');
        return image;
      }

      // Method 3: Try raw concatenation of all planes
      if (cameraImage.planes.length > 1) {
        debugPrint('Trying fallback method 3: Concatenated planes');
        final allBytes = <int>[];
        for (final plane in cameraImage.planes) {
          allBytes.addAll(plane.bytes);
        }
        
        var decoded = img.decodeImage(Uint8List.fromList(allBytes));
        if (decoded != null) {
          debugPrint('Fallback method 3 succeeded');
          return decoded;
        }
      }
      
      debugPrint('All fallback methods failed');
      return null;
    } catch (e) {
      debugPrint('Fallback conversion error: $e');
      return null;
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

  /// Convert CameraImage to ui.Image for drawing overlays
  static Future<ui.Image?> cameraImageToUiImage(CameraImage cameraImage, {bool isFrontCamera = false}) async {
    try {
      final imgImage = convertCameraImageToImage(cameraImage);
      if (imgImage == null) return null;

      // Apply orientation correction as in convertCameraImageToBytes
      img.Image processedImage;
      if (isFrontCamera) {
        final rotatedImage = img.copyRotate(imgImage, angle: 270);
        processedImage = img.flipHorizontal(rotatedImage);
      } else {
        processedImage = img.copyRotate(imgImage, angle: 90);
      }


      // Encode to PNG and decode via codec for robustness (handles pixel formats/strides)
      final pngBytes = img.encodePng(processedImage);

      final codec = await ui.instantiateImageCodec(Uint8List.fromList(pngBytes));
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e, st) {
      debugPrint('Error converting CameraImage to ui.Image: $e\n$st');
      return null;
    }
  }

  /// Convert img.Image to Float32List tensor for ML models
  /// Converts image pixels to normalized (0.0-1.0) RGB values
  static Float32List imageToTensor(
    img.Image sourceImage,
    int targetHeight,
    int targetWidth,
  ) {
    
    // Ensure image matches target dimensions
    img.Image finalImage = sourceImage;
    if (sourceImage.width != targetWidth || sourceImage.height != targetHeight) {
      finalImage = img.copyResize(
        sourceImage,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear,
      );
    }
    
    final int totalPixels = targetHeight * targetWidth * 3;
    final Float32List tensor = Float32List(totalPixels);
    
    // Convert image pixels to normalized float array
    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        final pixel = finalImage.getPixel(x, y);
        
        // Extract RGB components and normalize
        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();
        
        final int index = (y * targetWidth + x) * 3;
        tensor[index] = r / 255.0;     // R
        tensor[index + 1] = g / 255.0; // G
        tensor[index + 2] = b / 255.0; // B
      }
    }
    
    return tensor;
  }
}
