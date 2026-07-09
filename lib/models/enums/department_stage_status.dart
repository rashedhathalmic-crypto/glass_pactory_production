enum DepartmentStageStatus {
  pending,
  active,
  completed,
  skipped;

  String get label => switch (this) {
    DepartmentStageStatus.pending => 'Pending',
    DepartmentStageStatus.active => 'Active',
    DepartmentStageStatus.completed => 'Completed',
    DepartmentStageStatus.skipped => 'Skipped',
  };

  static DepartmentStageStatus fromString(String value) {
    return DepartmentStageStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => DepartmentStageStatus.pending,
    );
  }
}
