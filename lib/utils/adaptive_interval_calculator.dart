/// Adaptive interval calculator for optimizing inference timing
class AdaptiveIntervalCalculator {
  // Configuration parameters
  final int maxSamples;
  final double multiplier;
  final int minInterval;
  final int maxInterval;
  final double changeThreshold;
  
  // Internal state
  final List<int> _inferenceTimes = [];
  final Stopwatch _stopwatch = Stopwatch();
  int _lastInferenceTime = 0;
  
  /// Creates an adaptive interval calculator with configurable parameters.
  /// 
  /// [maxSamples] - How many recent inference times to keep for averaging (default: 10)
  /// [multiplier] - Multiplier for inference time to calculate target interval (default: 2.0)
  /// [minInterval] - Minimum allowed interval in milliseconds (default: 100)
  /// [maxInterval] - Maximum allowed interval in milliseconds (default: 5000)
  /// [changeThreshold] - Minimum percentage change to trigger adjustment (default: 0.2 = 20%)
  AdaptiveIntervalCalculator({
    this.maxSamples = 10,
    this.multiplier = 1.5,
    this.minInterval = 1000,
    this.maxInterval = 5000,
    this.changeThreshold = 0.2,
  });

  /// Start timing an inference
  void startTiming() {
    _stopwatch.reset();
    _stopwatch.start();
  }

  /// Stop timing and automatically add the sample.
  void stopTiming() {
    _stopwatch.stop();
    final inferenceTimeMs = _stopwatch.elapsedMilliseconds;
    _lastInferenceTime = inferenceTimeMs;
    _inferenceTimes.add(inferenceTimeMs);
    
    // Keep only the most recent samples
    if (_inferenceTimes.length > maxSamples) {
      _inferenceTimes.removeAt(0);
    }
  }

  /// Calculate new interval based on current performance.
  /// Returns the recommended interval (which may be the same as current if no change is needed).
  int calculateNewInterval(int currentInterval) {
    // Need at least 3 samples for reliable calculation
    if (_inferenceTimes.length < 3) {
      return currentInterval;
    }

    // Calculate average of recent inference times
    final average = _inferenceTimes.reduce((a, b) => a + b) / _inferenceTimes.length;
    
    // Calculate target interval (inference time * multiplier)
    final targetInterval = (average * multiplier).round();
    
    // Clamp to our allowed range
    final clampedTarget = targetInterval.clamp(minInterval, maxInterval);
    
    // Only change if the difference is significant enough
    final percentageChange = (clampedTarget - currentInterval).abs() / currentInterval;
    if (percentageChange < changeThreshold) {
      return currentInterval; // No significant change needed
    }
    
    return clampedTarget;
  }

  /// Reset all samples
  void reset() {
    _inferenceTimes.clear();
  }

  int get sampleCount => _inferenceTimes.length;
  
  double get averageInferenceTime => 
      _inferenceTimes.isEmpty ? 0 : _inferenceTimes.reduce((a, b) => a + b) / _inferenceTimes.length;
    
  int get lastInferenceTime => _lastInferenceTime;
}