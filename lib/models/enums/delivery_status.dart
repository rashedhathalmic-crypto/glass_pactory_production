enum DeliveryStatus {
  pending,
  ready,
  inTransit,
  delivered,
  confirmed;

  String get label => switch (this) {
        DeliveryStatus.pending => 'Pending',
        DeliveryStatus.ready => 'Ready for Delivery',
        DeliveryStatus.inTransit => 'In Transit',
        DeliveryStatus.delivered => 'Delivered',
        DeliveryStatus.confirmed => 'Customer Confirmed',
      };

  static DeliveryStatus fromString(String value) {
    return DeliveryStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => DeliveryStatus.pending,
    );
  }
}
