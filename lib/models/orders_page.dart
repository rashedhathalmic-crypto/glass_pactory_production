import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/production_order.dart';

class OrdersPage {
  const OrdersPage({
    required this.orders,
    required this.hasMore,
    this.lastDocument,
  });

  final List<ProductionOrder> orders;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
}
