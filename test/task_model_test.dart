import 'package:flutter_test/flutter_test.dart';
import 'package:sasatap/features/tasks/task_model.dart';

void main() {
  group('AutomationTask', () {
    test('round-trips through JSON', () {
      final task = AutomationTask(
        id: 'task_1',
        name: 'Office door',
        tagUid: '04A21B8C',
        actionType: TaskActionType.openUrl,
        actionValue: 'https://example.com',
        triggerCount: 3,
        lastTriggeredAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      );

      final decoded = AutomationTask.fromJson(task.toJson());

      expect(decoded.id, task.id);
      expect(decoded.name, task.name);
      expect(decoded.tagUid, task.tagUid);
      expect(decoded.actionType, task.actionType);
      expect(decoded.actionValue, task.actionValue);
      expect(decoded.triggerCount, 3);
      expect(decoded.lastTriggeredAt, task.lastTriggeredAt);
    });

    test('round-trips sequential actions', () {
      final task = AutomationTask(
        id: 'task_sequence',
        name: 'Welcome station',
        tagUid: '04A21B8C',
        actions: const <TaskAction>[
          TaskAction(type: TaskActionType.showNotification, value: 'Welcome'),
          TaskAction(type: TaskActionType.wait, value: '2'),
          TaskAction(
            type: TaskActionType.openUrl,
            value: 'https://example.com',
          ),
        ],
      );

      final decoded = AutomationTask.fromJson(task.toJson());

      expect(decoded.actions, hasLength(3));
      expect(decoded.actions[0].type, TaskActionType.showNotification);
      expect(decoded.actions[1].value, '2');
      expect(decoded.actions[2].value, 'https://example.com');
    });

    test('loads legacy single-action storage as a one-step sequence', () {
      final decoded = AutomationTask.fromJson(<String, dynamic>{
        'id': 'task_legacy',
        'name': 'Legacy rule',
        'tagUid': '04:A2:1B:8C',
        'actionType': 'openUrl',
        'actionValue': 'https://example.com',
      });

      expect(decoded.actions, hasLength(1));
      expect(decoded.actions.single.type, TaskActionType.openUrl);
      expect(decoded.actions.single.value, 'https://example.com');
    });

    test('normalizes UIDs loaded from old data', () {
      final decoded = AutomationTask.fromJson(<String, dynamic>{
        'id': 'task_2',
        'name': 'Wi-Fi',
        'tagUid': '04:a2 1b:8c',
        'actionType': 'unknown_action',
        'actionValue': '',
      });

      expect(decoded.tagUid, '04A21B8C');
      expect(decoded.actionType, TaskActionType.showMessage);
      expect(decoded.enabled, isTrue);
    });

    test('copyWith can clear the last trigger timestamp', () {
      final task = AutomationTask(
        id: 'task_3',
        name: 'Test',
        tagUid: '04A21B8C',
        actionType: TaskActionType.haptic,
        actionValue: '',
        lastTriggeredAt: DateTime.now(),
      );

      expect(task.copyWith(clearLastTriggeredAt: true).lastTriggeredAt, isNull);
    });

    test('only haptic actions do not require a value', () {
      expect(TaskActionType.haptic.requiresValue, isFalse);
      expect(TaskActionType.openUrl.requiresValue, isTrue);
      expect(TaskActionType.copyText.requiresValue, isTrue);
      expect(TaskActionType.showMessage.requiresValue, isTrue);
    });
  });
}
