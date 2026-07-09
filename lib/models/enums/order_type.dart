enum OrderType {
  standard,
  rework;

  String get label => switch (this) {
        OrderType.standard => 'Standard',
        OrderType.rework => 'Rework',
      };

  static OrderType fromString(String value) {
    return OrderType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => OrderType.standard,
    );
  }
}
