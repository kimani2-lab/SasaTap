import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sasatap/core/hex_utils.dart';
import 'package:sasatap/features/tasks/task_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaskRepositoryException implements Exception {
  const TaskRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Persists automation rules as JSON in [SharedPreferences].
class TaskRepository extends ChangeNotifier {
  TaskRepository(this._preferences);

  static const String storageKey = 'sasatap.tasks.v1';

  final SharedPreferences _preferences;
  List<AutomationTask> _tasks = const <AutomationTask>[];
  String? _loadWarning;

  List<AutomationTask> get all => List<AutomationTask>.unmodifiable(_tasks);

  String? get loadWarning => _loadWarning;

  Future<void> load() async {
    _loadWarning = null;
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      _tasks = const <AutomationTask>[];
      notifyListeners();
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        throw const FormatException(
          'Saved automations have an unsupported storage format.',
        );
      }
      final tasks = <AutomationTask>[];
      for (final rawTask in decoded) {
        if (rawTask is! Map<String, dynamic>) {
          throw const FormatException(
            'A saved automation has an unsupported storage format.',
          );
        }
        final task = AutomationTask.fromJson(rawTask);
        if (task.id.trim().isEmpty ||
            task.name.trim().isEmpty ||
            task.tagUid.isEmpty ||
            !isValidHex(task.tagUid) ||
            task.actions.isEmpty) {
          throw const FormatException(
            'A saved automation has an invalid ID, tag UID or action list.',
          );
        }
        tasks.add(task);
      }
      _tasks = List<AutomationTask>.unmodifiable(tasks);
    } on FormatException catch (error) {
      _setLoadWarning(error);
    } on TypeError catch (error) {
      _setLoadWarning(error);
    }
    notifyListeners();
  }

  List<AutomationTask> findByUid(String uid) {
    final normalized = normalizeUid(uid);
    if (normalized.isEmpty) {
      return const <AutomationTask>[];
    }
    return _tasks
        .where((task) => task.tagUid == normalized)
        .toList(growable: false);
  }

  AutomationTask? findById(String id) {
    for (final task in _tasks) {
      if (task.id == id) {
        return task;
      }
    }
    return null;
  }

  Future<void> upsert(AutomationTask task) async {
    if (task.id.trim().isEmpty ||
        task.name.trim().isEmpty ||
        !isValidHex(task.tagUid) ||
        task.actions.isEmpty) {
      throw const TaskRepositoryException(
        'A saved automation needs a name, valid tag UID and at least one action.',
      );
    }
    final updated = List<AutomationTask>.of(_tasks);
    final index = updated.indexWhere((entry) => entry.id == task.id);
    if (index >= 0) {
      updated[index] = task;
    } else {
      updated.insert(0, task);
    }
    await _persist(updated);
    _tasks = updated;
    notifyListeners();
  }

  Future<void> delete(String id) async {
    final updated = _tasks
        .where((task) => task.id != id)
        .toList(growable: false);
    await _persist(updated);
    _tasks = updated;
    notifyListeners();
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final task = findById(id);
    if (task == null) {
      return;
    }
    await upsert(task.copyWith(enabled: enabled));
  }

  Future<void> markTriggered(String id) async {
    final task = findById(id);
    if (task == null) {
      return;
    }
    await upsert(
      task.copyWith(
        triggerCount: task.triggerCount + 1,
        lastTriggeredAt: DateTime.now(),
      ),
    );
  }

  Future<void> _persist(List<AutomationTask> tasks) async {
    final encoded = jsonEncode(
      tasks.map((task) => task.toJson()).toList(growable: false),
    );
    final saved = await _preferences.setString(storageKey, encoded);
    if (!saved) {
      throw const TaskRepositoryException(
        'Automations could not be saved to device storage.',
      );
    }
  }

  void clearLoadWarning() {
    _loadWarning = null;
  }

  void _setLoadWarning(Object error) {
    _tasks = const <AutomationTask>[];
    _loadWarning =
        'Saved automations could not be loaded: $error. '
        'Saving a change will replace the unreadable stored data.';
  }
}
