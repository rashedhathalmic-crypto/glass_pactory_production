import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:glass_pactory_production/core/constants/firestore_constants.dart';
import 'package:glass_pactory_production/firebase_options.dart';
import 'package:glass_pactory_production/models/enums/order_status.dart';
import 'package:glass_pactory_production/services/dashboard_service.dart';
import 'package:glass_pactory_production/services/production_order_repository.dart';
import 'package:glass_pactory_production/services/user_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;
  final orders = firestore.collection(FirestoreConstants.productionOrders);

  final checks = <Future<void>>[
    _runCheck('dashboardService.loadStats', () async {
      final repo = ProductionOrderRepository(firestore);
      final summaries = await repo.fetchDepartmentOrderSummaries();
      await DashboardService(repo, UserRepository(firestore, FirebaseAuth.instance))
          .loadStats(asOf: DateTime.now(), departmentSummaries: summaries);
    }),
    _runCheck('countTotalOrders', () async {
      await ProductionOrderRepository(firestore).countTotalOrders();
    }),
    _runCheck('countOverdueOrders', () async {
      await ProductionOrderRepository(firestore).countOverdueOrders(
        asOf: DateTime.now(),
      );
    }),
    _runCheck('fetchDepartmentOrderSummaries', () async {
      await ProductionOrderRepository(firestore).fetchDepartmentOrderSummaries();
    }),
    _runCheck('watchRecentOrders (get)', () async {
      await orders.orderBy('createdAt', descending: true).limit(10).get();
    }),
    _runCheck('department orders status whereIn', () async {
      await orders
          .where(
            'status',
            whereIn: [
              OrderStatus.inProgress.name,
              OrderStatus.onHold.name,
            ],
          )
          .limit(100)
          .get();
    }),
    _runCheck('countActiveUsers', () async {
      await UserRepository(firestore, FirebaseAuth.instance).countActiveUsers();
    }),
    _runCheck('fetchOrdersPage no status', () async {
      await ProductionOrderRepository(firestore).fetchOrdersPage();
    }),
    _runCheck('fetchOrdersPage with status', () async {
      await ProductionOrderRepository(firestore).fetchOrdersPage(
        status: OrderStatus.inProgress,
      );
    }),
  ];

  var failed = false;
  for (final check in checks) {
    try {
      await check;
    } catch (_) {
      failed = true;
    }
  }

  if (failed) {
    // ignore: avoid_print
    print('\nOne or more Firestore queries failed.');
  } else {
    // ignore: avoid_print
    print('\nAll dashboard/department/order queries succeeded.');
  }
}

Future<void> _runCheck(String name, Future<void> Function() action) async {
  try {
    await action();
    // ignore: avoid_print
    print('OK  $name');
  } on FirebaseException catch (e) {
    // ignore: avoid_print
    print('FAIL $name -> ${e.code}: ${e.message}');
    rethrow;
  } catch (e) {
    // ignore: avoid_print
    print('FAIL $name -> $e');
    rethrow;
  }
}
