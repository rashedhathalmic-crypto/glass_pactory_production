enum OrderStatus {
  draft,
  inProgress,
  onHold,
  completed,
  cancelled;

  String get label => switch (this) {
    OrderStatus.draft => 'Draft',
    OrderStatus.inProgress => 'In Progress',
    OrderStatus.onHold => 'On Hold',
    OrderStatus.completed => 'Completed',
    OrderStatus.cancelled => 'Cancelled',
  };

  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => OrderStatus.draft,
    );
  }
}
