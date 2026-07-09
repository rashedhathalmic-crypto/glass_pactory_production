enum MessageType {
  general,
  urgent,
  workInstruction,
  reviewRequest,
  newProductionOrder,
  delayedOrder,
  reworkCreated,
  maintenanceNotice;

  String get label => switch (this) {
        MessageType.general => 'General',
        MessageType.urgent => 'Urgent',
        MessageType.workInstruction => 'Work Instruction',
        MessageType.reviewRequest => 'Review Request',
        MessageType.newProductionOrder => 'New Production Order',
        MessageType.delayedOrder => 'Delayed Order',
        MessageType.reworkCreated => 'Rework Created',
        MessageType.maintenanceNotice => 'Maintenance Notice',
      };

  static MessageType fromString(String value) {
    return MessageType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => MessageType.general,
    );
  }
}
