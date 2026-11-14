import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sasatap/features/saved/saved_tag_repository.dart';

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SavedTagRepository>(
      builder: (context, repository, _) {
        final query = _search.text.trim().toLowerCase();
        final tags = repository.tags
            .where(
              (tag) =>
                  tag.uid.toLowerCase().contains(query) ||
                  tag.records.any(
                    (record) =>
                        record.summary.toLowerCase().contains(query) ||
                        record.type.toLowerCase().contains(query),
                  ),
            )
            .toList(growable: false);
        final scheme = Theme.of(context).colorScheme;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Text(
              'Saved tags',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep a local reference to tags you have scanned.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search UID or record content',
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            if (repository.warning != null) ...[
              const SizedBox(height: 12),
              _MessageCard(message: repository.warning!, isError: true),
            ],
            const SizedBox(height: 16),
            if (tags.isEmpty)
              _EmptySavedState(hasSavedTags: repository.tags.isNotEmpty)
            else
              for (final tag in tags)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.primary,
                        child: const Icon(Icons.nfc),
                      ),
                      title: Text(
                        tag.uid,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${tag.records.length} NDEF record(s) · '
                        '${tag.tagType}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'view') {
                            _showDetails(context, tag);
                          } else if (action == 'delete') {
                            _delete(context, repository, tag);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'view',
                            child: Text('View details'),
                          ),
                          PopupMenuItem(value: 'delete', child: Text('Remove')),
                        ],
                      ),
                      onTap: () => _showDetails(context, tag),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  Future<void> _delete(
    BuildContext context,
    SavedTagRepository repository,
    SavedTag tag,
  ) async {
    try {
      await repository.delete(tag.uid);
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove saved tag: $error')),
        );
      }
    }
  }

  void _showDetails(BuildContext context, SavedTag tag) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(tag.uid, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Standard: ${tag.standard}'),
            Text('Type: ${tag.tagType}'),
            if (tag.manufacturer.isNotEmpty)
              Text('Manufacturer: ${tag.manufacturer}'),
            if (tag.capacity != null) Text('Capacity: ${tag.capacity} bytes'),
            Text('Saved: ${tag.savedAt.toLocal()}'),
            const SizedBox(height: 18),
            Text(
              'NDEF records',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (tag.records.isEmpty)
              const Text('No NDEF records were present when saved.'),
            for (var index = 0; index < tag.records.length; index++)
              Card(
                child: ListTile(
                  title: Text('${index + 1}. ${tag.records[index].type}'),
                  subtitle: Text(
                    tag.records[index].summary,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptySavedState extends StatelessWidget {
  const _EmptySavedState({required this.hasSavedTags});

  final bool hasSavedTags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              hasSavedTags ? Icons.search_off : Icons.bookmark_border,
              size: 36,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              hasSavedTags ? 'No matching tags' : 'Your library is empty',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              hasSavedTags
                  ? 'Try another UID or record search.'
                  : 'Read a tag and choose Save tag to keep its details here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = isError
        ? scheme.onErrorContainer
        : scheme.onPrimaryContainer;
    return Card(
      color: isError ? scheme.errorContainer : scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(message, style: TextStyle(color: foreground)),
      ),
    );
  }
}
