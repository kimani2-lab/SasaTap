import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sasatap/core/nfc_service.dart';
import 'package:sasatap/features/tasks/task_executor.dart';
import 'package:sasatap/features/tasks/task_model.dart';
import 'package:sasatap/features/tasks/task_repository.dart';

/// Coordinates task persistence and UID matching.
class TasksProvider extends ChangeNotifier {
  TasksProvider(this._nfc, this._repository, this._executor) {
    _repository.addListener(_syncTasks);
  }

  final NfcService _nfc;
  final TaskRepository _repository;
  final TaskExecutor _executor;

  List<AutomationTask> _tasks = const <AutomationTask>[];
  List<AutomationTask> _lastMatches = const <AutomationTask>[];
  bool _busy = false;
  NfcException? _error;
  String? _message;
  NfcTagScan? _scan;
  TaskExecutionResult? _lastExecution;

  List<AutomationTask> get tasks => _tasks;

  List<AutomationTask> get lastMatches => _lastMatches;

  bool get busy => _busy;

  NfcException? get error => _error;

  String? get message => _message;

  NfcTagScan? get scan => _scan;

  TaskExecutionResult? get lastExecution => _lastExecution;

  void syncFromRepository() {
    _tasks = _repository.all;
    final warning = _repository.loadWarning;
    if (warning != null) {
      _error = NfcException('task_storage', warning);
    }
    notifyListeners();
  }

  void _syncTasks() {
    _tasks = _repository.all;
    notifyListeners();
  }

  Future<void> saveTask(AutomationTask task) async {
    try {
      await _repository.upsert(task);
      _repository.clearLoadWarning();
      _tasks = _repository.all;
      _message = 'Task saved.';
      _error = null;
    } on Object catch (error) {
      _error = NfcException('task_storage', error.toString());
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      await _repository.delete(id);
      _repository.clearLoadWarning();
      _tasks = _repository.all;
      _message = 'Task deleted.';
      _error = null;
    } on Object catch (error) {
      _error = NfcException('task_storage', error.toString());
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> setEnabled(AutomationTask task, bool enabled) async {
    try {
      await _repository.setEnabled(task.id, enabled);
      _repository.clearLoadWarning();
      _tasks = _repository.all;
      _error = null;
    } on Object catch (error) {
      _error = NfcException('task_storage', error.toString());
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// Runs one saved automation's actions in sequence.
  Future<TaskExecutionResult> runTask(AutomationTask task) async {
    if (_busy) {
      throw const TaskExecutionException(
        'Another task operation is already running.',
      );
    }
    _busy = true;
    _error = null;
    _message = null;
    _lastExecution = null;
    notifyListeners();
    try {
      final result = await _executor.execute(task);
      _lastExecution = result;
      _tasks = _repository.all;
      _message = 'Task "${task.name}" completed.';
      return result;
    } on Object catch (error) {
      _error = NfcException('task_execution', error.toString());
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Polls a tag, closes the session, and returns all enabled tasks for its
  /// UID. An empty list is a valid result.
  Future<List<AutomationTask>> scanAndMatch() async {
    if (_busy) {
      return const <AutomationTask>[];
    }
    _busy = true;
    _error = null;
    _message = null;
    _lastMatches = const <AutomationTask>[];
    _lastExecution = null;
    notifyListeners();

    try {
      final scan = await _nfc.scan(
        alertMessage: 'Hold your phone near the tag to find its tasks',
      );
      _scan = scan;
      _lastMatches = _repository
          .findByUid(scan.uid)
          .where((task) => task.enabled)
          .toList(growable: false);
      _lastExecution = null;
      await _nfc.close(iosAlertMessage: 'Task lookup complete');
      if (_lastMatches.isEmpty) {
        _message = 'No enabled task matches UID ${scan.formattedUid}.';
      }
      return _lastMatches;
    } on NfcException catch (error) {
      _error = error;
      _lastMatches = const <AutomationTask>[];
      return const <AutomationTask>[];
    } on Object catch (error) {
      _error = NfcException('unexpected', error.toString());
      _lastMatches = const <AutomationTask>[];
      return const <AutomationTask>[];
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Scans a tag and returns its normalized UID, used by the task editor.
  Future<String?> captureUid() async {
    if (_busy) {
      return null;
    }
    _busy = true;
    _error = null;
    _message = null;
    notifyListeners();

    try {
      final scan = await _nfc.scan(
        alertMessage: 'Hold your phone near the tag to capture its UID',
      );
      _scan = scan;
      await _nfc.close(iosAlertMessage: 'UID captured');
      return scan.uid;
    } on NfcException catch (error) {
      _error = error;
      return null;
    } on Object catch (error) {
      _error = NfcException('unexpected', error.toString());
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void clearFeedback() {
    _error = null;
    _message = null;
    _lastExecution = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.removeListener(_syncTasks);
    unawaited(_nfc.close());
    super.dispose();
  }
}
