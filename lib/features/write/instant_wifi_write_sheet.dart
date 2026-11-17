import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sasatap/core/ndef_builder.dart';
import 'package:sasatap/features/write/write_provider.dart';

/// Shows a non-dismissible NFC progress sheet while the Wi-Fi record is
/// written. The sheet closes automatically on success and stays open with
/// actionable details when the write fails.
Future<void> showInstantWifiWriteSheet(
  BuildContext context, {
  required WifiCredentials credentials,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    builder: (_) => _InstantWifiWriteSheet(credentials: credentials),
  );
}

class _InstantWifiWriteSheet extends StatefulWidget {
  const _InstantWifiWriteSheet({required this.credentials});

  final WifiCredentials credentials;

  @override
  State<_InstantWifiWriteSheet> createState() => _InstantWifiWriteSheetState();
}

class _InstantWifiWriteSheetState extends State<_InstantWifiWriteSheet> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _started) {
        return;
      }
      _started = true;
      unawaited(_write());
    });
  }

  Future<void> _write() async {
    final provider = context.read<WriteProvider>();
    await provider.writeInstantWifi(widget.credentials);
    if (!mounted || provider.error != null || provider.result == null) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WriteProvider>();
    final error = provider.error;
    final success = provider.result != null && error == null;
    final theme = Theme.of(context);
    final color = error != null
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error != null
                  ? Icons.error_outline
                  : success
                  ? Icons.check_circle_outline
                  : Icons.nfc,
              size: 42,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              error != null
                  ? 'Wi-Fi write failed'
                  : success
                  ? 'Wi-Fi tag ready'
                  : 'Hold the tag near the phone',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error != null
                  ? error.message
                  : success
                  ? 'The Wi-Fi configuration is now on the tag. Android can '
                        'show a native connect prompt when the tag is tapped.'
                  : provider.status.isEmpty
                  ? 'Waiting for an NFC tag…'
                  : provider.status,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (error?.hint != null) ...[
              const SizedBox(height: 8),
              Text(
                error!.hint!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ] else if (!success) ...[
              const SizedBox(height: 22),
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                'Keep the tag still until the write completes.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
