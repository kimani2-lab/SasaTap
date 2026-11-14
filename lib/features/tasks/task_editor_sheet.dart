import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sasatap/core/hex_utils.dart';
import 'package:sasatap/features/tasks/task_model.dart';
import 'package:sasatap/features/tasks/tasks_provider.dart';
import 'package:sasatap/shared/utils/ui_helpers.dart';

/// Bottom sheet for creating or editing a local automation sequence.
class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({super.key, this.task});

  final AutomationTask? task;

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _uid;
  late final List<_ActionDraft> _actions;
  late bool _enabled;
  bool _capturing = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _name = TextEditingController(text: task?.name ?? '');
    _uid = TextEditingController(
      text: task == null ? '' : formatUid(task.tagUid),
    );
    _actions = task == null || task.actions.isEmpty
        ? <_ActionDraft>[_ActionDraft(type: TaskActionType.showMessage)]
        : task.actions.map(_ActionDraft.fromAction).toList();
    _enabled = task?.enabled ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _uid.dispose();
    for (final action in _actions) {
      action.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit automation' : 'New automation',
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Task name',
                    hintText: 'Welcome a visitor',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Give the task a name.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _uid,
                  style: const TextStyle(fontFamily: 'monospace'),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Tag UID',
                    hintText: '04 A2 1B 8C 5D 6E 7F',
                    helperText: 'Scan a tag or enter its UID in hexadecimal.',
                    prefixIcon: const Icon(Icons.fingerprint),
                    suffixIcon: _capturing
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            tooltip: 'Scan tag UID',
                            onPressed: _captureUid,
                            icon: const Icon(Icons.nfc),
                          ),
                  ),
                  validator: (value) {
                    if (value == null || normalizeUid(value).isEmpty) {
                      return 'Enter or scan a tag UID.';
                    }
                    if (!isValidHex(value)) {
                      return 'The UID must contain an even number of hex digits.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sequential actions',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addAction,
                      icon: const Icon(Icons.add),
                      label: const Text('Add action'),
                    ),
                  ],
                ),
                Text(
                  'Actions run in order after this tag is scanned. External '
                  'links are shown for confirmation.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                for (var index = 0; index < _actions.length; index++)
                  _buildActionCard(index),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enabled'),
                  subtitle: const Text(
                    'Only enabled automations run when their tag is scanned.',
                  ),
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.check),
                        label: Text(
                          _isEditing ? 'Save changes' : 'Create task',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(int index) {
    final draft = _actions[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(radius: 15, child: Text('${index + 1}')),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<TaskActionType>(
                    initialValue: draft.type,
                    decoration: const InputDecoration(labelText: 'Action type'),
                    items: [
                      for (final type in TaskActionType.values)
                        DropdownMenuItem(value: type, child: Text(type.label)),
                    ],
                    onChanged: (type) {
                      if (type != null) {
                        setState(() => draft.type = type);
                      }
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Move action up',
                  onPressed: index == 0 ? null : () => _moveAction(index, -1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'Move action down',
                  onPressed: index == _actions.length - 1
                      ? null
                      : () => _moveAction(index, 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: 'Remove action',
                  onPressed: _actions.length == 1
                      ? null
                      : () => _removeAction(index),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  draft.type.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            if (draft.type.requiresValue)
              TextFormField(
                controller: draft.value,
                keyboardType: _keyboardType(draft.type),
                minLines:
                    draft.type == TaskActionType.showMessage ||
                        draft.type == TaskActionType.showNotification
                    ? 2
                    : 1,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: _valueLabel(draft.type),
                  hintText: _valueHint(draft.type),
                  helperText: draft.type == TaskActionType.wait
                      ? 'Whole seconds, from 0 to $maxTaskWaitSeconds.'
                      : null,
                  alignLabelWithHint: true,
                ),
                validator: (value) => _validateActionValue(draft.type, value),
              ),
          ],
        ),
      ),
    );
  }

  static TextInputType _keyboardType(TaskActionType type) {
    if (type.requiresUri) {
      return TextInputType.url;
    }
    if (type == TaskActionType.wait) {
      return TextInputType.number;
    }
    return TextInputType.multiline;
  }

  static String _valueLabel(TaskActionType type) {
    switch (type) {
      case TaskActionType.openUrl:
        return 'Link';
      case TaskActionType.launchIntent:
        return 'Intent URI';
      case TaskActionType.copyText:
        return 'Text to copy';
      case TaskActionType.showMessage:
      case TaskActionType.showNotification:
        return 'Message';
      case TaskActionType.wait:
        return 'Duration in seconds';
      case TaskActionType.haptic:
        return '';
    }
  }

  static String _valueHint(TaskActionType type) {
    switch (type) {
      case TaskActionType.openUrl:
        return 'https://example.com';
      case TaskActionType.launchIntent:
        return 'https://example.com or mailto:team@example.com';
      case TaskActionType.copyText:
        return 'Text to place on the clipboard';
      case TaskActionType.showMessage:
      case TaskActionType.showNotification:
        return 'Message shown when the action runs';
      case TaskActionType.wait:
        return '5';
      case TaskActionType.haptic:
        return '';
    }
  }

  String? _validateActionValue(TaskActionType type, String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) {
      return type == TaskActionType.wait
          ? 'Enter a wait duration.'
          : 'Enter a value for this action.';
    }
    if (type == TaskActionType.wait) {
      final seconds = int.tryParse(value);
      if (seconds == null || seconds < 0 || seconds > maxTaskWaitSeconds) {
        return 'Enter a whole number from 0 to $maxTaskWaitSeconds.';
      }
    }
    if (type.requiresUri) {
      final uri = Uri.tryParse(value);
      if (uri == null ||
          !uri.hasScheme ||
          !const <String>{
            'http',
            'https',
            'mailto',
            'tel',
          }.contains(uri.scheme.toLowerCase())) {
        return 'Use a valid http(s), mailto or tel URI.';
      }
    }
    return null;
  }

  void _addAction() {
    setState(
      () => _actions.add(_ActionDraft(type: TaskActionType.showMessage)),
    );
  }

  void _removeAction(int index) {
    final removed = _actions.removeAt(index);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  void _moveAction(int index, int offset) {
    final target = index + offset;
    if (target < 0 || target >= _actions.length) {
      return;
    }
    setState(() {
      final action = _actions.removeAt(index);
      _actions.insert(target, action);
    });
  }

  Future<void> _captureUid() async {
    setState(() => _capturing = true);
    final provider = context.read<TasksProvider>();
    final uid = await provider.captureUid();
    if (!mounted) {
      return;
    }
    setState(() => _capturing = false);
    if (uid != null && uid.isNotEmpty) {
      _uid.text = formatUid(uid);
    } else {
      final error = provider.error;
      if (error != null) {
        showAppSnackBar(context, error.message, isError: true);
      }
    }
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final existing = widget.task;
    final task = AutomationTask(
      id: existing?.id ?? AutomationTask.generateId(),
      name: _name.text.trim(),
      tagUid: normalizeUid(_uid.text),
      actions: _actions
          .map(
            (draft) => TaskAction(
              type: draft.type,
              value: draft.type.requiresValue ? draft.value.text.trim() : '',
            ),
          )
          .toList(growable: false),
      enabled: _enabled,
      triggerCount: existing?.triggerCount ?? 0,
      lastTriggeredAt: existing?.lastTriggeredAt,
    );
    Navigator.of(context).pop(task);
  }
}

class _ActionDraft {
  _ActionDraft({required this.type, String value = ''})
    : value = TextEditingController(text: value);

  factory _ActionDraft.fromAction(TaskAction action) =>
      _ActionDraft(type: action.type, value: action.value);

  TaskActionType type;
  final TextEditingController value;

  void dispose() => value.dispose();
}
