import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/helpers/responsive_helper.dart';
import '../../../core/theme/app_icons.dart';
import '../../../providers/phase2_providers.dart';
import '../../../routing/route_paths.dart';
import '../../../widgets/widgets.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) => setState(() => _query = value.trim());

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(globalSearchProvider(_query));

    return SingleChildScrollView(
      padding: ResponsiveHelper.pagePadding(context),
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Global Search',
              subtitle:
                  'Search by order number, drawing, customer, project, or QR code',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Search',
                prefixIcon: const Icon(AppIcons.search),
                suffixIcon: IconButton(
                  icon: const Icon(AppIcons.arrowForward),
                  onPressed: () => _submit(_controller.text),
                ),
              ),
              onSubmitted: _submit,
            ),
            const SizedBox(height: 24),
            if (_query.isEmpty)
              const AppEmptyState(
                title: 'Enter a search term',
                subtitle: 'Results open the matching production order directly.',
              )
            else
              resultsAsync.when(
                loading: () => const AppLoadingIndicator(),
                error: (e, _) => AppErrorView(message: e.toString()),
                data: (results) {
                  if (results.isEmpty) {
                    return const AppEmptyState(
                      title: 'No matches found',
                      subtitle: 'Try a different order number or customer name.',
                    );
                  }
                  return AppCard(
                    title: '${results.length} result(s)',
                    child: Column(
                      children: [
                        for (final result in results)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(result.order.orderNumber),
                            subtitle: Text(
                              '${result.matchField}: ${result.matchValue}',
                            ),
                            trailing: const Icon(AppIcons.arrowForward),
                            onTap: () => context.push(
                              RoutePaths.orderDetailPath(result.order.id),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
