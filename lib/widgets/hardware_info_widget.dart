import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'dart:io';

/// Comprehensive hardware information widget that displays all available
/// raw device specifications using device_info_plus
class HardwareInfoWidget extends StatefulWidget {
  const HardwareInfoWidget({super.key});

  @override
  State<HardwareInfoWidget> createState() => _HardwareInfoWidgetState();
}

class _HardwareInfoWidgetState extends State<HardwareInfoWidget> {
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  
  Map<String, dynamic> _keyInfo = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _getDeviceInfo();
  }

  Future<void> _getDeviceInfo() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      Map<String, dynamic> keyInfo = {};

      if (Platform.isAndroid) {
        keyInfo = await _getAndroidInfo();
      } else if (Platform.isIOS) {
        keyInfo = await _getIOSInfo();
      } else {
        keyInfo = {'platform': 'Unsupported platform'};
      }

      setState(() {
        _keyInfo = keyInfo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting device info: $e';
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _getAndroidInfo() async {
    final androidInfo = await _deviceInfoPlugin.androidInfo;
    
    // Try to get additional system information
    String totalMemory = 'Not available';
    String cpuInfo = 'Not available';
    
    try {
      // Try to get memory info from /proc/meminfo
      final memInfoResult = await Process.run('cat', ['/proc/meminfo']);
      final memLines = memInfoResult.stdout.toString().split('\n');
      final memTotalLine = memLines.firstWhere(
        (line) => line.startsWith('MemTotal:'),
        orElse: () => '',
      );
      if (memTotalLine.isNotEmpty) {
        final memoryString = memTotalLine.split(':')[1].trim();
        // Parse memory from KB to GB
        final memoryKB = RegExp(r'(\d+)').firstMatch(memoryString)?.group(1);
        if (memoryKB != null) {
          final memoryGB = (int.parse(memoryKB) / 1024 / 1024).toStringAsFixed(1);
          totalMemory = '${memoryGB} GB';
        } else {
          totalMemory = memoryString; // Fallback to original format
        }
      }
    } catch (e) {
      totalMemory = 'Unable to determine';
    }
    
    try {
      // Try to get CPU info from /proc/cpuinfo
      final cpuInfoResult = await Process.run('cat', ['/proc/cpuinfo']);
      final cpuLines = cpuInfoResult.stdout.toString().split('\n');
      final processorLines = cpuLines.where((line) => line.startsWith('processor')).toList();
      final modelNameLine = cpuLines.firstWhere(
        (line) => line.contains('model name') || line.contains('Hardware'),
        orElse: () => '',
      );
      cpuInfo = 'Cores: ${processorLines.length}';
      if (modelNameLine.isNotEmpty) {
        cpuInfo += ', ${modelNameLine.split(':')[1].trim()}';
      }
    } catch (e) {
      cpuInfo = 'Unable to determine';
    }
    
    // Key information for inference performance
    return {
      'Device Model': '${androidInfo.brand} ${androidInfo.model}',
      'Manufacturer': androidInfo.manufacturer,
      'Android Version': 'Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})',
      'Architecture': _getArchitectureInfo(androidInfo.supportedAbis),
      'CPU Hardware': androidInfo.hardware,
      'CPU Information': cpuInfo,
      'Total Memory': totalMemory,
      'Performance Tier': _estimatePerformanceTier(androidInfo),
      'Is Physical Device': androidInfo.isPhysicalDevice ? 'Yes' : 'No (Emulator)',
    };
  }
  
  Future<Map<String, dynamic>> _getIOSInfo() async {
    final iosInfo = await _deviceInfoPlugin.iosInfo;
    
    // Key information for inference performance
    return {
      'Device Model': iosInfo.model,
      'Device Name': iosInfo.name,
      'System': '${iosInfo.systemName} ${iosInfo.systemVersion}',
      'Machine': iosInfo.utsname.machine,
      'Is Physical Device': iosInfo.isPhysicalDevice ? 'Yes' : 'No (Simulator)',
      'Localized Model': iosInfo.localizedModel,
    };
  }
  
  String _getArchitectureInfo(List<String> abis) {
    if (abis.contains('arm64-v8a')) return 'ARM64 (High Performance)';
    if (abis.contains('armeabi-v7a')) return 'ARM32 (Standard)';
    if (abis.contains('x86_64')) return 'x86_64 (Emulator/Intel)';
    if (abis.contains('x86')) return 'x86 (Emulator/Intel)';
    return 'Unknown Architecture';
  }
  
  String _estimatePerformanceTier(AndroidDeviceInfo info) {
    // Simple heuristic based on known hardware patterns
    final hardware = info.hardware.toLowerCase();
    final model = info.model.toLowerCase();
    final sdkInt = info.version.sdkInt;
    
    // High-end indicators
    if (hardware.contains('qcom') && (model.contains('8 gen') || model.contains('888') || model.contains('8+'))) {
      return 'High (Flagship)';
    }
    if (hardware.contains('exynos') && (hardware.contains('2200') || hardware.contains('2100'))) {
      return 'High (Flagship)';
    }
    
    // Medium-end indicators  
    if (hardware.contains('qcom') && (model.contains('7 gen') || model.contains('778') || model.contains('765'))) {
      return 'Medium (Mid-range)';
    }
    
    // Basic SDK-based estimation
    if (sdkInt >= 30) return 'Medium (Android 11+)';
    if (sdkInt >= 26) return 'Low (Android 8+)';
    
    return 'Very Low (Legacy)';
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent();
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading device information...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                shadows: [
                  Shadow(
                    blurRadius: 8.0,
                    color: Colors.black26,
                    offset: Offset(1.0, 1.0),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error, 
              size: 48, 
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 8.0,
                  color: Colors.black26,
                  offset: Offset(1.0, 1.0),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading device info',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 8.0,
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(1.0, 1.0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                shadows: [
                  Shadow(
                    blurRadius: 6.0,
                    color: Colors.black.withValues(alpha: 0.2),
                    offset: const Offset(1.0, 1.0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _getDeviceInfo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFA855F7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.3),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const Icon(
                Icons.star, 
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
              Expanded(
                child: Text(
                  'Key Hardware Information',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black.withValues(alpha: 0.3),
                        offset: const Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: IconButton(
                  onPressed: _getDeviceInfo,
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 20,
                  ),
                  tooltip: 'Refresh Device Info',
                ),
              ),
            ],
          ),
        ),
        
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildInfoTable(_keyInfo),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInfoTable(Map<String, dynamic> data) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(3),
      },
      children: data.entries.map((entry) {
        return TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 14,
                  shadows: [
                    Shadow(
                      blurRadius: 6.0,
                      color: Colors.black.withValues(alpha: 0.2),
                      offset: const Offset(1.0, 1.0),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SelectableText(
                entry.value.toString(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.9),
                  shadows: [
                    Shadow(
                      blurRadius: 4.0,
                      color: Colors.black.withValues(alpha: 0.15),
                      offset: const Offset(0.5, 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
