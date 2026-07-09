class ReportPeriod {
  const ReportPeriod({this.startDate, this.endDate});

  final DateTime? startDate;
  final DateTime? endDate;

  @override
  bool operator ==(Object other) =>
      other is ReportPeriod &&
      other.startDate == startDate &&
      other.endDate == endDate;

  @override
  int get hashCode => Object.hash(startDate, endDate);
}
