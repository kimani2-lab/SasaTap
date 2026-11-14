import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sasatap/core/nfc_service.dart';
import 'package:sasatap/features/tasks/task_executor.dart';
import 'package:sasatap/features/tasks/task_intent.dart';
import 'package:sasatap/features/tasks/task_model.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

Future<void> showErrorDialog(BuildContext context, NfcException error) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.error_outline),
      title: const Text('NFC operation failed'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error.message),
          if (error.hint != null) ...[
            const SizedBox(height: 12),
            Text(error.hint!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<bool> confirmDestructiveAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Continue',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Executes the local intent produced by a task.
///
/// SasaTap intentionally performs reversible foreground actions (clipboard,
/// haptics, explanatory dialog) rather than silently launching arbitrary
/// external apps. Links are copied so the user stays in control.
Future<void> runTaskIntent(
  BuildContext context, {
  required String taskName,
  required TaskIntent intent,
}) async {
  if (intent.haptic) {
    await HapticFeedback.mediumImpact();
  }
  if (intent.clipboardText != null) {
    await Clipboard.setData(ClipboardData(text: intent.clipboardText!));
  }
  if (!context.mounted) {
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(intent.icon),
      title: Text(taskName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(intent.message),
          if (intent.clipboardText != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              intent.clipboardText!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Copied to clipboard.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

/// Presents the results of a sequential automation run.
///
/// URI actions are copied only after the user explicitly chooses to do so;
/// the application does not silently launch another app.
Future<void> showTaskExecutionResult(
  BuildContext context,
  TaskExecutionResult result,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        result.error == null ? Icons.bolt : Icons.error_outline,
        color: result.error == null
            ? null
            : Theme.of(dialogContext).colorScheme.error,
      ),
      title: Text(result.task.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.error != null) ...[
              Text(
                result.error!,
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.error,
                ),
              ),
              if (result.actions.isNotEmpty) const Divider(height: 20),
            ],
            for (var index = 0; index < result.actions.length; index++) ...[
              if (index > 0) const Divider(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(result.actions[index].action.type.label),
                        const SizedBox(height: 2),
                        Text(
                          result.actions[index].message,
                          style: Theme.of(dialogContext).textTheme.bodySmall,
                        ),
                        if (result.actions[index].confirmationValue != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: SelectableText(
                                  result.actions[index].confirmationValue!,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  try {
                                    await Clipboard.setData(
                                      ClipboardData(
                                        text: result
                                            .actions[index]
                                            .confirmationValue!,
                                      ),
                                    );
                                    if (context.mounted) {
                                      showAppSnackBar(
                                        context,
                                        'Link copied to clipboard.',
                                      );
                                    }
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
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('Copy link'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

String formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) {
    return '${kilobytes.toStringAsFixed(1)} KB';
  }
  return '${(kilobytes / 1024).toStringAsFixed(2)} MB';
}

String prettyEnumName(String value) {
  if (value.isEmpty) {
    return 'Unknown';
  }
  return value
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}
