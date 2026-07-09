enum OrderPriority {
  low,
  normal,
  high,
  urgent;

  String get label => switch (this) {
    OrderPriority.low => 'Low',
    OrderPriority.normal => 'Normal',
    OrderPriority.high => 'High',
    OrderPriority.urgent => 'Urgent',
  };

  static OrderPriority fromString(String value) {
    return OrderPriority.values.firstWhere(
      (priority) => priority.name == value,
      orElse: () => OrderPriority.normal,
    );
  }
}
