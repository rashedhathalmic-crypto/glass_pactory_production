import '../core/helpers/parse_helpers.dart';

class OrderMaterial {
  const OrderMaterial({
    required this.name,
    required this.quantity,
    required this.unit,
    this.isDefault = false,
  });

  final String name;
  final double quantity;
  final String unit;
  final bool isDefault;

  OrderMaterial copyWith({
    String? name,
    double? quantity,
    String? unit,
    bool? isDefault,
  }) {
    return OrderMaterial(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'isDefault': isDefault,
    };
  }

  factory OrderMaterial.fromMap(Map<String, dynamic> map) {
    return OrderMaterial(
      name: map['name'] as String? ?? '',
      quantity: ParseHelpers.parseDouble(map['quantity']),
      unit: map['unit'] as String? ?? '',
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }
}
