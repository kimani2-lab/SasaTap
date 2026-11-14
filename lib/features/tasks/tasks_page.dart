import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sasatap/core/hex_utils.dart';
import 'package:sasatap/core/nfc_service.dart';
import 'package:sasatap/features/tasks/task_editor_sheet.dart';
import 'package:sasatap/features/tasks/task_intent.dart';
import 'package:sasatap/features/tasks/task_model.dart';
import 'package:sasatap/features/tasks/tasks_provider.dart';
import 'package:sasatap/shared/utils/ui_helpers.dart';
import 'package:sasatap/shared/widgets/nfc_availability_banner.dart';
import 'package:sasatap/shared/widgets/section_card.dart';

enum _TaskMenuAction { run, edit, delete }

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TasksProvider>(
      builder: (context, provider, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const NfcAvailabilityBanner(),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Local automation',
              subtitle: 'Map a tag UID to a foreground action.',
              icon: Icons.bolt,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SasaTap matches tasks while the app is open and a tag is '
                    'scanned. Background scanning is restricted by Android '
                    'and iOS, so tasks do not run when the app is closed.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: provider.busy
                              ? null
                              : () => _scanAndRun(context, provider),
                          icon: const Icon(Icons.nfc),
                          label: const Text('Scan & run'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: provider.busy
                              ? null
                              : () => _addTask(context, provider),
                          icon: const Icon(Icons.add),
                          label: const Text('New task'),
                        ),
                      ),
                    ],
                  ),
                  if (provider.busy) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
            if (provider.error != null) ...[
              const SizedBox(height: 12),
              _TaskFeedbackCard(
                error: provider.error,
                message: null,
                onDismiss: provider.clearFeedback,
              ),
            ] else if (provider.message != null) ...[
              const SizedBox(height: 12),
              _TaskFeedbackCard(
                error: null,
                message: provider.message,
                onDismiss: provider.clearFeedback,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Saved tasks',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${provider.tasks.length}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (provider.tasks.isEmpty)
              SectionCard(
                title: 'No tasks yet',
                subtitle: 'Create a rule, then scan its tag to trigger it.',
                icon: Icons.playlist_add,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: provider.busy
                        ? null
                        : () => _addTask(context, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Create your first task'),
                  ),
                ),
              )
            else
              for (final task in provider.tasks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TaskCard(
                    task: task,
                    onRun: () => _runTask(context, provider, task),
                    onEdit: () => _editTask(context, provider, task),
                    onToggle: (enabled) async {
                      try {
                        await provider.setEnabled(task, enabled);
                      } on Object catch (error) {
                        if (context.mounted) {
                          showAppSnackBar(
                            context,
                            error.toString(),
                            isError: true,
                          );
                        }
                      }
                    },
                    onDelete: () => _deleteTask(context, provider, task),
                  ),
                ),
          ],
        );
      },
    );
  }

  Future<void> _addTask(BuildContext context, TasksProvider provider) async {
    final task = await showModalBottomSheet<AutomationTask>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const TaskEditorSheet(),
    );
    if (task != null) {
      try {
        await provider.saveTask(task);
      } on Object catch (error) {
        if (context.mounted) {
          showAppSnackBar(context, error.toString(), isError: true);
        }
      }
    }
  }

  Future<void> _editTask(
    BuildContext context,
    TasksProvider provider,
    AutomationTask task,
  ) async {
    final updated = await showModalBottomSheet<AutomationTask>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => TaskEditorSheet(task: task),
    );
    if (updated != null) {
      try {
        await provider.saveTask(updated);
      } on Object catch (error) {
        if (context.mounted) {
          showAppSnackBar(context, error.toString(), isError: true);
        }
      }
    }
  }

  Future<void> _deleteTask(
    BuildContext context,
    TasksProvider provider,
    AutomationTask task,
  ) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete this task?',
      message: '"${task.name}" will be removed from this device.',
      confirmLabel: 'Delete',
    );
    if (confirmed) {
      try {
        await provider.deleteTask(task.id);
      } on Object catch (error) {
        if (context.mounted) {
          showAppSnackBar(context, error.toString(), isError: true);
        }
      }
    }
  }

  Future<void> _runTask(
    BuildContext context,
    TasksProvider provider,
    AutomationTask task,
  ) async {
    try {
      final result = await provider.runTask(task);
      if (context.mounted) {
        await showTaskExecutionResult(context, result);
      }
    } on Object catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, error.toString(), isError: true);
      }
    }
  }

  Future<void> _scanAndRun(BuildContext context, TasksProvider provider) async {
    final matches = await provider.scanAndMatch();
    if (!context.mounted || matches.isEmpty) {
      return;
    }

    AutomationTask? selected;
    if (matches.length == 1) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(TaskIntent.iconFor(matches.first.actionType)),
          title: const Text('Task matched'),
          content: Text('Run "${matches.first.name}" for this tag?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Run task'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        selected = matches.first;
      }
    } else {
      selected = await showModalBottomSheet<AutomationTask>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  '${matches.length} tasks match this tag',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (final task in matches)
                ListTile(
                  leading: Icon(TaskIntent.iconFor(task.actionType)),
                  title: Text(task.name),
                  subtitle: Text('${task.actions.length} sequential action(s)'),
                  onTap: () => Navigator.of(sheetContext).pop(task),
                ),
            ],
          ),
        ),
      );
    }

    if (selected != null && context.mounted) {
      await _runTask(context, provider, selected);
    }
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onRun,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final AutomationTask task;
  final VoidCallback onRun;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onEdit,
        isThreeLine: true,
        leading: CircleAvatar(
          backgroundColor: scheme.secondaryContainer,
          foregroundColor: scheme.onSecondaryContainer,
          child: Icon(TaskIntent.iconFor(task.actionType), size: 20),
        ),
        title: Text(
          task.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              'UID ${formatUid(task.tagUid)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            Text(
              '${task.actions.length} action(s): '
              '${task.actions.map((action) => action.type.label).join(' → ')}'
              '${task.enabled ? '' : ' • disabled'}',
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (task.triggerCount > 0)
              Text(
                'Triggered ${task.triggerCount} time(s)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: task.enabled, onChanged: onToggle),
            PopupMenuButton<_TaskMenuAction>(
              tooltip: 'Task actions',
              onSelected: (action) {
                switch (action) {
                  case _TaskMenuAction.run:
                    onRun();
                    break;
                  case _TaskMenuAction.edit:
                    onEdit();
                    break;
                  case _TaskMenuAction.delete:
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _TaskMenuAction.run,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.play_arrow_outlined),
                    title: Text('Run now'),
                  ),
                ),
                PopupMenuItem(
                  value: _TaskMenuAction.edit,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                  ),
                ),
                PopupMenuItem(
                  value: _TaskMenuAction.delete,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskFeedbackCard extends StatelessWidget {
  const _TaskFeedbackCard({
    required this.error,
    required this.message,
    required this.onDismiss,
  });

  final NfcException? error;
  final String? message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isError = error != null;
    final background = isError
        ? scheme.errorContainer
        : scheme.primaryContainer;
    final foreground = isError
        ? scheme.onErrorContainer
        : scheme.onPrimaryContainer;
    return Card(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: foreground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isError ? error!.message : message ?? '',
                    style: TextStyle(color: foreground),
                  ),
                  if (isError && error!.hint != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      error!.hint!,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              icon: Icon(Icons.close, color: foreground, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
