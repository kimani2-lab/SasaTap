import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sasatap/core/ndef_inspector.dart';
import 'package:sasatap/core/nfc_service.dart';
import 'package:sasatap/features/read/read_provider.dart';
import 'package:sasatap/features/saved/saved_tag_repository.dart';
import 'package:sasatap/features/tasks/task_executor.dart';
import 'package:sasatap/features/tasks/task_intent.dart';
import 'package:sasatap/features/tasks/task_model.dart';
import 'package:sasatap/features/tasks/tasks_provider.dart';
import 'package:sasatap/shared/utils/ui_helpers.dart';
import 'package:sasatap/shared/widgets/ndef_record_tile.dart';
import 'package:sasatap/shared/widgets/nfc_availability_banner.dart';
import 'package:sasatap/shared/widgets/section_card.dart';
import 'package:sasatap/shared/widgets/tag_info_card.dart';

class ReadPage extends StatelessWidget {
  const ReadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReadProvider>(
      builder: (context, provider, _) {
        final scan = provider.scan;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const NfcAvailabilityBanner(),
            const SizedBox(height: 12),
            if (provider.scanning) const _ScanningCard(),
            if (provider.error != null)
              _ErrorCard(
                error: provider.error!,
                onRetry: () async {
                  await provider.scanTag();
                },
              ),
            if (!provider.scanning && scan == null && provider.error == null)
              _EmptyReadCard(
                onScan: () async {
                  await provider.scanTag();
                },
              ),
            if (scan != null) ...[
              TagInfoCard(
                scan: scan,
                onCopy: () => _copyTagDetails(context, scan),
              ),
              if (provider.matchedTasks.isNotEmpty) ...[
                const SizedBox(height: 12),
                _MatchedTasksCard(
                  tasks: provider.matchedTasks,
                  executions: provider.executionResults,
                ),
              ],
              const SizedBox(height: 12),
              SectionCard(
                title: 'NDEF records',
                subtitle: scan.records.isEmpty
                    ? 'No records were found on this tag.'
                    : '${scan.records.length} record(s) decoded.',
                icon: Icons.data_object,
                trailing: IconButton(
                  tooltip: 'Save tag to library',
                  onPressed: () async {
                    try {
                      await context.read<SavedTagRepository>().save(scan);
                      if (context.mounted) {
                        showAppSnackBar(context, 'Tag saved to your library.');
                      }
                    } on Object catch (error) {
                      if (context.mounted) {
                        showAppSnackBar(
                          context,
                          'Could not save tag: $error',
                          isError: true,
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.bookmark_add_outlined),
                ),
                child: scan.records.isEmpty
                    ? Text(
                        scan.ndefReadError ??
                            'The tag is blank or not NDEF formatted. '
                                'Use the Write tab to add a record.',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : Column(
                        children: [
                          for (final record in NdefInspector.inspect(
                            scan.records,
                          ))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: NdefRecordTile(record: record),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await provider.closeSession();
                        if (!context.mounted) return;
                        showAppSnackBar(context, 'NFC session closed.');
                      },
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Close session'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await provider.scanTag();
                      },
                      icon: const Icon(Icons.nfc),
                      label: const Text('Scan again'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _copyTagDetails(BuildContext context, NfcTagScan scan) async {
    final tag = scan.tag;
    final buffer = StringBuffer()
      ..writeln('SasaTap tag export')
      ..writeln('UID: ${scan.formattedUid}')
      ..writeln('Standard: ${tag.standard}')
      ..writeln('Type: ${tag.type.name}')
      ..writeln('ATQA: ${tag.atqa ?? '-'}')
      ..writeln('SAK: ${tag.sak ?? '-'}')
      ..writeln('NDEF available: ${tag.ndefAvailable ?? 'unknown'}')
      ..writeln('NDEF writable: ${tag.ndefWritable ?? 'unknown'}')
      ..writeln('NDEF capacity: ${tag.ndefCapacity ?? 'unknown'} bytes')
      ..writeln('Records: ${scan.records.length}');
    if (scan.records.isNotEmpty) {
      buffer.writeln('---');
      for (final record in scan.records) {
        buffer.writeln(record.toString());
      }
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (context.mounted) {
      showAppSnackBar(context, 'Tag details copied to clipboard.');
    }
  }
}

class _EmptyReadCard extends StatelessWidget {
  const _EmptyReadCard({required this.onScan});

  final Future<void> Function() onScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          children: [
            Container(
              height: 208,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFF123C5A),
                    Color(0xFF0C243B),
                    Color(0xFF0A192B),
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (final size in <double>[174, 144, 112])
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.18),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.08),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary.withValues(alpha: 0.26),
                          const Color(0xFF07516A),
                        ],
                      ),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.72),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.phone_android,
                      size: 48,
                      color: scheme.primary,
                    ),
                  ),
                  Positioned(
                    right: 68,
                    top: 82,
                    child: Icon(
                      Icons.contactless,
                      size: 34,
                      color: scheme.primary,
                    ),
                  ),
                  Positioned(
                    left: 67,
                    bottom: 58,
                    child: Icon(
                      Icons.nfc,
                      size: 25,
                      color: scheme.primary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Tap an NFC Tag',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Align the tag with the top of your phone for best results.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await onScan();
                },
                icon: const Icon(Icons.nfc),
                label: const Text('Start Scan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanningCard extends StatelessWidget {
  const _ScanningCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Waiting for an NFC tag…',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Keep the tag still against the NFC antenna.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});

  final NfcException error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: scheme.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    error.message,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
            if (error.hint != null) ...[
              const SizedBox(height: 8),
              Text(
                error.hint!,
                style: TextStyle(
                  color: scheme.onErrorContainer.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  await onRetry();
                },
                child: const Text('Try again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchedTasksCard extends StatelessWidget {
  const _MatchedTasksCard({required this.tasks, required this.executions});

  final List<AutomationTask> tasks;
  final List<TaskExecutionResult> executions;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Automation matched',
      subtitle: 'This UID has local tasks attached to it.',
      icon: Icons.bolt,
      child: Column(
        children: [
          for (final task in tasks)
            Builder(
              builder: (context) {
                final intent = TaskIntent.fromTask(task);
                final matchingExecutions = executions
                    .where((result) => result.task.id == task.id)
                    .toList(growable: false);
                final execution = matchingExecutions.isEmpty
                    ? null
                    : matchingExecutions.first;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(intent.icon),
                  title: Text(task.name),
                  subtitle: Text(
                    execution == null
                        ? '${task.actions.length} sequential action(s)'
                        : execution.error ??
                              '${execution.actions.length} action(s) completed',
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: () async {
                      if (execution != null) {
                        await showTaskExecutionResult(context, execution);
                      } else {
                        try {
                          final result = await context
                              .read<TasksProvider>()
                              .runTask(task);
                          if (context.mounted) {
                            await showTaskExecutionResult(context, result);
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
                      }
                    },
                    child: Text(execution == null ? 'Run' : 'View'),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
