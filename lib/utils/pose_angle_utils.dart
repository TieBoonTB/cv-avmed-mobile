import 'dart:math' as math;
import '../types/detection_types.dart';

/// Utility functions for calculating angles between pose landmarks
/// Designed to work with MLKit pose detection outputs (DetectionBox coordinates)
class PoseAngleUtils {
  /// Convert DetectionBox to a simple point (x, y) using center coordinates
  static Point<double> boxToPoint(DetectionBox box) {
    return Point<double>(
      box.x + box.width / 2.0,  // center x
      box.y + box.height / 2.0, // center y
    );
  }

  /// Find the angle between two points (in degrees)
  /// Returns the angle from point1 to point2 measured from the positive x-axis
  /// Range: 0 to 360 degrees (0° = right, 90° = up, 180° = left, 270° = down)
  /// 
  /// Example:
  /// ```dart
  /// final shoulder = DetectionBox(x: 0.3, y: 0.2, width: 0.01, height: 0.01);
  /// final hip = DetectionBox(x: 0.3, y: 0.5, width: 0.01, height: 0.01);
  /// final angle = PoseAngleUtils.angleBetweenPoints(shoulder, hip);
  /// // Result: 270° (pointing straight down)
  /// ```
  static double angleBetweenPoints(DetectionBox point1, DetectionBox point2) {
    final p1 = boxToPoint(point1);
    final p2 = boxToPoint(point2);
    
    final deltaX = p2.x - p1.x;
    final deltaY = p2.y - p1.y;
    
    // atan2 returns radians in range [-π, π]
    // Convert to degrees and normalize to [0, 360]
    double angleRadians = math.atan2(deltaY, deltaX);
    double angleDegrees = angleRadians * 180.0 / math.pi;
    
    // Normalize to 0-360 range
    if (angleDegrees < 0) {
      angleDegrees += 360.0;
    }
    
    return angleDegrees;
  }

  /// Find the angle between a point and the positive x-axis (horizontal right)
  /// Uses the origin (0,0) as the reference point
  /// Range: 0 to 360 degrees
  /// 
  /// Example:
  /// ```dart
  /// final point = DetectionBox(x: 0.5, y: 0.3, width: 0.01, height: 0.01);
  /// final angle = PoseAngleUtils.angleWithXAxis(point);
  /// // Result: angle of the line from origin to point
  /// ```
  static double angleWithXAxis(DetectionBox point) {
    final origin = DetectionBox(x: 0.0, y: 0.0, width: 0.0, height: 0.0);
    return angleBetweenPoints(origin, point);
  }

  /// Find the angle between a point and the positive y-axis (vertical up)
  /// Uses the origin (0,0) as the reference point
  /// Range: 0 to 360 degrees
  /// 
  /// Note: In image coordinates, y typically increases downward, so this measures
  /// angle relative to the downward y-axis direction
  /// 
  /// Example:
  /// ```dart
  /// final point = DetectionBox(x: 0.3, y: 0.5, width: 0.01, height: 0.01);
  /// final angle = PoseAngleUtils.angleWithYAxis(point);
  /// // Result: angle of the line from origin to point relative to y-axis
  /// ```
  static double angleWithYAxis(DetectionBox point) {
    // For y-axis, we want angle relative to vertical (0,1) direction
    // This is equivalent to measuring from x-axis and subtracting 90°
    double angleFromX = angleWithXAxis(point);
    double angleFromY = angleFromX - 90.0;
    
    // Normalize to 0-360 range
    if (angleFromY < 0) {
      angleFromY += 360.0;
    }
    
    return angleFromY;
  }

  /// Helper function: Calculate the angle at a joint between three points
  /// This calculates the interior angle at the middle point (joint)
  /// Range: 0 to 180 degrees
  /// 
  /// Example for hip angle:
  /// ```dart
  /// final shoulder = DetectionBox(...);  // Point above hip
  /// final hip = DetectionBox(...);       // Joint point
  /// final knee = DetectionBox(...);      // Point below hip
  /// final hipAngle = PoseAngleUtils.jointAngle(shoulder, hip, knee);
  /// // Result: interior angle at the hip joint
  /// ```
  static double jointAngle(DetectionBox point1, DetectionBox joint, DetectionBox point2) {
    final p1 = boxToPoint(point1);
    final pJoint = boxToPoint(joint);
    final p2 = boxToPoint(point2);
    
    // Create vectors from joint to each point
    final v1x = p1.x - pJoint.x;
    final v1y = p1.y - pJoint.y;
    final v2x = p2.x - pJoint.x;
    final v2y = p2.y - pJoint.y;
    
    // Calculate magnitudes
    final mag1 = math.sqrt(v1x * v1x + v1y * v1y);
    final mag2 = math.sqrt(v2x * v2x + v2y * v2y);
    
    if (mag1 == 0 || mag2 == 0) {
      return 0.0; // Invalid input, points are coincident
    }
    
    // Calculate dot product
    final dot = v1x * v2x + v1y * v2y;
    
    // Calculate angle using dot product formula
    var cosTheta = dot / (mag1 * mag2);
    
    // Clamp to handle numerical precision issues
    cosTheta = cosTheta.clamp(-1.0, 1.0);
    
    // Convert from radians to degrees
    final angleRadians = math.acos(cosTheta);
    final angleDegrees = angleRadians * 180.0 / math.pi;
    
    return angleDegrees;
  }
}

/// Simple 2D point class for internal calculations
class Point<T extends num> {
  final T x;
  final T y;
  
  const Point(this.x, this.y);
  
  @override
  String toString() => 'Point($x, $y)';
}