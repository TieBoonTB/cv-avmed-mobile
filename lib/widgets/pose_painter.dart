import 'dart:ui';

import 'package:flutter/material.dart';

class PosePainter extends CustomPainter {
  final List<Offset> points;
  final double ratio;

  PosePainter({
    required this.points,
    required this.ratio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isNotEmpty) {
      Paint pointPaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 8;
      var headPaint = Paint()
        ..color = Colors.deepOrange
        ..strokeWidth = 2;
      var leftPaint = Paint()
        ..color = Colors.lightBlue
        ..strokeWidth = 2;
      var rightPaint = Paint()
        ..color = Colors.yellow
        ..strokeWidth = 2;
      var bodyPaint = Paint()
        ..color = Colors.pink
        ..strokeWidth = 2;

      // Helper that safely returns a list of points for given indices.
      List<Offset> safePointsForIndices(List<int> indices) {
        final out = <Offset>[];
        for (final i in indices) {
          if (i >= 0 && i < points.length) out.add(points[i] * ratio);
        }
        return out;
      }

      // Draw available keypoints (limit to first 34 if present).
      final maxPointCount = points.length < 34 ? points.length : 34;
      canvas.drawPoints(
        PointMode.points,
        List<Offset>.generate(maxPointCount, (i) => points[i] * ratio),
        pointPaint,
      );

      canvas.drawPoints(
        PointMode.polygon,
        safePointsForIndices([8, 6, 5, 4, 0, 1, 2, 3, 7]),
        headPaint,
      );
      canvas.drawPoints(
        PointMode.polygon,
        [
          points[10],
          points[9],
        ].map((point) => point * ratio).toList(),
        headPaint,
      );

      canvas.drawPoints(
        PointMode.polygon,
        safePointsForIndices([12, 14, 16, 18, 20, 16]),
        leftPaint,
      );
      canvas.drawPoints(
        PointMode.polygon,
        [
          points[16],
          points[22],
        ].map((point) => point * ratio).toList(),
        leftPaint,
      );
      canvas.drawPoints(
        PointMode.polygon,
        [
          points[24],
          points[26],
          points[28],
          points[32],
          points[30],
          points[28],
  ].map((point) => point * ratio).toList(),
        leftPaint,
      );

      canvas.drawPoints(
        PointMode.polygon,
        safePointsForIndices([11, 13, 15, 17, 19, 15]),
        rightPaint,
      );
      canvas.drawPoints(
        PointMode.polygon,
        [
          points[15],
          points[21],
        ].map((point) => point * ratio).toList(),
        rightPaint,
      );
      canvas.drawPoints(
        PointMode.polygon,
        [
          points[23],
          points[25],
          points[27],
          points[29],
          points[31],
          points[27],
  ].map((point) => point * ratio).toList(),
        rightPaint,
      );

      canvas.drawPoints(
        PointMode.polygon,
        safePointsForIndices([11, 12, 24, 23, 11]),
        bodyPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
