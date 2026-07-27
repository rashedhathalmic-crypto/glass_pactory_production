abstract final class RoutePaths {
  static const String login = '/login';
  static const String dashboard = '/';
  static const String orders = '/orders';
  static const String orderDetail = '/orders/:orderId';
  static const String orderCreate = '/orders/create';
  static const String users = '/users';
  static const String departments = '/departments';
  static const String departmentDetail = '/departments/:departmentId';
  static const String reports = '/reports';
  static const String search = '/search';
  static const String drawings = '/drawings';
  static const String notifications = '/notifications';
  static const String qrScan = '/qr-scan';
  static const String management = '/management';
  static const String productionManagement = '/production-management';
  static const String auditLog = '/audit-log';
  static const String ncGenerator = '/nc-generator';
  static const String accessDenied = '/access-denied';

  static String orderDetailPath(String orderId) => '/orders/$orderId';
  static String departmentDetailPath(String departmentId) =>
      '/departments/$departmentId';
}
