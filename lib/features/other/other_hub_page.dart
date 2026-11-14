import 'package:flutter/material.dart';
import 'package:sasatap/features/home/home_page.dart';

class OtherHubPage extends StatelessWidget {
  const OtherHubPage({super.key, required this.onOpen});

  final ValueChanged<AppDestination> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text(
          'More tools',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tag diagnostics and useful free NFC tools.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        _ToolTile(
          icon: Icons.sensors,
          title: 'Tag compatibility',
          description:
              'Read tag technology, memory capacity, NDEF status and UID.',
          onTap: () => onOpen(AppDestination.tools),
        ),
        const SizedBox(height: 12),
        _ToolTile(
          icon: Icons.storage_outlined,
          title: 'Memory and tag tools',
          description:
              'Dump memory, erase or format supported tags, and inspect raw data.',
          onTap: () => onOpen(AppDestination.tools),
        ),
        const SizedBox(height: 12),
        _ToolTile(
          icon: Icons.bolt,
          title: 'Smart tasks',
          description: 'Trigger a sequence of local actions with a tag scan.',
          onTap: () => onOpen(AppDestination.tasks),
        ),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.primary,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 15),
        onTap: onTap,
      ),
    );
  }
}
