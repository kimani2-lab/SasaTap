import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:sasatap/core/nfc_service.dart';
import 'package:sasatap/shared/utils/ui_helpers.dart';

/// Displays the metadata exposed by `flutter_nfc_kit` for a polled tag.
class TagInfoCard extends StatelessWidget {
  const TagInfoCard({super.key, required this.scan, this.onCopy});

  final NfcTagScan scan;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final tag = scan.tag;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final rows = <(String, String)>[
      ('UID', scan.formattedUid),
      ('Standard', tag.standard.trim().isEmpty ? 'Unknown' : tag.standard),
      ('Tag type', _tagTypeLabel(tag.type)),
      if (_has(tag.atqa)) ('ATQA', tag.atqa!),
      if (_has(tag.sak)) ('SAK', tag.sak!),
      if (_has(tag.protocolInfo)) ('Protocol info', tag.protocolInfo!),
      if (_has(tag.historicalBytes)) ('Historical bytes', tag.historicalBytes!),
      if (_has(tag.applicationData)) ('Application data', tag.applicationData!),
      if (_has(tag.manufacturer)) ('Manufacturer', tag.manufacturer!),
      if (_has(tag.systemCode)) ('System code', tag.systemCode!),
      if (_has(tag.dsfId)) ('DSF ID', tag.dsfId!),
      if (_has(tag.ndefType)) ('NDEF type', tag.ndefType!),
      (
        'NDEF capacity',
        tag.ndefCapacity == null
            ? 'Not reported'
            : formatBytes(tag.ndefCapacity!),
      ),
      ('NDEF status', _ndefStatus(tag)),
      ('Can make read-only', _yesNo(tag.ndefCanMakeReadOnly)),
      if (tag.mifareInfo != null) ...[
        ('MIFARE type', tag.mifareInfo!.type),
        ('Memory size', formatBytes(tag.mifareInfo!.size)),
        ('Block / page count', '${tag.mifareInfo!.blockCount}'),
        ('Block / page size', '${tag.mifareInfo!.blockSize} bytes'),
        if (tag.mifareInfo!.sectorCount != null)
          ('Sector count', '${tag.mifareInfo!.sectorCount}'),
      ],
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: const Icon(Icons.contactless_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tag details', style: theme.textTheme.titleMedium),
                      Text(
                        scan.formattedUid,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(scan: scan),
                if (onCopy != null)
                  IconButton(
                    tooltip: 'Copy tag details',
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_all_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            for (final (label, value) in rows) _DetailRow(label, value),
            if (scan.ndefReadError != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'NDEF could not be decoded: ${scan.ndefReadError}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static bool _has(String? value) =>
      value != null && value.trim().isNotEmpty;

  static String _yesNo(bool? value) {
    if (value == null) {
      return 'Unknown';
    }
    return value ? 'Yes' : 'No';
  }

  static String _ndefStatus(NFCTag tag) {
    if (tag.ndefAvailable == false) {
      return 'Not NDEF formatted';
    }
    if (tag.ndefWritable == null) {
      return 'Unknown';
    }
    return tag.ndefWritable! ? 'Writable' : 'Read-only';
  }

  static String _tagTypeLabel(NFCTagType type) {
    switch (type) {
      case NFCTagType.iso7816:
        return 'ISO 7816 / Type 4';
      case NFCTagType.iso15693:
        return 'ISO 15693 / Type 5';
      case NFCTagType.iso18092:
        return 'ISO 18092 / FeliCa';
      case NFCTagType.mifare_classic:
        return 'MIFARE Classic';
      case NFCTagType.mifare_ultralight:
        return 'MIFARE Ultralight / NTAG';
      case NFCTagType.mifare_desfire:
        return 'MIFARE DESFire';
      case NFCTagType.mifare_plus:
        return 'MIFARE Plus';
      case NFCTagType.webusb:
        return 'WebUSB reader';
      case NFCTagType.unknown:
        return 'Unknown';
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.scan});

  final NfcTagScan scan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!scan.isNdefAvailable) {
      return Chip(
        label: const Text('No NDEF'),
        visualDensity: VisualDensity.compact,
        avatar: Icon(Icons.block, size: 16, color: scheme.error),
      );
    }
    final writable = scan.isWritable;
    return Chip(
      label: Text(writable ? 'Writable' : 'Read-only'),
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        writable ? Icons.edit_outlined : Icons.lock_outline,
        size: 16,
        color: writable ? scheme.primary : scheme.tertiary,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: label.contains('UID') ||
                        label.contains('ATQA') ||
                        label.contains('SAK')
                    ? 'monospace'
                    : null,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
