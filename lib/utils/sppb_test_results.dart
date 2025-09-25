/// SPPB Test Results model extracted from controllers
class SPPBTestResults {
  final bool isSuccessful;
  final int completedRepetitions;
  final double totalTime;
  final double averageRepetitionTime;
  final int sppbScore;
  final double movementSmoothness;
  final List<double> repetitionTimes;

  SPPBTestResults({
    required this.isSuccessful,
    required this.completedRepetitions,
    required this.totalTime,
    required this.averageRepetitionTime,
    required this.sppbScore,
    required this.movementSmoothness,
    required this.repetitionTimes,
  });

  factory SPPBTestResults.failed() {
    return SPPBTestResults(
      isSuccessful: false,
      completedRepetitions: 0,
      totalTime: 0.0,
      averageRepetitionTime: 0.0,
      sppbScore: 0,
      movementSmoothness: 0.0,
      repetitionTimes: [],
    );
  }

  /// Get performance grade based on SPPB score
  String get performanceGrade {
    switch (sppbScore) {
      case 4:
        return 'Excellent';
      case 3:
        return 'Good';
      case 2:
        return 'Fair';
      case 1:
        return 'Poor';
      default:
        return 'Unable to Complete';
    }
  }
}
