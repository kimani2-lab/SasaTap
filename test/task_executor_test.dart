import 'package:flutter_test/flutter_test.dart';
import 'package:sasatap/features/tasks/task_executor.dart';
import 'package:sasatap/features/tasks/task_model.dart';
import 'package:sasatap/features/tasks/task_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaskExecutor', () {
    late TaskRepository repository;
    late TaskExecutor executor;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      repository = TaskRepository(await SharedPreferences.getInstance());
      await repository.load();
      executor = TaskExecutor(repository);
    });

    test(
      'runs matching enabled actions in sequence and records trigger',
      () async {
        final task = AutomationTask(
          id: 'welcome',
          name: 'Welcome station',
          tagUid: '04:A2:1B:8C',
          actions: const <TaskAction>[
            TaskAction(type: TaskActionType.showNotification, value: 'Welcome'),
            TaskAction(type: TaskActionType.wait, value: '0'),
          ],
        );
        await repository.upsert(task);

        final results = await executor.executeForUid('04a21b8c');

        expect(results, hasLength(1));
        expect(results.single.actions, hasLength(2));
        expect(results.single.actions.first.message, 'Welcome');
        expect(repository.findById(task.id)?.triggerCount, 1);
      },
    );

    test('does not execute disabled tasks', () async {
      await repository.upsert(
        AutomationTask(
          id: 'disabled',
          name: 'Disabled task',
          tagUid: '04A21B8C',
          actions: const <TaskAction>[
            TaskAction(type: TaskActionType.showMessage, value: 'No'),
          ],
          enabled: false,
        ),
      );

      expect(await executor.executeForUid('04A21B8C'), isEmpty);
    });

    test('rejects unsupported URI schemes', () async {
      final task = AutomationTask(
        id: 'unsafe-uri',
        name: 'Unsafe URI',
        tagUid: '04A21B8C',
        actions: const <TaskAction>[
          TaskAction(
            type: TaskActionType.launchIntent,
            value: 'file:///secret',
          ),
        ],
      );
      await repository.upsert(task);

      await expectLater(
        executor.execute(task),
        throwsA(isA<TaskExecutionException>()),
      );
      expect(repository.findById(task.id)?.triggerCount, 0);
    });
  });
}
