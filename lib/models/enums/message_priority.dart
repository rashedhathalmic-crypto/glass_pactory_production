enum MessagePriority {
  low,
  normal,
  high;

  String get label => switch (this) {
        MessagePriority.low => 'Low',
        MessagePriority.normal => 'Normal',
        MessagePriority.high => 'High',
      };

  static MessagePriority fromString(String value) {
    return MessagePriority.values.firstWhere(
      (priority) => priority.name == value,
      orElse: () => MessagePriority.normal,
    );
  }
}
