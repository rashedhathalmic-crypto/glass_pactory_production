import '../models/drawing_archive_item.dart';
import '../models/production_order.dart';
import 'production_order_repository.dart';

class DrawingArchiveService {
  DrawingArchiveService(this._orderRepository);

  final ProductionOrderRepository _orderRepository;

  Future<List<DrawingArchiveItem>> fetchDrawings({
    String search = '',
    String customer = '',
    String project = '',
    int limit = 200,
  }) async {
    final orders = await _orderRepository.getAllOrders(limit: limit);
    final items = orders
        .where((order) => order.pdfUrl.isNotEmpty || order.dxfUrl.isNotEmpty)
        .map(_toArchiveItem)
        .toList();

    return _applyFilters(
      items,
      search: search,
      customer: customer,
      project: project,
    );
  }

  DrawingArchiveItem _toArchiveItem(ProductionOrder order) {
    return DrawingArchiveItem(
      orderId: order.id,
      orderNumber: order.orderNumber,
      customerName: order.customerName,
      projectName: order.projectName,
      drawingNumber: order.drawingNumber,
      glassType: order.glassType,
      pdfUrl: order.pdfUrl,
      dxfUrl: order.dxfUrl,
      createdAt: order.createdAt,
    );
  }

  List<DrawingArchiveItem> _applyFilters(
    List<DrawingArchiveItem> items, {
    required String search,
    required String customer,
    required String project,
  }) {
    final searchLower = search.trim().toLowerCase();
    final customerLower = customer.trim().toLowerCase();
    final projectLower = project.trim().toLowerCase();

    return items.where((item) {
      final matchesSearch = searchLower.isEmpty ||
          item.orderNumber.toLowerCase().contains(searchLower) ||
          item.drawingNumber.toLowerCase().contains(searchLower) ||
          item.customerName.toLowerCase().contains(searchLower) ||
          item.projectName.toLowerCase().contains(searchLower);
      final matchesCustomer = customerLower.isEmpty ||
          item.customerName.toLowerCase().contains(customerLower);
      final matchesProject = projectLower.isEmpty ||
          item.projectName.toLowerCase().contains(projectLower);
      return matchesSearch && matchesCustomer && matchesProject;
    }).toList();
  }
}
