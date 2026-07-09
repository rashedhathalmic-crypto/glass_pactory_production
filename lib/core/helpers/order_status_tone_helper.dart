import '../../models/enums/order_status.dart';
import '../../widgets/status_tone.dart';

abstract final class OrderStatusToneHelper {
  static StatusTone toneFor(OrderStatus status) {
    return switch (status) {
      OrderStatus.draft => StatusTone.neutral,
      OrderStatus.inProgress => StatusTone.info,
      OrderStatus.onHold => StatusTone.warning,
      OrderStatus.completed => StatusTone.success,
      OrderStatus.cancelled => StatusTone.error,
    };
  }
}
