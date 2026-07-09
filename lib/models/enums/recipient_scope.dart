enum RecipientScope {
  singleEmployee,
  department,
  everyone;

  String get label => switch (this) {
        RecipientScope.singleEmployee => 'Single Employee',
        RecipientScope.department => 'Department',
        RecipientScope.everyone => 'Everyone',
      };

  static RecipientScope fromString(String value) {
    return RecipientScope.values.firstWhere(
      (scope) => scope.name == value,
      orElse: () => RecipientScope.everyone,
    );
  }
}
