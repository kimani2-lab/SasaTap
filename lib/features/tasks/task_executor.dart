import 'package:flutter/services.dart';
import 'package:sasatap/core/hex_utils.dart';
import 'package:sasatap/features/tasks/task_model.dart';
import 'package:sasatap/features/tasks/task_repository.dart';

/// Outcome for one completed or user-confirmable automation action.
class TaskActionOutcome {
  const TaskActionOutcome({
    required this.action,
    required this.message,
    this.confirmationValue,
  });

  final TaskAction action;
  final String message;

  /// URL or intent URI to display for explicit user confirmation.
  final String? confirmationValue;
}

/// Result of running one automation profile.
class TaskExecutionResult {
  const TaskExecutionResult({
    required this.task,
    required this.actions,
    this.error,
  });

  final AutomationTask task;
  final List<TaskActionOutcome> actions;
  final String? error;
}

/// Error raised when a task action is invalid or cannot be completed.
class TaskExecutionException implements Exception {
  const TaskExecutionException(this.message, {this.actionIndex});

  final String message;
  final int? actionIndex;

  @override
  String toString() => message;
}

/// Executes enabled local rules in action order.
///
/// Actions requiring external apps are returned as confirmation requests;
/// SasaTap never launches an arbitrary URI or intent without user consent.
class TaskExecutor {
  TaskExecutor(this._repository);

  final TaskRepository _repository;

  List<AutomationTask> findEnabledForUid(String uid) => _repository
      .findByUid(normalizeUid(uid))
      .where((task) => task.enabled)
      .toList(growable: false);

  Future<List<TaskExecutionResult>> executeForUid(String uid) async {
    final normalizedUid = normalizeUid(uid);
    if (!isValidHex(normalizedUid)) {
      throw const TaskExecutionException(
        'The scanned tag returned an invalid UID.',
      );
    }

    final tasks = findEnabledForUid(normalizedUid);
    final results = <TaskExecutionResult>[];
    for (final task in tasks) {
      try {
        results.add(await execute(task));
      } on TaskExecutionException catch (error) {
        results.add(
          TaskExecutionResult(
            task: task,
            actions: const <TaskActionOutcome>[],
            error: error.message,
          ),
        );
      }
    }
    return List<TaskExecutionResult>.unmodifiable(results);
  }

  Future<TaskExecutionResult> execute(AutomationTask task) async {
    if (!task.enabled) {
      throw const TaskExecutionException('This automation is disabled.');
    }
    if (task.actions.isEmpty) {
      throw const TaskExecutionException(
        'This automation does not contain any actions.',
      );
    }

    final outcomes = <TaskActionOutcome>[];
    for (var index = 0; index < task.actions.length; index++) {
      final action = task.actions[index];
      try {
        outcomes.add(await _executeAction(action));
      } on Object catch (error) {
        throw TaskExecutionException(
          'Action ${index + 1} (${action.type.label}) failed: $error',
          actionIndex: index,
        );
      }
    }

    await _repository.markTriggered(task.id);
    return TaskExecutionResult(
      task: task,
      actions: List<TaskActionOutcome>.unmodifiable(outcomes),
    );
  }

  Future<TaskActionOutcome> _executeAction(TaskAction action) async {
    final value = action.value.trim();
    switch (action.type) {
      case TaskActionType.openUrl:
      case TaskActionType.launchIntent:
        final uri = Uri.tryParse(value);
        if (uri == null ||
            !uri.hasScheme ||
            !const <String>{
              'http',
              'https',
              'mailto',
              'tel',
            }.contains(uri.scheme.toLowerCase())) {
          throw const TaskExecutionException(
            'Only valid http, https, mailto and tel URIs can be requested.',
          );
        }
        return TaskActionOutcome(
          action: action,
          message:
              'Review the requested URI and copy it if you want to use it.',
          confirmationValue: value,
        );
      case TaskActionType.copyText:
        await Clipboard.setData(ClipboardData(text: action.value));
        return TaskActionOutcome(
          action: action,
          message: 'Text copied to the clipboard.',
        );
      case TaskActionType.showMessage:
      case TaskActionType.showNotification:
        if (value.isEmpty) {
          throw const TaskExecutionException(
            'Enter a message for this action.',
          );
        }
        return TaskActionOutcome(action: action, message: action.value);
      case TaskActionType.haptic:
        await HapticFeedback.mediumImpact();
        return TaskActionOutcome(
          action: action,
          message: 'Haptic feedback triggered.',
        );
      case TaskActionType.wait:
        final seconds = int.tryParse(value);
        if (seconds == null || seconds < 0 || seconds > maxTaskWaitSeconds) {
          throw const TaskExecutionException(
            'Wait duration must be between 0 and 300 seconds.',
          );
        }
        await Future<void>.delayed(Duration(seconds: seconds));
        return TaskActionOutcome(
          action: action,
          message: 'Waited $seconds second(s).',
        );
    }
  }
}
