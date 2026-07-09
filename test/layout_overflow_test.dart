import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glass_pactory_production/features/authentication/presentation/login_screen.dart';
import 'package:glass_pactory_production/models/enums/department.dart';
import 'package:glass_pactory_production/widgets/stat_card.dart';
import 'package:glass_pactory_production/models/order_filters.dart';
import 'package:glass_pactory_production/widgets/illustrations/department_hero_illustration.dart';
import 'package:glass_pactory_production/widgets/order_filters_panel.dart';
import 'package:glass_pactory_production/widgets/responsive_card_grid.dart';

void main() {
  Future<void> expectNoOverflow(
    WidgetTester tester, {
    required Size size,
    required Widget child,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: SizedBox(width: size.width - 64, child: child),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  }

  group('layout overflow', () {
    testWidgets('stat grid fits at 1366x768', (tester) async {
      await expectNoOverflow(
        tester,
        size: const Size(1366, 768),
        child: const ResponsiveCardGrid(
          columns: 4,
          itemCount: 6,
          itemBuilder: _statCard,
        ),
      );
    });

    testWidgets('stat grid fits at 1920x1080', (tester) async {
      await expectNoOverflow(
        tester,
        size: const Size(1920, 1080),
        child: const ResponsiveCardGrid(
          columns: 4,
          itemCount: 6,
          itemBuilder: _statCard,
        ),
      );
    });

    testWidgets('department cards fit at 1366x768', (tester) async {
      await expectNoOverflow(
        tester,
        size: const Size(1366, 768),
        child: ResponsiveCardGrid(
          columns: 3,
          itemCount: Department.values.length,
          itemBuilder: (context, index) {
            final dept = Department.values[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dept.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('0 active orders'),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });

    testWidgets('stat card fits exact 187x63.2 constraint', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 187,
                height: 63.2,
                child: StatCard(
                  label: 'In Progress',
                  value: '128',
                  icon: Icons.play_arrow,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('stat card fits exact 187x63.2 with trend', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 187,
                height: 63.2,
                child: StatCard(
                  label: 'Completion Rate',
                  value: '98.5%',
                  icon: Icons.analytics,
                  trend: '+2.1% vs last week',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('order filters panel fits narrow and desktop widths', (tester) async {
      for (final width in [700.0, 900.0, 1042.0, 1200.0]) {
        await expectNoOverflow(
          tester,
          size: Size(width, 600),
          child: OrderFiltersPanel(
            filters: const OrderFilters(),
            onChanged: (_) {},
            onClear: () {},
          ),
        );
      }
    });

    testWidgets('department cards with illustrations fit at 1366x768', (tester) async {
      await expectNoOverflow(
        tester,
        size: const Size(1366, 768),
        child: ResponsiveCardGrid(
          columns: 3,
          itemCount: Department.values.length,
          itemBuilder: (context, index) {
            final dept = Department.values[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DepartmentCardIllustration(department: dept),
                    Text(dept.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const Text('0 active orders'),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });

    testWidgets('login screen fits at 1366x768', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}

Widget _statCard(BuildContext context, int index) {
  const labels = [
    'Total Orders',
    'In Progress',
    'Completed',
    'On Hold',
    'Overdue',
    'Active Users',
  ];
  return StatCard(label: labels[index], value: '${index * 12}');
}
