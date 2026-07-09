import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/helpers/order_status_tone_helper.dart';
import '../../../core/helpers/date_helper.dart';
import '../../../core/helpers/responsive_helper.dart';
import '../../../models/enums/order_status.dart';
import '../../../models/production_order.dart';
import '../../../routing/route_paths.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/order_filters.dart';
import '../../../providers/phase2_providers.dart';
import '../../../providers/production_order_provider.dart';
import '../../../core/permissions/app_permission.dart';
import '../../../core/permissions/permission_context.dart';
import '../../../models/enums/user_role.dart';
import '../../../utils/extensions/extensions.dart';
import '../../../core/theme/app_icons.dart';
import '../../../widgets/widgets.dart';

class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({super.key});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> {
  final _scrollController = ScrollController();
  final List<ProductionOrder> _orders = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  String _searchQuery = '';
  OrderStatus? _statusFilter;
  OrderFilters _advancedFilters = const OrderFilters();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _orders.clear();
      _lastDocument = null;
      _hasMore = true;
    });

    try {
      final page = await ref
          .read(productionOrderRepositoryProvider)
          .fetchOrdersPage(status: _statusFilter, searchQuery: _searchQuery);
      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(_filterClient(page.orders));
        _lastDocument = page.lastDocument;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoadingMore || _searchQuery.isNotEmpty) return;
    setState(() => _isLoadingMore = true);

    try {
      final page = await ref.read(productionOrderRepositoryProvider).fetchOrdersPage(
            status: _statusFilter,
            startAfter: _lastDocument,
          );
      if (!mounted) return;
      setState(() {
        _orders.addAll(_filterClient(page.orders));
        _lastDocument = page.lastDocument;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoadingMore = false;
      });
    }
  }

  List<ProductionOrder> _filterClient(List<ProductionOrder> orders) {
    var filtered = orders;
    final user = ref.read(currentAppUserProvider).asData?.value;
    if (user != null && !user.hasPermission(AppPermission.viewAllOrders)) {
      filtered = filtered.where((order) {
        final context = PermissionContext(
          order: order,
          department: order.currentDepartment,
        );
        if (user.role == UserRole.operator) {
          return user.hasPermission(
            AppPermission.viewAssignedOrders,
            context: context,
          );
        }
        return user.hasPermission(
          AppPermission.viewDepartmentOrders,
          context: context,
        );
      }).toList();
    }
    if (_statusFilter != null) {
      filtered = filtered.where((order) => order.status == _statusFilter).toList();
    }
    filtered = ref.read(searchServiceProvider).applyFilters(
          filtered,
          _advancedFilters.copyWith(status: null),
        );
    if (_searchQuery.isEmpty) return filtered;
    final lower = _searchQuery.toLowerCase();
    return filtered
        .where(
          (order) =>
              order.orderNumber.toLowerCase().contains(lower) ||
              order.customerName.toLowerCase().contains(lower) ||
              order.projectName.toLowerCase().contains(lower) ||
              order.drawingNumber.toLowerCase().contains(lower),
        )
        .toList();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (_searchQuery == value) return;
      setState(() => _searchQuery = value);
      _loadInitial();
    });
  }

  void _onStatusChanged(OrderStatus? status) {
    setState(() => _statusFilter = status);
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    final canCreate = user?.hasPermission(AppPermission.createOrders) ?? false;

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ResponsiveHelper.pagePadding(context),
        child: ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Production Orders',
                subtitle: 'Track and manage glass production workflow',
                actions: [
                  if (canCreate)
                    ElevatedButton.icon(
                      onPressed: () async {
                        await context.push(RoutePaths.orderCreate);
                        if (mounted) _loadInitial();
                      },
                      icon: const Icon(AppIcons.add, size: 18),
                      label: const Text('New Order'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _FiltersBar(
                statusFilter: _statusFilter,
                onSearchChanged: _onSearchChanged,
                onStatusChanged: _onStatusChanged,
              ),
              const SizedBox(height: 12),
              OrderFiltersPanel(
                filters: _advancedFilters,
                onChanged: (value) {
                  setState(() => _advancedFilters = value);
                  _loadInitial();
                },
                onClear: () {
                  setState(() => _advancedFilters = const OrderFilters());
                  _loadInitial();
                },
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const AppLoadingIndicator()
              else if (_error != null)
                AppErrorView(message: _error!, onRetry: _loadInitial)
              else if (_orders.isEmpty)
                const AppEmptyState(title: 'No orders match your filters')
              else ...[
                AppCard(child: _OrdersTable(orders: _orders)),
                if (_isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onStatusChanged,
  });

  final OrderStatus? statusFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<OrderStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: ResponsiveHelper.isMobile(context) ? double.infinity : 280,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search orders...',
              prefixIcon: Icon(AppIcons.search),
              isDense: true,
            ),
            onChanged: onSearchChanged,
          ),
        ),
        SizedBox(
          width: ResponsiveHelper.isMobile(context) ? double.infinity : 200,
          child: DropdownButtonFormField<OrderStatus?>(
            isExpanded: true,
            initialValue: statusFilter,
            decoration: const InputDecoration(
              labelText: 'Status',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Statuses')),
              ...OrderStatus.values.map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.label, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: onStatusChanged,
          ),
        ),
      ],
    );
  }
}

class _OrdersTable extends StatelessWidget {
  const _OrdersTable({required this.orders});

  final List<ProductionOrder> orders;

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isMobile(context)) {
      return Column(children: orders.map((o) => _OrderTile(order: o)).toList());
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Order #')),
          DataColumn(label: Text('Customer')),
          DataColumn(label: Text('Glass Type')),
          DataColumn(label: Text('Drawing / Area')),
          DataColumn(label: Text('Qty')),
          DataColumn(label: Text('Department')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Due Date')),
        ],
        rows: orders.map((order) {
          return DataRow(
            onSelectChanged: (_) =>
                context.push(RoutePaths.orderDetailPath(order.id)),
            cells: [
              DataCell(Text(order.orderNumber)),
              DataCell(Text(order.customerName)),
              DataCell(Text(order.glassType)),
              DataCell(
                Text(
                  '${order.drawingNumber}\n${order.areaSqM.toStringAsFixed(2)} m²',
                ),
              ),
              DataCell(Text(order.quantity.toString())),
              DataCell(Text(order.currentDepartment.shortLabel)),
              DataCell(
                StatusChip(
                  label: order.status.label,
                  tone: OrderStatusToneHelper.toneFor(order.status),
                ),
              ),
              DataCell(Text(DateHelper.formatDate(order.dueDate))),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final ProductionOrder order;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(order.orderNumber),
      subtitle: Text(
        '${order.customerName} · ${order.currentDepartment.label}',
      ),
      trailing: StatusChip(
        label: order.status.label,
        tone: OrderStatusToneHelper.toneFor(order.status),
      ),
      onTap: () => context.push(RoutePaths.orderDetailPath(order.id)),
    );
  }
}
