import 'package:flutter/material.dart';
import '../widgets/hardware_info_widget.dart';

class DeviceInfoPage extends StatelessWidget {
  const DeviceInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
            shadows: [
              Shadow(
                blurRadius: 8.0,
                color: Colors.black54,
                offset: Offset(1.0, 1.0),
              ),
            ],
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Device Information',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black.withValues(alpha: 0.4),
                offset: const Offset(1.0, 1.0),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.5, -1.0),
            end: Alignment(0.5, 1.0),
            colors: [
              Color(0xFFEC4899), // pink-500
              Color(0xFFA855F7), // purple-500
              Color(0xFF0EA5E9), // sky-500
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.smartphone,
                        color: Colors.white,
                        size: 28,
                        shadows: [
                          Shadow(
                            blurRadius: 8.0,
                            color: Colors.black26,
                            offset: Offset(1.0, 1.0),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Hardware Specifications',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 10.0,
                              color: Colors.black.withValues(alpha: 0.3),
                              offset: const Offset(2.0, 2.0),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Hardware info widget
                const Expanded(
                  child: HardwareInfoWidget(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
