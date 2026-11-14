import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sasatap/core/hex_utils.dart';
import 'package:sasatap/core/nfc_service.dart';
import 'package:sasatap/features/other/other_provider.dart';
import 'package:sasatap/shared/utils/ui_helpers.dart';
import 'package:sasatap/shared/widgets/nfc_availability_banner.dart';
import 'package:sasatap/shared/widgets/section_card.dart';
import 'package:sasatap/shared/widgets/tag_info_card.dart';

class TagToolsPage extends StatefulWidget {
  const TagToolsPage({super.key});

  @override
  State<TagToolsPage> createState() => _TagToolsPageState();
}

class _TagToolsPageState extends State<TagToolsPage> {
  final _password = TextEditingController();
  final _pack = TextEditingController(text: '0000');
  final _firstPage = TextEditingController(text: '4');
  final _command = TextEditingController(text: '30 04');

  @override
  void dispose() {
    _password.dispose();
    _pack.dispose();
    _firstPage.dispose();
    _command.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OtherProvider>(
      builder: (context, provider, _) {
        final scan = provider.scan;
        final ready = scan != null && !provider.busy;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const NfcAvailabilityBanner(),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Tag session',
              subtitle: scan == null
                  ? 'No tag connected'
                  : 'Connected to ${scan.formattedUid}',
              icon: Icons.sensors,
              trailing: scan == null
                  ? null
                  : TextButton(
                      onPressed: provider.busy
                          ? null
                          : () async {
                              await provider.closeSession();
                            },
                      child: const Text('Close'),
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (scan == null)
                    Text(
                      'Scan a tag to unlock memory dumping, formatting, '
                      'password protection and raw commands.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (scan != null)
                    Text(
                      'Keep the tag against the phone while running tools.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: provider.busy ? null : provider.scanTag,
                      icon: const Icon(Icons.nfc),
                      label: Text(
                        scan == null ? 'Scan tag' : 'Scan another tag',
                      ),
                    ),
                  ),
                  if (provider.busy) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
            if (scan != null) ...[
              const SizedBox(height: 12),
              TagInfoCard(scan: scan),
            ],
            if (provider.error != null) ...[
              const SizedBox(height: 12),
              _FeedbackCard(
                error: provider.error,
                message: null,
                onDismiss: provider.clearFeedback,
              ),
            ] else if (provider.message != null) ...[
              const SizedBox(height: 12),
              _FeedbackCard(
                error: null,
                message: provider.message,
                onDismiss: provider.clearFeedback,
              ),
            ],
            const SizedBox(height: 12),
            SectionCard(
              title: 'Memory dump',
              subtitle:
                  'Reads Type 2 pages, ISO 15693 blocks or MIFARE '
                  'Classic sectors.',
              icon: Icons.storage_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: ready ? provider.dumpMemory : null,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Dump memory'),
                    ),
                  ),
                  if (provider.dump != null) ...[
                    const SizedBox(height: 12),
                    _MemoryDumpView(dump: provider.dump!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Format and erase',
              subtitle:
                  'Formatting initialises a Type 2 tag with a fresh '
                  'Capability Container. Erasing clears the NDEF message.',
              icon: Icons.cleaning_services_outlined,
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: ready
                          ? () => _confirm(
                              context,
                              title: 'Format this tag?',
                              message:
                                  'This writes a new Type 2 Capability '
                                  'Container and erases the current NDEF '
                                  'message. It only works on MIFARE '
                                  'Ultralight/NTAG tags and may fail on locked '
                                  'tags.',
                              confirmLabel: 'Format',
                              action: provider.format,
                            )
                          : null,
                      icon: const Icon(Icons.build_circle_outlined),
                      label: const Text('Format as NDEF'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: ready
                          ? () => _confirm(
                              context,
                              title: 'Erase the NDEF message?',
                              message:
                                  'The tag stays formatted, but all NDEF '
                                  'records are removed.',
                              confirmLabel: 'Erase',
                              action: provider.erase,
                            )
                          : null,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Erase NDEF message'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Make read-only',
              subtitle: 'Permanently locks the NDEF area of the tag.',
              icon: Icons.lock_outline,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This action cannot be undone. Only use it on tags you '
                    'intend to keep permanently immutable.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.errorContainer,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onErrorContainer,
                      ),
                      onPressed: ready
                          ? () => _confirm(
                              context,
                              title: 'Make this tag read-only?',
                              message:
                                  'The NDEF area will be locked forever. '
                                  'This cannot be reversed.',
                              confirmLabel: 'Lock tag',
                              action: provider.makeReadOnly,
                            )
                          : null,
                      icon: const Icon(Icons.lock),
                      label: const Text('Lock NDEF area'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'NTAG password protection',
              subtitle:
                  'NTAG213/215/216 only. Write protection begins at the '
                  'first protected page.',
              icon: Icons.password,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _firstPage,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'First protected page',
                            helperText: 'Usually 4',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _pack,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp('[0-9a-fA-F ]'),
                            ),
                            LengthLimitingTextInputFormatter(8),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'PACK',
                            helperText: '2 bytes, e.g. 1234',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F ]')),
                      LengthLimitingTextInputFormatter(11),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      helperText: '4 bytes in hexadecimal, e.g. A1B2C3D4',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: ready
                              ? () => _setPassword(context, provider)
                              : null,
                          child: const Text('Set password'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: ready
                              ? () => _removePassword(context, provider)
                              : null,
                          child: const Text('Remove'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keep a record of the password and PACK. Losing them can '
                    'leave the tag permanently unwritable.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Raw transceive',
              subtitle:
                  'Send APDUs or technology commands. Responses are '
                  'displayed as hexadecimal.',
              icon: Icons.terminal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _command,
                    style: const TextStyle(fontFamily: 'monospace'),
                    minLines: 1,
                    maxLines: 3,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp('[0-9a-fA-F xX]'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Command (hex)',
                      hintText: '30 04',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final command in const <String>[
                        '30 00',
                        '60',
                        '3A 00 00',
                      ])
                        ActionChip(
                          label: Text(command),
                          onPressed: ready
                              ? () {
                                  _command.text = command;
                                }
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: ready
                          ? () => _sendCommand(context, provider)
                          : null,
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Send command'),
                    ),
                  ),
                  if (provider.transceiveOutput != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SelectableText(
                          provider.transceiveOutput!.isEmpty
                              ? '(empty response)'
                              : provider.transceiveOutput!,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() action,
  }) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
    );
    if (!confirmed) {
      return;
    }
    await action();
  }

  Future<void> _setPassword(
    BuildContext context,
    OtherProvider provider,
  ) async {
    final password = _cleanHex(_password.text);
    final pack = _cleanHex(_pack.text);
    final firstPage = int.tryParse(_firstPage.text.trim());

    if (password.length != 8) {
      showAppSnackBar(
        context,
        'Password must be exactly 4 bytes (8 hex digits).',
        isError: true,
      );
      return;
    }
    if (pack.length != 4) {
      showAppSnackBar(
        context,
        'PACK must be exactly 2 bytes (4 hex digits).',
        isError: true,
      );
      return;
    }
    if (firstPage == null || firstPage < 0 || firstPage > 255) {
      showAppSnackBar(
        context,
        'First protected page must be between 0 and 255.',
        isError: true,
      );
      return;
    }

    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Enable password protection?',
      message:
          'SasaTap will write PWD, PACK and the NTAG configuration '
          'pages. If you lose this password, the tag may become permanently '
          'unwritable. Only continue for NTAG213/215/216 tags.',
      confirmLabel: 'Enable protection',
    );
    if (!confirmed) {
      return;
    }
    await provider.setPassword(
      password: password,
      pack: pack,
      firstProtectedPage: firstPage,
    );
  }

  Future<void> _removePassword(
    BuildContext context,
    OtherProvider provider,
  ) async {
    final password = _cleanHex(_password.text);
    if (password.length != 8) {
      showAppSnackBar(
        context,
        'Enter the current 4-byte password as 8 hexadecimal digits.',
        isError: true,
      );
      return;
    }
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Remove password protection?',
      message:
          'The current password is required to authenticate before the '
          'configuration can be changed.',
      confirmLabel: 'Remove protection',
    );
    if (!confirmed) {
      return;
    }
    await provider.removePassword(password);
  }

  Future<void> _sendCommand(
    BuildContext context,
    OtherProvider provider,
  ) async {
    final command = _command.text.trim();
    if (!isValidHex(command)) {
      showAppSnackBar(
        context,
        'Enter an even number of hexadecimal digits.',
        isError: true,
      );
      return;
    }
    await provider.transceive(command);
  }

  static String _cleanHex(String value) =>
      value.replaceAll(RegExp('[^0-9a-fA-F]'), '').toUpperCase();
}

class _MemoryDumpView extends StatelessWidget {
  const _MemoryDumpView({required this.dump});

  final MemoryDump dump;

  @override
  Widget build(BuildContext context) {
    final buffer = StringBuffer();
    for (final page in dump.pages) {
      buffer.writeln('${page.label.padRight(12)} ${bytesToHex(page.bytes)}');
    }
    if (dump.truncated) {
      buffer.writeln(
        '\nRead stopped early (locked memory, password protection or tag '
        'lost).',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${dump.title} • ${dump.pages.length} entries • '
          '${formatBytes(dump.totalBytes)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 280),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                buffer.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.error,
    required this.message,
    required this.onDismiss,
  });

  final NfcException? error;
  final String? message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isError = error != null;
    final background = isError
        ? scheme.errorContainer
        : scheme.primaryContainer;
    final foreground = isError
        ? scheme.onErrorContainer
        : scheme.onPrimaryContainer;

    return Card(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: foreground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isError ? error!.message : message ?? '',
                    style: TextStyle(color: foreground),
                  ),
                  if (isError && error!.hint != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      error!.hint!,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              icon: Icon(Icons.close, color: foreground, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
