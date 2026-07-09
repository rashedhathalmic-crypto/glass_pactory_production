import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:glass_pactory_production/core/constants/firestore_constants.dart';
import 'package:glass_pactory_production/firebase_options.dart';
import 'package:glass_pactory_production/services/history_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;
  final historyRef = firestore.collection(FirestoreConstants.orderHistory);
  final ordersRef = firestore.collection(FirestoreConstants.productionOrders);
  final historyService = HistoryService(firestore);

  final orderIds = <String>[];
  final ordersSnapshot = await ordersRef.limit(5).get();
  for (final doc in ordersSnapshot.docs) {
    orderIds.add(doc.id);
  }

  if (orderIds.isEmpty) {
    final historySample = await historyRef.limit(3).get();
    for (final doc in historySample.docs) {
      final orderId = doc.data()['orderId'] as String?;
      if (orderId != null && orderId.isNotEmpty) {
        orderIds.add(orderId);
      }
    }
  }

  if (orderIds.isEmpty) {
    // ignore: avoid_print
    print('VERIFY_ORDER_HISTORY: no sample order IDs found');
    return;
  }

  var failures = 0;
  for (final orderId in orderIds.toSet()) {
    try {
      await historyRef.where('orderId', isEqualTo: orderId).get();
      await historyService.getOrderHistory(orderId);
      // ignore: avoid_print
      print('VERIFY_ORDER_HISTORY OK $orderId');
    } on FirebaseException catch (e) {
      failures++;
      // ignore: avoid_print
      print('VERIFY_ORDER_HISTORY FAIL $orderId -> ${e.code}: ${e.message}');
    }
  }

  if (failures == 0) {
    // ignore: avoid_print
    print('VERIFY_ORDER_HISTORY: all ${orderIds.length} order history queries succeeded');
  } else {
    // ignore: avoid_print
    print('VERIFY_ORDER_HISTORY: $failures queries failed');
  }
}
