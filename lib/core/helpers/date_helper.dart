import 'package:intl/intl.dart';

abstract final class DateHelper {
  static final DateFormat _dateFormat = DateFormat('MMM d, yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('MMM d, yyyy HH:mm');
  static final DateFormat _timeFormat = DateFormat('HH:mm');

  static String formatDate(DateTime? date) {
    if (date == null) return '—';
    return _dateFormat.format(date);
  }

  static String formatDateTime(DateTime? date) {
    if (date == null) return '—';
    return _dateTimeFormat.format(date);
  }

  static String formatTime(DateTime? date) {
    if (date == null) return '—';
    return _timeFormat.format(date);
  }

  static String relativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return formatDate(date);
  }
}
