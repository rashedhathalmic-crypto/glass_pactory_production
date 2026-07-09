enum ReportType {
  dailyProduction,
  weeklyProduction,
  monthlyProduction,
  department,
  delayedOrders,
  rework,
  delivery,
  productionTime;

  String get label => switch (this) {
        ReportType.dailyProduction => 'Daily Production',
        ReportType.weeklyProduction => 'Weekly Production',
        ReportType.monthlyProduction => 'Monthly Production',
        ReportType.department => 'Department Report',
        ReportType.delayedOrders => 'Delayed Orders',
        ReportType.rework => 'Rework Report',
        ReportType.delivery => 'Delivery Report',
        ReportType.productionTime => 'Production Time',
      };
}
