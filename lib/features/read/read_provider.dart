import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sasatap/core/nfc_service.dart';
import 'package:sasatap/features/tasks/task_executor.dart';
import 'package:sasatap/features/tasks/task_model.dart';

/// Owns the read workflow so the UI only deals with simple state.
class ReadProvider extends ChangeNotifier {
  ReadProvider(this._nfc, this._taskExecutor);

  final NfcService _nfc;
  final TaskExecutor _taskExecutor;

  bool _scanning = false;
  NfcTagScan? _scan;
  NfcException? _error;
  List<AutomationTask> _matchedTasks = const <AutomationTask>[];
  List<TaskExecutionResult> _executionResults = const <TaskExecutionResult>[];

  bool get scanning => _scanning;

  NfcTagScan? get scan => _scan;

  NfcException? get error => _error;

  List<AutomationTask> get matchedTasks => _matchedTasks;

  List<TaskExecutionResult> get executionResults => _executionResults;

  Future<void> scanTag() async {
    if (_scanning) {
      return;
    }
    _scanning = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _nfc.scan(
        alertMessage: 'Hold your phone near the tag to read it',
      );
      _scan = result;
      _matchedTasks = _taskExecutor.findEnabledForUid(result.uid);
      _executionResults = const <TaskExecutionResult>[];
      if (_matchedTasks.isNotEmpty) {
        await _nfc.close(iosAlertMessage: 'Automation matched');
        try {
          _executionResults = await _taskExecutor.executeForUid(result.uid);
        } on Object catch (error) {
          _error = NfcException('task_execution', error.toString());
        }
      }
    } on NfcException catch (error) {
      _error = error;
      _scan = null;
      _matchedTasks = const <AutomationTask>[];
      _executionResults = const <TaskExecutionResult>[];
    } on Object catch (error) {
      _error = NfcException('unexpected', error.toString());
      _scan = null;
      _matchedTasks = const <AutomationTask>[];
      _executionResults = const <TaskExecutionResult>[];
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  Future<void> closeSession() async {
    await _nfc.close(iosAlertMessage: 'Reader closed');
    notifyListeners();
  }

  void clear() {
    _scan = null;
    _error = null;
    _matchedTasks = const <AutomationTask>[];
    _executionResults = const <TaskExecutionResult>[];
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_nfc.close());
    super.dispose();
  }
}
