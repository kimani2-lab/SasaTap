import 'package:flutter/material.dart';

enum AppDestination { read, write, tools, tasks }

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onOpen});

  final ValueChanged<AppDestination> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF123752), Color(0xFF0D1D30)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Eyebrow(label: 'SASATAP  /  NFC TOOLKIT'),
              const SizedBox(height: 18),
              Text(
                'Read and write NFC tags faster',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scan a tag, create records, or set up a local automation.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.contactless, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Your NFC tools are ready',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text('Free NFC actions', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 560 ? 3 : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: columns == 2 ? 0.8 : 1.05,
              children: [
                _ActionCard(
                  icon: Icons.contactless,
                  title: 'Read now',
                  description: 'Read tag details and inspect NDEF records.',
                  buttonLabel: 'Read',
                  onPressed: () => onOpen(AppDestination.read),
                ),
                _ActionCard(
                  icon: Icons.edit_note,
                  title: 'Write now',
                  description: 'Create one or more records and write a tag.',
                  buttonLabel: 'Write',
                  onPressed: () => onOpen(AppDestination.write),
                ),
                _ActionCard(
                  icon: Icons.bolt,
                  title: 'Automate',
                  description:
                      'Build ordered local actions triggered by a tag.',
                  buttonLabel: 'Automations',
                  onPressed: () => onOpen(AppDestination.tasks),
                ),
                _ActionCard(
                  icon: Icons.construction,
                  title: 'Tag tools',
                  description: 'Inspect memory and manage writable tags.',
                  buttonLabel: 'Open tools',
                  onPressed: () => onOpen(AppDestination.tools),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tips & notes', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Keep the phone near the tag antenna, enable NFC in device '
                  'settings, and keep SasaTap open while reading or writing.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.primary,
              child: Icon(icon),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPressed,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
