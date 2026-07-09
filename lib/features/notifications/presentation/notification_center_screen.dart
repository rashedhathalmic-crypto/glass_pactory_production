import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/date_helper.dart';
import '../../../core/helpers/responsive_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../models/enums/department.dart';
import '../../../models/enums/message_priority.dart';
import '../../../models/enums/message_type.dart';
import '../../../models/enums/recipient_scope.dart';
import '../../../core/permissions/app_permission.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/phase2_providers.dart';
import '../../../utils/extensions/extensions.dart';
import '../../../widgets/widgets.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    final notificationsAsync = ref.watch(notificationsStreamProvider);

    return SingleChildScrollView(
      padding: ResponsiveHelper.pagePadding(context),
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Notification Center',
              subtitle: 'Internal notifications with realtime updates',
              actions: [
                if ((user?.hasPermission(AppPermission.sendNotifications) ??
                        false) ||
                    (user?.hasPermission(
                          AppPermission.sendDepartmentNotifications,
                        ) ??
                        false))
                  FilledButton.icon(
                    onPressed: () => _showComposeDialog(user!),
                    icon: const Icon(AppIcons.add, size: 18),
                    label: const Text('Send Notification'),
                  ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: user == null
                      ? null
                      : () => ref
                          .read(notificationServiceProvider)
                          .markAllAsRead(user),
                  child: const Text('Mark All Read'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            notificationsAsync.when(
              loading: () => const AppLoadingIndicator(),
              error: (e, _) => AppErrorView(message: e.toString()),
              data: (messages) {
                if (messages.isEmpty) {
                  return const AppEmptyState(
                    title: 'No notifications',
                    subtitle: 'New notifications will appear here instantly.',
                  );
                }
                return AppCard(
                  title: '${messages.where((m) => !m.isRead).length} unread',
                  child: Column(
                    children: [
                      for (final message in messages)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  message.title,
                                  style: TextStyle(
                                    fontWeight: message.isRead
                                        ? FontWeight.w500
                                        : FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (!message.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.info,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(message.message),
                              const SizedBox(height: 4),
                              Text(
                                '${message.type.label} · ${message.priority.label} · '
                                '${message.senderName} · '
                                '${DateHelper.formatDateTime(message.createdAt)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              final service =
                                  ref.read(notificationServiceProvider);
                              if (value == 'read') {
                                await service.markAsRead(message.id);
                              } else if (value == 'delete') {
                                await service.deleteMessage(message.id);
                              }
                            },
                            itemBuilder: (context) => [
                              if (!message.isRead)
                                const PopupMenuItem(
                                  value: 'read',
                                  child: Text('Mark as Read'),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
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

  Future<void> _showComposeDialog(dynamic user) async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    var type = MessageType.general;
    var priority = MessagePriority.normal;
    var scope = RecipientScope.everyone;
    Department? department;
    var receiverName = '';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Send Notification'),
          content: SizedBox(
            width: 420,
            child: MessageComposeFields(
              titleController: titleController,
              messageController: messageController,
              type: type,
              priority: priority,
              scope: scope,
              department: department,
              receiverName: receiverName,
              onTypeChanged: (value) => setLocalState(() => type = value),
              onPriorityChanged: (value) =>
                  setLocalState(() => priority = value),
              onScopeChanged: (value) => setLocalState(() => scope = value),
              onDepartmentChanged: (value) =>
                  setLocalState(() => department = value),
              onReceiverNameChanged: (value) =>
                  setLocalState(() => receiverName = value),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await ref.read(notificationServiceProvider).sendMessage(
                      sender: user,
                      title: titleController.text,
                      message: messageController.text,
                      type: type,
                      priority: priority,
                      scope: scope,
                      receiverName: receiverName,
                      department: department,
                    );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}
