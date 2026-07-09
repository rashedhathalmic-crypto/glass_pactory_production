import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/helpers/department_stats_helper.dart';
import '../core/helpers/parse_helpers.dart';
import '../core/constants/default_materials.dart';
import '../core/constants/firestore_constants.dart';
import '../core/helpers/polygon_area_helper.dart';
import '../models/department_order_summary.dart';
import '../models/enums/department.dart';
import '../models/enums/department_stage_status.dart';
import '../models/enums/order_priority.dart';
import '../models/enums/order_status.dart';
import '../models/enums/order_type.dart';
import '../models/order_material.dart';
import '../models/orders_page.dart';
import '../models/production_order.dart';
import '../utils/exceptions/exceptions.dart';

class ProductionOrderRepository {
  ProductionOrderRepository(this._firestore);

  final FirebaseFirestore _firestore;
  static const int defaultPageSize = 50;
  static const int departmentOrdersLimit = 100;

  final Set<String> _migrationAttempted = {};

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection(FirestoreConstants.productionOrders);

  DocumentReference<Map<String, dynamic>> get _counterRef => _firestore
      .collection(FirestoreConstants.counters)
      .doc(FirestoreConstants.orderCounter);

  Future<String> _generateOrderNumber() async {
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(_counterRef);
      final current = ParseHelpers.parseInt(snapshot.data()?['value']);
      final next = current + 1;
      transaction.set(_counterRef, {'value': next}, SetOptions(merge: true));
      final year = DateTime.now().year;
      return 'GF-$year-${next.toString().padLeft(5, '0')}';
    });
  }

  Stream<List<ProductionOrder>> watchRecentOrders({int limit = 10}) {
    return _ordersRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(_mapDocumentWithoutMigration).toList(),
        );
  }

  Future<OrdersPage> fetchOrdersPage({
    int limit = defaultPageSize,
    OrderStatus? status,
    String searchQuery = '',
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    try {
      final trimmedSearch = searchQuery.trim();

      if (trimmedSearch.isNotEmpty) {
        final term = trimmedSearch.toUpperCase();
        final snapshot = await _ordersRef
            .where('orderNumber', isGreaterThanOrEqualTo: term)
            .where('orderNumber', isLessThan: '$term\uf8ff')
            .limit(limit)
            .get();
        final orders = snapshot.docs.map(_mapDocumentWithoutMigration).toList();
        return OrdersPage(
          orders: _applyClientFilters(orders, status: status, search: trimmedSearch),
          hasMore: false,
        );
      }

      if (status != null) {
        final snapshot = await _ordersRef
            .where('status', isEqualTo: status.name)
            .get();

        final docById = {
          for (final doc in snapshot.docs) doc.id: doc,
        };

        var orders = snapshot.docs.map(_mapDocumentWithoutMigration).toList()
          ..sort((a, b) {
            final aCreated =
                a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bCreated =
                b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bCreated.compareTo(aCreated);
          });

        if (startAfter != null) {
          final startIndex = orders.indexWhere((o) => o.id == startAfter.id);
          if (startIndex >= 0) {
            orders = orders.sublist(startIndex + 1);
          }
        }

        final pageOrders = orders.take(limit).toList();
        final lastOrder = pageOrders.isEmpty ? null : pageOrders.last;

        return OrdersPage(
          orders: _applyClientFilters(
            pageOrders,
            status: status,
            search: trimmedSearch,
          ),
          hasMore: orders.length > limit,
          lastDocument:
              lastOrder == null ? null : docById[lastOrder.id],
        );
      }

      Query<Map<String, dynamic>> query = _ordersRef.orderBy(
        'createdAt',
        descending: true,
      );

      query = query.limit(limit);
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final orders = snapshot.docs.map(_mapDocumentWithoutMigration).toList();
      final lastDoc = snapshot.docs.isEmpty ? null : snapshot.docs.last;

      return OrdersPage(
        orders: orders,
        hasMore: snapshot.docs.length >= limit,
        lastDocument: lastDoc,
      );
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to load orders page',
        code: e.code,
      );
    }
  }

  List<ProductionOrder> _applyClientFilters(
    List<ProductionOrder> orders, {
    OrderStatus? status,
    required String search,
  }) {
    final lower = search.toLowerCase();
    return orders.where((order) {
      final matchesStatus = status == null || order.status == status;
      final matchesSearch =
          order.orderNumber.toLowerCase().contains(lower) ||
          order.customerName.toLowerCase().contains(lower);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  Stream<List<ProductionOrder>> watchOrders({OrderStatus? status}) {
    if (status != null) {
      return _ordersRef
          .where('status', isEqualTo: status.name)
          .snapshots()
          .map((snapshot) {
            final orders = snapshot.docs.map(_mapDocumentWithoutMigration).toList()
              ..sort((a, b) {
                final aCreated =
                    a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                final bCreated =
                    b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                return bCreated.compareTo(aCreated);
              });
            if (orders.length > defaultPageSize) {
              return orders.sublist(0, defaultPageSize);
            }
            return orders;
          });
    }

    return _ordersRef
        .orderBy('createdAt', descending: true)
        .limit(defaultPageSize)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(_mapDocumentWithoutMigration).toList(),
        );
  }

  void _migrateLegacyDocumentIfNeeded(
    String orderId,
    ProductionOrder order,
    Map<String, dynamic> raw,
  ) {
    if (_migrationAttempted.contains(orderId)) return;
    if (!order.needsLegacyMigration(raw)) return;
    _migrationAttempted.add(orderId);
    _ordersRef.doc(orderId).update({
      ...order.legacyMigrationPatch(raw),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }).catchError((_) {});
  }

  ProductionOrder _mapDocumentWithoutMigration(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ProductionOrder.fromMap(doc.id, doc.data() ?? {});
  }

  ProductionOrder _mapDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final order = ProductionOrder.fromMap(doc.id, data);
    _migrateLegacyDocumentIfNeeded(doc.id, order, data);
    return order;
  }

  Stream<List<ProductionOrder>> watchOrdersByDepartment(Department department) {
    // Query by status only to avoid composite Firestore indexes; filter and sort
    // by department client-side. Also picks up legacy department keys until migrated.
    return _ordersRef
        .where(
          'status',
          whereIn: [
            OrderStatus.inProgress.name,
            OrderStatus.onHold.name,
          ],
        )
        .limit(departmentOrdersLimit * 5)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map(_mapDocument)
              .where((order) => order.currentDepartment == department)
              .toList()
            ..sort(_compareDepartmentOrders);

          if (orders.length > departmentOrdersLimit) {
            return orders.sublist(0, departmentOrdersLimit);
          }
          return orders;
        });
  }

  int _compareDepartmentOrders(ProductionOrder a, ProductionOrder b) {
    final priorityCompare = a.priority.index.compareTo(b.priority.index);
    if (priorityCompare != 0) return priorityCompare;

    final aDue = a.dueDate ?? DateTime(2100);
    final bDue = b.dueDate ?? DateTime(2100);
    return aDue.compareTo(bDue);
  }

  Stream<ProductionOrder?> watchOrder(String orderId) {
    return _ordersRef.doc(orderId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return _mapDocumentWithoutMigration(doc);
    });
  }

  Future<ProductionOrder?> getOrder(String orderId) async {
    try {
      final doc = await _ordersRef.doc(orderId).get();
      if (!doc.exists) return null;
      return _mapDocument(doc);
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to load order',
        code: e.code,
      );
    }
  }

  Future<List<ProductionOrder>> getAllOrders({int limit = 200}) async {
    final snapshot = await _ordersRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(_mapDocumentWithoutMigration).toList();
  }

  Future<int> countTotalOrders() => _countQuery(_ordersRef);

  Future<int> countByStatus(OrderStatus status) {
    return _countQuery(
      _ordersRef.where('status', isEqualTo: status.name),
    );
  }

  Future<int> countOverdueOrders({required DateTime asOf}) async {
    try {
      final snapshot = await _ordersRef
          .where(
            'status',
            whereIn: [
              OrderStatus.inProgress.name,
              OrderStatus.onHold.name,
              OrderStatus.draft.name,
            ],
          )
          .get();

      return snapshot.docs.map(_mapDocumentWithoutMigration).where((order) {
        final due = order.dueDate;
        return due != null && due.isBefore(asOf);
      }).length;
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to count overdue orders',
        code: e.code,
      );
    }
  }

  Future<int> countInDepartment(Department department, OrderStatus status) async {
    try {
      final snapshot = await _ordersRef
          .where('status', isEqualTo: status.name)
          .get();

      return snapshot.docs
          .map(_mapDocumentWithoutMigration)
          .where((order) => order.currentDepartment == department)
          .length;
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to count orders in department',
        code: e.code,
      );
    }
  }

  Future<Map<Department, int>> countActiveByDepartment() async {
    final summaries = await fetchDepartmentOrderSummaries();
    return {
      for (final summary in summaries)
        summary.department: summary.activeCount + summary.pendingCount,
    };
  }

  /// Single query for all department workload stats (replaces per-dept aggregations).
  Future<List<DepartmentOrderSummary>> fetchDepartmentOrderSummaries() async {
    try {
      final snapshot = await _ordersRef
          .where(
            'status',
            whereIn: DepartmentStatsHelper.trackedStatuses
                .map((status) => status.name)
                .toList(),
          )
          .get();

      final orders = snapshot.docs.map(_mapDocumentWithoutMigration);
      return DepartmentStatsHelper.summarizeByDepartment(orders);
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to load department summaries',
        code: e.code,
      );
    }
  }

  Future<int> _countQuery(Query<Map<String, dynamic>> query) async {
    try {
      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to count orders',
        code: e.code,
      );
    }
  }

  Future<List<ProductionOrder>> getOrdersForReport({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 500,
  }) async {
    final snapshot = await _ordersRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    var orders = snapshot.docs.map(_mapDocumentWithoutMigration).toList();

    if (startDate != null) {
      orders = orders
          .where(
            (order) =>
                order.createdAt != null && !order.createdAt!.isBefore(startDate),
          )
          .toList();
    }

    if (endDate != null) {
      orders = orders
          .where(
            (order) =>
                order.createdAt != null && !order.createdAt!.isAfter(endDate),
          )
          .toList();
    }

    return orders;
  }

  Future<ProductionOrder> createOrder({
    required String customerName,
    required String glassType,
    required String drawingNumber,
    required double thicknessMm,
    required int quantity,
    required int polygonSides,
    required List<double> polygonSideLengthsMm,
    required String createdBy,
    String description = '',
    String projectName = '',
    OrderPriority priority = OrderPriority.normal,
    DateTime? dueDate,
    List<OrderMaterial>? materials,
    String pdfUrl = '',
    String dxfUrl = '',
  }) async {
    try {
      final orderNumber = await _generateOrderNumber();
      final now = DateTime.now();
      final docRef = _ordersRef.doc();

      final statuses = ProductionOrder.initialDepartmentStatuses();
      statuses[Department.glassProcessing.name] =
          DepartmentStageStatus.active.name;

      final areaSqM = PolygonAreaHelper.calculateAreaSqM(
        sides: polygonSides,
        sideLengthsMm: polygonSideLengthsMm,
      );

      final order = ProductionOrder(
        id: docRef.id,
        orderNumber: orderNumber,
        customerName: customerName.trim(),
        glassType: glassType.trim(),
        drawingNumber: drawingNumber.trim(),
        thicknessMm: thicknessMm,
        quantity: quantity,
        polygonSides: polygonSides,
        polygonSideLengthsMm: polygonSideLengthsMm,
        areaSqM: areaSqM,
        pdfUrl: pdfUrl,
        dxfUrl: dxfUrl,
        materials: materials ?? DefaultMaterials.initialList(),
        status: OrderStatus.inProgress,
        priority: priority,
        currentDepartment: Department.glassProcessing,
        departmentStatuses: statuses,
        workflowData: ProductionOrder.initialWorkflowData(),
        description: description.trim(),
        projectName: projectName.trim(),
        dueDate: dueDate,
        startedAt: now,
        createdAt: now,
        updatedAt: now,
        createdBy: createdBy,
      );

      await docRef.set(order.toMap());
      return order;
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to create order',
        code: e.code,
      );
    }
  }

  Future<ProductionOrder> createReworkOrder({
    required ProductionOrder parentOrder,
    required int quantity,
    required List<String> rejectReasons,
    required String createdBy,
  }) async {
    try {
      final orderNumber = await _generateOrderNumber();
      final now = DateTime.now();
      final docRef = _ordersRef.doc();

      final statuses = ProductionOrder.initialDepartmentStatuses();
      statuses[Department.glassProcessing.name] =
          DepartmentStageStatus.active.name;

      final reasonText = rejectReasons.isEmpty
          ? 'Rework from ${parentOrder.orderNumber}'
          : rejectReasons.join('; ');

      final order = ProductionOrder(
        id: docRef.id,
        orderNumber: orderNumber,
        customerName: parentOrder.customerName,
        glassType: parentOrder.glassType,
        drawingNumber: parentOrder.drawingNumber,
        thicknessMm: parentOrder.thicknessMm,
        quantity: quantity,
        polygonSides: parentOrder.polygonSides,
        polygonSideLengthsMm: parentOrder.polygonSideLengthsMm,
        areaSqM: parentOrder.areaSqM,
        pdfUrl: parentOrder.pdfUrl,
        dxfUrl: parentOrder.dxfUrl,
        materials: parentOrder.materials,
        status: OrderStatus.inProgress,
        priority: OrderPriority.high,
        currentDepartment: Department.glassProcessing,
        departmentStatuses: statuses,
        workflowData: ProductionOrder.initialWorkflowData(),
        description: 'Rework order for ${parentOrder.orderNumber}',
        notes: reasonText,
        dueDate: parentOrder.dueDate,
        startedAt: now,
        createdAt: now,
        updatedAt: now,
        createdBy: createdBy,
        orderType: OrderType.rework,
        parentOrderId: parentOrder.id,
      );

      await docRef.set(order.toMap());
      return order;
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to create rework order',
        code: e.code,
      );
    }
  }

  Future<void> updateOrder(ProductionOrder order) async {
    try {
      await _ordersRef.doc(order.id).update({
        ...order.copyWith(updatedAt: DateTime.now()).toMap(),
      });
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to update order',
        code: e.code,
      );
    }
  }

  Future<void> deleteOrder(String orderId) async {
    try {
      await _ordersRef.doc(orderId).delete();
    } on FirebaseException catch (e) {
      throw FirestoreException(
        e.message ?? 'Failed to delete order',
        code: e.code,
      );
    }
  }

  Future<Map<OrderStatus, int>> countAllByStatus() async {
    final counts = <OrderStatus, int>{};
    await Future.wait(
      OrderStatus.values.map((status) async {
        counts[status] = await countByStatus(status);
      }),
    );
    return counts;
  }

  Future<Map<Department, int>> countByDepartment() async {
    return countActiveByDepartment();
  }
}
