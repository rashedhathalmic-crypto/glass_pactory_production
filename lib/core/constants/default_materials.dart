import '../../models/order_material.dart';

class DefaultMaterials {
  DefaultMaterials._();

  static const List<String> names = [
    'Glass',
    'Polycarbonate',
    'PVB',
    'EVA',
    'TPU',
    'Silicone',
    'Spacer',
    'Edge Seal',
  ];

  static List<OrderMaterial> initialList() {
    return names
        .map(
          (name) => OrderMaterial(
            name: name,
            quantity: 0,
            unit: 'pcs',
            isDefault: true,
          ),
        )
        .toList();
  }
}
