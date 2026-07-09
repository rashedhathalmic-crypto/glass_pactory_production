import 'production_order.dart';

class SearchResult {
  const SearchResult({
    required this.order,
    required this.matchField,
    required this.matchValue,
  });

  final ProductionOrder order;
  final String matchField;
  final String matchValue;
}
