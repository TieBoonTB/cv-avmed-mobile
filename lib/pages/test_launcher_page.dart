import 'package:flutter/material.dart';
import '../pages/camera_page.dart';
import '../utils/test_controller_factory.dart';

/// Demo page showing how to launch different test types
/// using the new camera page architecture
class TestLauncherPage extends StatelessWidget {
  const TestLauncherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Launcher'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a Test Type',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The new camera page works with any test controller implementation',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // Available test types
            Expanded(
              child: ListView.builder(
                itemCount: TestControllerFactory.getAvailableTestTypes().length,
                itemBuilder: (context, index) {
                  final testType = TestControllerFactory.getAvailableTestTypes()[index];
                  return _buildTestTypeCard(context, testType);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestTypeCard(BuildContext context, TestType testType) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getTestIcon(testType),
                  size: 32,
                  color: Colors.blue,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TestControllerFactory.getTestDisplayName(testType),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        TestControllerFactory.getTestDescription(testType),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Launch buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _launchTest(context, testType, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text('Start Test'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _launchTest(context, testType, true),
                    child: const Text('Trial Mode'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTestIcon(TestType testType) {
    switch (testType) {
      case TestType.objectDetector:
        return Icons.visibility;
      case TestType.sppbChairStand:
        return Icons.accessibility_new;
    }
  }
  void _launchTest(BuildContext context, TestType testType, bool isTrial) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraPage(
          patientCode: 'DEMO_${DateTime.now().millisecondsSinceEpoch}',
          testType: testType,
          isTrial: isTrial,
        ),
      ),
    );
  }
}
