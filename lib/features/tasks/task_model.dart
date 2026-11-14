import 'package:sasatap/core/hex_utils.dart';

const int maxTaskWaitSeconds = 300;

/// Foreground-safe actions that a local automation profile can run.
enum TaskActionType {
  openUrl,
  copyText,
  showMessage,
  haptic,
  wait,
  showNotification,
  launchIntent,
}

extension TaskActionTypeInfo on TaskActionType {
  String get label {
    switch (this) {
      case TaskActionType.openUrl:
        return 'Open a link';
      case TaskActionType.copyText:
        return 'Copy text';
      case TaskActionType.showMessage:
        return 'Show a message';
      case TaskActionType.haptic:
        return 'Haptic feedback';
      case TaskActionType.wait:
        return 'Wait';
      case TaskActionType.showNotification:
        return 'Show notification';
      case TaskActionType.launchIntent:
        return 'Show launch intent';
    }
  }

  String get description {
    switch (this) {
      case TaskActionType.openUrl:
        return 'Presents a link for the user to open.';
      case TaskActionType.copyText:
        return 'Copies the configured text to the clipboard.';
      case TaskActionType.showMessage:
        return 'Shows a message after the task runs.';
      case TaskActionType.haptic:
        return 'Triggers a short haptic confirmation.';
      case TaskActionType.wait:
        return 'Pauses the sequence for the configured number of seconds.';
      case TaskActionType.showNotification:
        return 'Displays a foreground notification in SasaTap.';
      case TaskActionType.launchIntent:
        return 'Presents a supported URI intent for user confirmation.';
    }
  }

  bool get requiresValue => this != TaskActionType.haptic;

  bool get requiresUri =>
      this == TaskActionType.openUrl || this == TaskActionType.launchIntent;
}

/// One ordered action in a tag automation sequence.
class TaskAction {
  const TaskAction({required this.type, this.value = ''});

  final TaskActionType type;
  final String value;

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.name,
    'value': value,
  };

  factory TaskAction.fromJson(Map<String, dynamic> json) {
    final name = json['type'] as String?;
    final type = TaskActionType.values.firstWhere(
      (candidate) => candidate.name == name,
      orElse: () => TaskActionType.showMessage,
    );
    return TaskAction(type: type, value: json['value'] as String? ?? '');
  }
}

/// A local automation profile mapping a tag UID to ordered actions.
///
/// The legacy [actionType] and [actionValue] constructor arguments and JSON
/// fields remain supported so previously saved one-action rules still load.
class AutomationTask {
  AutomationTask({
    required this.id,
    required this.name,
    required String tagUid,
    List<TaskAction>? actions,
    TaskActionType? actionType,
    String actionValue = '',
    this.enabled = true,
    this.triggerCount = 0,
    this.lastTriggeredAt,
  }) : tagUid = normalizeUid(tagUid),
       actions = List<TaskAction>.unmodifiable(
         actions ??
             <TaskAction>[
               TaskAction(
                 type: actionType ?? TaskActionType.showMessage,
                 value: actionValue,
               ),
             ],
       );

  final String id;
  final String name;

  /// Normalized uppercase hexadecimal UID without separators.
  final String tagUid;
  final List<TaskAction> actions;
  final bool enabled;
  final int triggerCount;
  final DateTime? lastTriggeredAt;

  /// Compatibility accessors for callers that display the first action.
  TaskActionType get actionType =>
      actions.isEmpty ? TaskActionType.showMessage : actions.first.type;

  String get actionValue => actions.isEmpty ? '' : actions.first.value;

  static String generateId() => 'task_${DateTime.now().microsecondsSinceEpoch}';

  AutomationTask copyWith({
    String? id,
    String? name,
    String? tagUid,
    List<TaskAction>? actions,
    TaskActionType? actionType,
    String? actionValue,
    bool? enabled,
    int? triggerCount,
    DateTime? lastTriggeredAt,
    bool clearLastTriggeredAt = false,
  }) {
    final updatedActions =
        actions ??
        (actionType != null || actionValue != null
            ? <TaskAction>[
                TaskAction(
                  type: actionType ?? this.actionType,
                  value: actionValue ?? this.actionValue,
                ),
                ...this.actions.skip(1),
              ]
            : this.actions);
    return AutomationTask(
      id: id ?? this.id,
      name: name ?? this.name,
      tagUid: tagUid ?? this.tagUid,
      actions: updatedActions,
      enabled: enabled ?? this.enabled,
      triggerCount: triggerCount ?? this.triggerCount,
      lastTriggeredAt: clearLastTriggeredAt
          ? null
          : (lastTriggeredAt ?? this.lastTriggeredAt),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'tagUid': tagUid,
    'actions': actions.map((action) => action.toJson()).toList(),
    // Kept during the schema transition for older app builds.
    'actionType': actionType.name,
    'actionValue': actionValue,
    'enabled': enabled,
    'triggerCount': triggerCount,
    'lastTriggeredAt': lastTriggeredAt?.toIso8601String(),
  };

  factory AutomationTask.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'];
    final List<TaskAction> actions;
    if (rawActions != null && rawActions is! List<dynamic>) {
      throw const FormatException(
        'An automation action list has an unsupported storage format.',
      );
    }
    if (rawActions is List<dynamic>) {
      actions = <TaskAction>[];
      for (final rawAction in rawActions) {
        if (rawAction is! Map<String, dynamic>) {
          throw const FormatException(
            'An automation action has an unsupported storage format.',
          );
        }
        actions.add(TaskAction.fromJson(rawAction));
      }
      if (actions.isEmpty) {
        throw const FormatException(
          'An automation must contain at least one action.',
        );
      }
    } else {
      actions = <TaskAction>[
        TaskAction(
          type: TaskActionType.values.firstWhere(
            (type) => type.name == json['actionType'],
            orElse: () => TaskActionType.showMessage,
          ),
          value: json['actionValue'] as String? ?? '',
        ),
      ];
    }
    return AutomationTask(
      id: json['id'] as String? ?? generateId(),
      name: json['name'] as String? ?? 'Untitled task',
      tagUid: normalizeUid(json['tagUid'] as String? ?? ''),
      actions: actions,
      enabled: json['enabled'] as bool? ?? true,
      triggerCount: (json['triggerCount'] as num?)?.toInt() ?? 0,
      lastTriggeredAt: DateTime.tryParse(
        json['lastTriggeredAt'] as String? ?? '',
      ),
    );
  }
}
