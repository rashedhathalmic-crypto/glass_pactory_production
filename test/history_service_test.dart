import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_pactory_production/models/enums/history_action.dart';
import 'package:glass_pactory_production/models/order_history_entry.dart';

void main() {
  test('watchOrderHistory queries by orderId only without Firestore orderBy',
      () {
    final source =
        File('lib/services/history_service.dart').readAsStringSync();
    final watchStart = source.indexOf('watchOrderHistory(');
    final sortHelperStart = source.indexOf('_sortAndLimitHistory', watchStart);

    expect(watchStart, greaterThan(-1));
    expect(sortHelperStart, greaterThan(watchStart));

    final watchBlock = source.substring(watchStart, sortHelperStart);
    expect(watchBlock, contains(".where('orderId', isEqualTo: orderId)"));
    expect(watchBlock, contains('.snapshots()'));
    expect(watchBlock, isNot(contains("orderBy('timestamp'")));
  });

  test('getOrderHistory queries by orderId only without Firestore orderBy', () {
    final source =
        File('lib/services/history_service.dart').readAsStringSync();
    final getStart = source.indexOf('getOrderHistory(');
    final sortHelperStart = source.indexOf('_sortAndLimitHistory', getStart);

    expect(getStart, greaterThan(-1));
    expect(sortHelperStart, greaterThan(getStart));

    final getBlock = source.substring(getStart, sortHelperStart);
    expect(getBlock, contains(".where('orderId', isEqualTo: orderId)"));
    expect(getBlock, contains('.get()'));
    expect(getBlock, isNot(contains("orderBy('timestamp'")));
  });

  test('history entries sort newest first with null timestamps last', () {
    final entries = [
      OrderHistoryEntry(
        id: '1',
        orderId: 'o1',
        action: HistoryAction.created,
        performedBy: 'u1',
        performedByName: 'User 1',
        timestamp: DateTime(2024, 1, 1),
      ),
      OrderHistoryEntry(
        id: '2',
        orderId: 'o1',
        action: HistoryAction.updated,
        performedBy: 'u1',
        performedByName: 'User 1',
        timestamp: DateTime(2024, 6, 1),
      ),
      OrderHistoryEntry(
        id: '3',
        orderId: 'o1',
        action: HistoryAction.updated,
        performedBy: 'u1',
        performedByName: 'User 1',
      ),
    ]..sort((a, b) {
        final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

    expect(entries.first.id, '2');
    expect(entries.last.id, '3');
  });
}
