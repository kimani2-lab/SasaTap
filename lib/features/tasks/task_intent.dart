import 'package:flutter/material.dart';
import 'package:sasatap/features/tasks/task_model.dart';

/// The foreground action requested by a task.
///
/// External URLs are never launched silently; the user sees the destination
/// and the value is placed on the clipboard.
class TaskIntent {
  const TaskIntent({
    required this.icon,
    required this.message,
    this.clipboardText,
    this.haptic = false,
  });

  final IconData icon;
  final String message;
  final String? clipboardText;
  final bool haptic;

  static IconData iconFor(TaskActionType type) {
    switch (type) {
      case TaskActionType.openUrl:
        return Icons.open_in_new;
      case TaskActionType.copyText:
        return Icons.copy_all_outlined;
      case TaskActionType.showMessage:
        return Icons.message_outlined;
      case TaskActionType.haptic:
        return Icons.vibration;
      case TaskActionType.wait:
        return Icons.hourglass_bottom;
      case TaskActionType.showNotification:
        return Icons.notifications_outlined;
      case TaskActionType.launchIntent:
        return Icons.open_in_new;
    }
  }

  factory TaskIntent.fromTask(AutomationTask task) {
    switch (task.actionType) {
      case TaskActionType.openUrl:
        return TaskIntent(
          icon: Icons.open_in_new,
          message: 'This task requests opening the following link:',
          clipboardText: task.actionValue,
        );
      case TaskActionType.copyText:
        return TaskIntent(
          icon: Icons.copy_all_outlined,
          message: 'The task value has been copied to the clipboard.',
          clipboardText: task.actionValue,
        );
      case TaskActionType.showMessage:
        return TaskIntent(
          icon: Icons.message_outlined,
          message: task.actionValue.isEmpty
              ? 'This task has no message configured.'
              : task.actionValue,
        );
      case TaskActionType.haptic:
        return const TaskIntent(
          icon: Icons.vibration,
          message: 'Haptic feedback triggered by the task.',
          haptic: true,
        );
      case TaskActionType.wait:
        return const TaskIntent(
          icon: Icons.hourglass_bottom,
          message: 'This task includes a wait action.',
        );
      case TaskActionType.showNotification:
        return TaskIntent(
          icon: Icons.notifications_outlined,
          message: task.actionValue,
        );
      case TaskActionType.launchIntent:
        return TaskIntent(
          icon: Icons.open_in_new,
          message: 'This task requests a foreground intent:',
          clipboardText: task.actionValue,
        );
    }
  }
}
