import 'package:flutter/material.dart';

enum AppDestination { read, write, tools, tasks }

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onOpen});

  final ValueChanged<AppDestination> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 640;
        final horizontalPadding = isWide ? 28.0 : 20.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            28,
          ),
          children: [
            _DashboardBanner(isWide: isWide),
            const SizedBox(height: 26),
            Text(
              'NFC Tools',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Choose an action to work with an NFC tag.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: isWide ? 300 : 220,
                mainAxisExtent: 174,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              children: [
                _ActionCard(
                  icon: Icons.contactless,
                  iconColor: const Color(0xFF1674F9),
                  title: 'Read tag',
                  description: 'Scan and inspect tag details.',
                  onPressed: () => onOpen(AppDestination.read),
                ),
                _ActionCard(
                  icon: Icons.edit_note,
                  iconColor: const Color(0xFF08B98E),
                  title: 'Write tag',
                  description: 'Create records and write a tag.',
                  onPressed: () => onOpen(AppDestination.write),
                ),
                _ActionCard(
                  icon: Icons.bolt,
                  iconColor: const Color(0xFF7449EE),
                  title: 'Automations',
                  description: 'Run actions when you scan a tag.',
                  onPressed: () => onOpen(AppDestination.tasks),
                ),
                _ActionCard(
                  icon: Icons.tune,
                  iconColor: const Color(0xFFFF922E),
                  title: 'Tag tools',
                  description: 'Inspect memory and manage tags.',
                  onPressed: () => onOpen(AppDestination.tools),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surfaceContainer
                    : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your tags stay yours',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Read and write NFC data directly on your device.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DashboardBanner extends StatelessWidget {
  const _DashboardBanner({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? const Color(0xFFEAF2FF)
        : const Color(0xFF102C62);
    final subtitleColor = isDark
        ? const Color(0xFFD5E4FF)
        : const Color(0xFF294779);

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 28 : 20,
        vertical: isWide ? 24 : 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: isDark
              ? const [Color(0xFF142D57), Color(0xFF174E9B), Color(0xFF075CF5)]
              : const [Color(0xFFDDE7FF), Color(0xFFB8CEFF), Color(0xFF0868F5)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned(
            right: isWide ? 22 : -34,
            top: -92,
            child: Container(
              width: 210,
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.12),
                borderRadius: BorderRadius.circular(120),
              ),
            ),
          ),
          Positioned(
            right: -44,
            bottom: -132,
            child: Container(
              width: 250,
              height: 190,
              decoration: BoxDecoration(
                color: const Color(0xFF0055E8).withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(120),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello there 👋',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Welcome back! Explore the tools below to get started.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.nfc,
                color: Colors.white.withValues(alpha: 0.95),
                size: isWide ? 48 : 36,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
