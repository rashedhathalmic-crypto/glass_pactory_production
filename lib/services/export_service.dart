import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/helpers/download_helper.dart';
import '../models/enums/department.dart';
import '../models/enums/order_status.dart';
import '../models/enums/report_type.dart';
import '../models/order_filters.dart';
import '../models/production_report_data.dart';
import '../models/report_summary.dart';
import '../services/analytics_service.dart';
import '../services/production_order_repository.dart';
import '../services/search_service.dart';

class ExportService {
  ExportService(
    this._orderRepository,
    this._searchService,
    this._analyticsService,
  );

  final ProductionOrderRepository _orderRepository;
  final SearchService _searchService;
  final AnalyticsService _analyticsService;

  Future<ProductionReportData> buildReport({
    required ReportType type,
    DateTime? startDate,
    DateTime? endDate,
    OrderFilters filters = const OrderFilters(),
  }) async {
    final orders = await _orderRepository.getOrdersForReport(
      startDate: startDate,
      endDate: endDate,
    );
    final filtered = _searchService.applyFilters(orders, filters);
    final asOf = DateTime.now();
    final periodLabel = _periodLabel(startDate, endDate);

    return switch (type) {
      ReportType.dailyProduction => ProductionReportData(
          title: 'Daily Production Report',
          periodLabel: periodLabel,
          summaryRows: [
            ReportRow(
              label: 'Completed Orders',
              value: filtered
                  .where((o) => o.status == OrderStatus.completed)
                  .length
                  .toString(),
            ),
            ReportRow(
              label: 'In Progress',
              value: filtered
                  .where((o) => o.status == OrderStatus.inProgress)
                  .length
                  .toString(),
            ),
          ],
          orders: filtered,
        ),
      ReportType.weeklyProduction => ProductionReportData(
          title: 'Weekly Production Report',
          periodLabel: periodLabel,
          summaryRows: [
            ReportRow(
              label: 'Total Orders',
              value: filtered.length.toString(),
            ),
            ReportRow(
              label: 'Completed',
              value: filtered
                  .where((o) => o.status == OrderStatus.completed)
                  .length
                  .toString(),
            ),
          ],
          orders: filtered,
        ),
      ReportType.monthlyProduction => ProductionReportData(
          title: 'Monthly Production Report',
          periodLabel: periodLabel,
          summaryRows: [
            ReportRow(
              label: 'Total Orders',
              value: filtered.length.toString(),
            ),
            ReportRow(
              label: 'Rework Orders',
              value: _analyticsService.reworkOrdersList(filtered).length.toString(),
            ),
          ],
          orders: filtered,
        ),
      ReportType.department => ProductionReportData(
          title: 'Department Report',
          periodLabel: periodLabel,
          departmentRows: {
            for (final dept in Department.values)
              dept: filtered
                  .where((o) => o.currentDepartment == dept)
                  .length,
          },
          orders: filtered,
        ),
      ReportType.delayedOrders => ProductionReportData(
          title: 'Delayed Orders Report',
          periodLabel: periodLabel,
          orders: _analyticsService.delayedOrdersList(filtered, asOf),
          summaryRows: [
            ReportRow(
              label: 'Delayed Orders',
              value: _analyticsService
                  .delayedOrdersList(filtered, asOf)
                  .length
                  .toString(),
            ),
          ],
        ),
      ReportType.rework => ProductionReportData(
          title: 'Rework Report',
          periodLabel: periodLabel,
          orders: _analyticsService.reworkOrdersList(filtered),
          summaryRows: [
            ReportRow(
              label: 'Rework Orders',
              value: _analyticsService.reworkOrdersList(filtered).length.toString(),
            ),
          ],
        ),
      ReportType.delivery => ProductionReportData(
          title: 'Delivery Report',
          periodLabel: periodLabel,
          orders: filtered
              .where(
                (o) =>
                    o.currentDepartment == Department.finishedDelivery ||
                    o.status == OrderStatus.completed,
              )
              .toList(),
          summaryRows: [
            ReportRow(
              label: 'Delivery Queue',
              value: filtered
                  .where((o) => o.currentDepartment == Department.finishedDelivery)
                  .length
                  .toString(),
            ),
          ],
        ),
      ReportType.productionTime => ProductionReportData(
          title: 'Production Time Report',
          periodLabel: periodLabel,
          productionTimeRows: [
            for (final order in filtered)
              for (final dept in Department.values)
                if (_analyticsService.departmentHours(order, dept) > 0)
                  ProductionTimeRow(
                    orderNumber: order.orderNumber,
                    department: dept,
                    hours: _analyticsService.departmentHours(order, dept),
                  ),
          ],
        ),
    };
  }

  Future<void> exportPdf(ProductionReportData data) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text(data.title)),
          pw.Text('Period: ${data.periodLabel}'),
          pw.SizedBox(height: 12),
          for (final row in data.summaryRows)
            pw.Text('${row.label}: ${row.value}'),
          if (data.departmentRows.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Department Breakdown', style: pw.TextStyle(fontSize: 14)),
            for (final entry in data.departmentRows.entries)
              pw.Text('${entry.key.label}: ${entry.value}'),
          ],
          if (data.productionTimeRows.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Production Time', style: pw.TextStyle(fontSize: 14)),
            for (final row in data.productionTimeRows)
              pw.Text(
                '${row.orderNumber} · ${row.department.label}: '
                '${row.hours.toStringAsFixed(1)} h',
              ),
          ],
          if (data.orders.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Orders', style: pw.TextStyle(fontSize: 14)),
            pw.TableHelper.fromTextArray(
              headers: const [
                'Order #',
                'Customer',
                'Department',
                'Status',
              ],
              data: data.orders
                  .map(
                    (o) => [
                      o.orderNumber,
                      o.customerName,
                      o.currentDepartment.label,
                      o.status.label,
                    ],
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
    final bytes = await doc.save();
    await downloadBytes(
      bytes: Uint8List.fromList(bytes),
      fileName: '${_fileSafe(data.title)}.pdf',
      mimeType: 'application/pdf',
    );
  }

  Future<void> exportExcel(ProductionReportData data) async {
    final excel = Excel.createExcel();
    final sheet = excel['Report'];
    excel.delete('Sheet1');

    sheet.appendRow([TextCellValue(data.title)]);
    sheet.appendRow([TextCellValue('Period: ${data.periodLabel}')]);
    sheet.appendRow([TextCellValue('')]);

    for (final row in data.summaryRows) {
      sheet.appendRow([
        TextCellValue(row.label),
        TextCellValue(row.value),
      ]);
    }

    if (data.departmentRows.isNotEmpty) {
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([TextCellValue('Department'), TextCellValue('Count')]);
      for (final entry in data.departmentRows.entries) {
        sheet.appendRow([
          TextCellValue(entry.key.label),
          IntCellValue(entry.value),
        ]);
      }
    }

    if (data.productionTimeRows.isNotEmpty) {
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([
        TextCellValue('Order #'),
        TextCellValue('Department'),
        TextCellValue('Hours'),
      ]);
      for (final row in data.productionTimeRows) {
        sheet.appendRow([
          TextCellValue(row.orderNumber),
          TextCellValue(row.department.label),
          DoubleCellValue(row.hours),
        ]);
      }
    }

    if (data.orders.isNotEmpty) {
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([
        TextCellValue('Order #'),
        TextCellValue('Customer'),
        TextCellValue('Project'),
        TextCellValue('Department'),
        TextCellValue('Status'),
        TextCellValue('Priority'),
      ]);
      for (final order in data.orders) {
        sheet.appendRow([
          TextCellValue(order.orderNumber),
          TextCellValue(order.customerName),
          TextCellValue(order.projectName),
          TextCellValue(order.currentDepartment.label),
          TextCellValue(order.status.label),
          TextCellValue(order.priority.label),
        ]);
      }
    }

    final bytes = excel.encode();
    if (bytes == null) return;
    await downloadBytes(
      bytes: Uint8List.fromList(bytes),
      fileName: '${_fileSafe(data.title)}.xlsx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<void> exportSummaryPdf(ReportSummary summary) async {
    await exportPdf(
      ProductionReportData(
        title: 'Production Summary',
        periodLabel: summary.periodLabel,
        summaryRows: [
          ReportRow(
            label: 'Units Produced',
            value: summary.totalProduced.toString(),
          ),
          ReportRow(
            label: 'Completion Rate',
            value: '${summary.completionRate.toStringAsFixed(1)}%',
          ),
          ReportRow(
            label: 'Average Cycle Time',
            value: '${summary.averageCycleDays.toStringAsFixed(1)} days',
          ),
          ReportRow(
            label: 'Inspection Pass Rate',
            value: '${summary.inspectionPassRate.toStringAsFixed(1)}%',
          ),
        ],
        departmentRows: summary.departmentThroughput,
      ),
    );
  }

  String _periodLabel(DateTime? start, DateTime? end) {
    final formatter = DateFormat('yyyy-MM-dd');
    if (start == null && end == null) return 'All Time';
    if (start != null && end != null) {
      return '${formatter.format(start)} — ${formatter.format(end)}';
    }
    if (start != null) return 'From ${formatter.format(start)}';
    return 'Until ${formatter.format(end!)}';
  }

  String _fileSafe(String value) =>
      value.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
}
