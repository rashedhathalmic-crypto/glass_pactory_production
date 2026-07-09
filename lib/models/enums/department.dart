enum Department {
  glassProcessing,
  grindingWashing,
  assemblyAutoclave,
  quality,
  finishedDelivery;

  String get label => switch (this) {
        Department.glassProcessing => 'Glass Processing',
        Department.grindingWashing => 'Grinding & Washing',
        Department.assemblyAutoclave => 'Assembly & Autoclave',
        Department.quality => 'Quality',
        Department.finishedDelivery => 'Finished & Delivery',
      };

  String get shortLabel => switch (this) {
        Department.glassProcessing => 'Glass Processing',
        Department.grindingWashing => 'Grinding',
        Department.assemblyAutoclave => 'Assembly',
        Department.quality => 'Quality',
        Department.finishedDelivery => 'Delivery',
      };

  int get sequenceOrder => index;

  Department? get next {
    final nextIndex = index + 1;
    if (nextIndex >= Department.values.length) return null;
    return Department.values[nextIndex];
  }

  Department? get previous {
    final prevIndex = index - 1;
    if (prevIndex < 0) return null;
    return Department.values[prevIndex];
  }

  /// Maps legacy Firestore department keys to the current workflow.
  static String normalizeStorageKey(String value) {
    if (values.any((department) => department.name == value)) {
      return value;
    }
    return Department.glassProcessing.name;
  }

  static Department fromString(String value) {
    final normalized = normalizeStorageKey(value);
    return Department.values.firstWhere(
      (dept) => dept.name == normalized,
      orElse: () => Department.glassProcessing,
    );
  }

  static List<Department> get productionFlow => Department.values;
}
