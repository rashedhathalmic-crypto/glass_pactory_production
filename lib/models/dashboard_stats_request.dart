/// Frozen point-in-time used for dashboard statistics queries.
///
/// [asOf] is captured when the dashboard opens or when the user refreshes.
/// It must not be recomputed on every provider rebuild.
class DashboardStatsRequest {
  const DashboardStatsRequest(this.asOf);

  final DateTime asOf;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardStatsRequest &&
          other.asOf.millisecondsSinceEpoch == asOf.millisecondsSinceEpoch;

  @override
  int get hashCode => asOf.millisecondsSinceEpoch;
}
