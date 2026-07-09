enum UserRole {
  admin,
  manager,
  supervisor,
  operator,
  qualityInspector,
  warehouseDelivery;

  String get label => switch (this) {
        UserRole.admin => 'Admin',
        UserRole.manager => 'Production Manager',
        UserRole.supervisor => 'Department Supervisor',
        UserRole.operator => 'Operator',
        UserRole.qualityInspector => 'Quality Inspector',
        UserRole.warehouseDelivery => 'Warehouse / Delivery',
      };

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => UserRole.operator,
    );
  }
}
