enum InspectionStatus {
  notStarted,
  pending,
  passed,
  failed;

  String get label => switch (this) {
    InspectionStatus.notStarted => 'Not Started',
    InspectionStatus.pending => 'Pending Inspection',
    InspectionStatus.passed => 'Passed',
    InspectionStatus.failed => 'Failed',
  };

  static InspectionStatus fromString(String value) {
    return InspectionStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => InspectionStatus.notStarted,
    );
  }
}
