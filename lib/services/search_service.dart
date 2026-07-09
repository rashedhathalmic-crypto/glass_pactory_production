import '../models/order_filters.dart';
import '../models/production_order.dart';
import '../models/search_result.dart';
import 'production_order_repository.dart';

class SearchService {
  SearchService(this._orderRepository);

  final ProductionOrderRepository _orderRepository;

  Future<List<SearchResult>> search(String query, {int limit = 100}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final orders = await _orderRepository.getAllOrders(limit: limit);
    final lower = trimmed.toLowerCase();
    final results = <SearchResult>[];

    for (final order in orders) {
      if (order.orderNumber.toLowerCase().contains(lower)) {
        results.add(
          SearchResult(
            order: order,
            matchField: 'Order Number',
            matchValue: order.orderNumber,
          ),
        );
        continue;
      }
      if (order.drawingNumber.toLowerCase().contains(lower)) {
        results.add(
          SearchResult(
            order: order,
            matchField: 'Drawing Number',
            matchValue: order.drawingNumber,
          ),
        );
        continue;
      }
      if (order.customerName.toLowerCase().contains(lower)) {
        results.add(
          SearchResult(
            order: order,
            matchField: 'Customer',
            matchValue: order.customerName,
          ),
        );
        continue;
      }
      if (order.projectName.toLowerCase().contains(lower)) {
        results.add(
          SearchResult(
            order: order,
            matchField: 'Project',
            matchValue: order.projectName,
          ),
        );
        continue;
      }
      if (order.id == trimmed || order.orderNumber == trimmed) {
        results.add(
          SearchResult(
            order: order,
            matchField: 'QR / Order ID',
            matchValue: order.orderNumber,
          ),
        );
      }
    }

    return results;
  }

  Future<ProductionOrder?> findByQrOrOrderNumber(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final direct = await _orderRepository.getOrder(trimmed);
    if (direct != null) return direct;

    final orders = await _orderRepository.getAllOrders(limit: 300);
    for (final order in orders) {
      if (order.orderNumber.toLowerCase() == trimmed.toLowerCase() ||
          order.id == trimmed) {
        return order;
      }
    }
    return null;
  }

  List<ProductionOrder> applyFilters(
    List<ProductionOrder> orders,
    OrderFilters filters,
  ) {
    return orders.where((order) {
      if (filters.customer.isNotEmpty &&
          !order.customerName
              .toLowerCase()
              .contains(filters.customer.toLowerCase())) {
        return false;
      }
      if (filters.project.isNotEmpty &&
          !order.projectName
              .toLowerCase()
              .contains(filters.project.toLowerCase())) {
        return false;
      }
      if (filters.glassType.isNotEmpty &&
          !order.glassType
              .toLowerCase()
              .contains(filters.glassType.toLowerCase())) {
        return false;
      }
      if (filters.department != null &&
          order.currentDepartment != filters.department) {
        return false;
      }
      if (filters.status != null && order.status != filters.status) {
        return false;
      }
      if (filters.priority != null && order.priority != filters.priority) {
        return false;
      }
      if (filters.startDate != null &&
          (order.createdAt == null ||
              order.createdAt!.isBefore(filters.startDate!))) {
        return false;
      }
      if (filters.endDate != null &&
          (order.createdAt == null ||
              order.createdAt!.isAfter(filters.endDate!))) {
        return false;
      }
      return true;
    }).toList();
  }
}
