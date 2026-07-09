import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums/department.dart';
import '../models/order_history_entry.dart';
import '../models/production_order.dart';
import '../services/history_service.dart';
import '../services/production_order_repository.dart';

final productionOrderRepositoryProvider = Provider<ProductionOrderRepository>((
  ref,
) {
  return ProductionOrderRepository(FirebaseFirestore.instance);
});

/// Live stream of the 10 most recent orders — dashboard only.
final recentOrdersStreamProvider = StreamProvider<List<ProductionOrder>>((ref) {
  return ref.read(productionOrderRepositoryProvider).watchRecentOrders(limit: 10);
});

final orderStreamProvider = StreamProvider.family<ProductionOrder?, String>((
  ref,
  orderId,
) {
  return ref.read(productionOrderRepositoryProvider).watchOrder(orderId);
});

final departmentOrdersStreamProvider =
    StreamProvider.family<List<ProductionOrder>, Department>((ref, dept) {
      return ref
          .read(productionOrderRepositoryProvider)
          .watchOrdersByDepartment(dept);
    });

final historyServiceProvider = Provider<HistoryService>((ref) {
  return HistoryService(FirebaseFirestore.instance);
});

final orderHistoryStreamProvider =
    StreamProvider.family<List<OrderHistoryEntry>, String>((ref, orderId) {
      return ref.read(historyServiceProvider).watchOrderHistory(orderId);
    });
