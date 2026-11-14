import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sasatap/core/ndef_inspector.dart';

/// Expandable view of a single decoded NDEF record.
class NdefRecordTile extends StatelessWidget {
  const NdefRecordTile({super.key, required this.record});

  final NdefRecordView record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: scheme.secondaryContainer,
          foregroundColor: scheme.onSecondaryContainer,
          child: Icon(_iconFor(record.kind), size: 20),
        ),
        title: Text(
          record.summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Record ${record.index + 1} • ${record.kind} • ${record.type}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          for (final entry in record.details.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 108,
                    child: Text(
                      entry.key,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      entry.value,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Raw record', style: theme.textTheme.labelLarge),
              const Spacer(),
              IconButton(
                tooltip: 'Copy raw hex',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: record.rawHex));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Raw record copied.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                record.rawHex.isEmpty ? '(empty)' : record.rawHex,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String kind) {
    switch (kind) {
      case 'URI':
        return Icons.link;
      case 'Text':
        return Icons.text_fields;
      case 'vCard':
        return Icons.person_outline;
      case 'Wi-Fi':
        return Icons.wifi;
      case 'MIME':
        return Icons.insert_drive_file_outlined;
      case 'Empty':
        return Icons.remove_circle_outline;
      default:
        return Icons.memory;
    }
  }
}
