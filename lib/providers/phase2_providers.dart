import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard_stats_request.dart';
import '../models/extended_dashboard_stats.dart';
import '../models/internal_message.dart';
import '../models/order_filters.dart';
import '../models/production_report_data.dart';
import '../models/search_result.dart';
import '../models/system_audit_log_entry.dart';
import '../models/drawing_archive_item.dart';
import '../models/enums/report_type.dart';
import '../models/report_period.dart';
import '../services/analytics_service.dart';
import '../services/audit_service.dart';
import '../services/drawing_archive_service.dart';
import '../services/export_service.dart';
import '../services/internal_message_service.dart';
import '../services/production_management_service.dart';
import '../services/search_service.dart';
import 'auth_provider.dart';
import 'dashboard_provider.dart';
import 'production_order_provider.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(
    ref.read(productionOrderRepositoryProvider),
    ref.read(historyServiceProvider),
  );
});

final auditServiceProvider = Provider<AuditService>((ref) {
  return AuditService(FirebaseFirestore.instance);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(FirebaseFirestore.instance);
});

final alertServiceProvider = Provider<AlertService>((ref) {
  return AlertService(FirebaseFirestore.instance);
});

final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService(ref.read(productionOrderRepositoryProvider));
});

final drawingArchiveServiceProvider = Provider<DrawingArchiveService>((ref) {
  return DrawingArchiveService(ref.read(productionOrderRepositoryProvider));
});

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(
    ref.read(productionOrderRepositoryProvider),
    ref.read(searchServiceProvider),
    ref.read(analyticsServiceProvider),
  );
});

final productionManagementServiceProvider =
    Provider<ProductionManagementService>((ref) {
      return ProductionManagementService(
        ref.read(productionOrderRepositoryProvider),
        ref.read(historyServiceProvider),
        ref.read(auditServiceProvider),
      );
    });

final extendedDashboardStatsProvider =
    FutureProvider.family<ExtendedDashboardStats, DashboardStatsRequest>((
      ref,
      request,
    ) async {
      final phase1 = await ref.watch(dashboardStatsProvider(request).future);
      return ref.read(analyticsServiceProvider).buildExtendedStats(
        asOf: request.asOf,
        phase1Stats: phase1,
      );
    });

final notificationsStreamProvider =
    StreamProvider<List<InternalMessage>>((ref) {
      final user = ref.watch(currentAppUserProvider).asData?.value;
      if (user == null) return const Stream.empty();
      return ref.read(notificationServiceProvider).watchMessagesForUser(user);
    });

final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  final user = ref.watch(currentAppUserProvider).asData?.value;
  if (user == null) return const Stream.empty();
  return ref.read(notificationServiceProvider).watchUnreadCount(user);
});

final alertsStreamProvider = StreamProvider<List<InternalMessage>>((ref) {
  final user = ref.watch(currentAppUserProvider).asData?.value;
  if (user == null) return const Stream.empty();
  return ref.read(alertServiceProvider).watchMessagesForUser(user);
});

final auditLogStreamProvider = StreamProvider<List<SystemAuditLogEntry>>((ref) {
  return ref.read(auditServiceProvider).watchRecent(limit: 150);
});

final globalSearchProvider =
    FutureProvider.family<List<SearchResult>, String>((ref, query) async {
      if (query.trim().isEmpty) return const [];
      return ref.read(searchServiceProvider).search(query);
    });

final drawingArchiveProvider =
    FutureProvider.family<List<DrawingArchiveItem>, DrawingArchiveQuery>((
      ref,
      query,
    ) async {
      return ref.read(drawingArchiveServiceProvider).fetchDrawings(
        search: query.search,
        customer: query.customer,
        project: query.project,
      );
    });

final productionReportProvider =
    FutureProvider.family<ProductionReportData, ProductionReportRequest>((
      ref,
      request,
    ) async {
      return ref.read(exportServiceProvider).buildReport(
        type: request.type,
        startDate: request.period.startDate,
        endDate: request.period.endDate,
        filters: request.filters,
      );
    });

class DrawingArchiveQuery {
  const DrawingArchiveQuery({
    this.search = '',
    this.customer = '',
    this.project = '',
  });

  final String search;
  final String customer;
  final String project;

  @override
  bool operator ==(Object other) =>
      other is DrawingArchiveQuery &&
      search == other.search &&
      customer == other.customer &&
      project == other.project;

  @override
  int get hashCode => Object.hash(search, customer, project);
}

class ProductionReportRequest {
  const ProductionReportRequest({
    required this.type,
    required this.period,
    this.filters = const OrderFilters(),
  });

  final ReportType type;
  final ReportPeriod period;
  final OrderFilters filters;

  @override
  bool operator ==(Object other) =>
      other is ProductionReportRequest &&
      type == other.type &&
      period == other.period &&
      filters == other.filters;

  @override
  int get hashCode => Object.hash(type, period, filters);
}
