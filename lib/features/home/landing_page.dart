import 'package:flutter/material.dart';
import 'package:sasatap/features/home/home_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({
    super.key,
    required this.onGetStarted,
    required this.onOpenDestination,
  });

  final VoidCallback onGetStarted;
  final ValueChanged<AppDestination> onOpenDestination;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _scrollController = ScrollController();
  final _topKey = GlobalKey();
  final _toolsKey = GlobalKey();
  final _aboutKey = GlobalKey();
  final _helpKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 760;
    final showNavigationLinks = screenWidth >= 1020;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                isWide ? 36 : 18,
                12,
                isWide ? 36 : 18,
                32,
              ),
              children: [
                KeyedSubtree(
                  key: _topKey,
                  child: _LandingHeader(
                    showNavigationLinks: showNavigationLinks,
                    onHome: () => _scrollTo(_topKey),
                    onTools: () => _scrollTo(_toolsKey),
                    onAbout: () => _scrollTo(_aboutKey),
                    onHelp: () => _scrollTo(_helpKey),
                    onGetStarted: widget.onGetStarted,
                  ),
                ),
                SizedBox(height: isWide ? 22 : 14),
                _LandingHero(
                  isWide: isWide,
                  onGetStarted: widget.onGetStarted,
                  onLearnMore: () => _scrollTo(_aboutKey),
                ),
                const SizedBox(height: 16),
                const _FeatureBar(),
                SizedBox(height: isWide ? 50 : 34),
                KeyedSubtree(
                  key: _toolsKey,
                  child: _ToolsSection(
                    isWide: isWide,
                    onOpenDestination: widget.onOpenDestination,
                  ),
                ),
                SizedBox(height: isWide ? 40 : 28),
                KeyedSubtree(
                  key: _aboutKey,
                  child: _AboutSection(isWide: isWide),
                ),
                SizedBox(height: isWide ? 40 : 28),
                KeyedSubtree(
                  key: _helpKey,
                  child: _HelpSection(isWide: isWide),
                ),
                const SizedBox(height: 28),
                _FinalCallToAction(onGetStarted: widget.onGetStarted),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'SasaTap  ·  NFC tools made simple',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingHeader extends StatelessWidget {
  const _LandingHeader({
    required this.showNavigationLinks,
    required this.onHome,
    required this.onTools,
    required this.onAbout,
    required this.onHelp,
    required this.onGetStarted,
  });

  final bool showNavigationLinks;
  final VoidCallback onHome;
  final VoidCallback onTools;
  final VoidCallback onAbout;
  final VoidCallback onHelp;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.contactless, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SasaTap',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'NFC Tools',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (showNavigationLinks) ...[
          _HeaderLink(label: 'Home', icon: Icons.home_outlined, onTap: onHome),
          _HeaderLink(
            label: 'Tools',
            icon: Icons.grid_view_rounded,
            onTap: onTools,
          ),
          _HeaderLink(label: 'About', icon: Icons.info_outline, onTap: onAbout),
          _HeaderLink(label: 'Help', icon: Icons.help_outline, onTap: onHelp),
          const SizedBox(width: 10),
        ],
        FilledButton.icon(
          onPressed: onGetStarted,
          icon: const Icon(Icons.arrow_forward, size: 17),
          label: Text(showNavigationLinks ? 'Get started' : 'Dashboard'),
        ),
      ],
    );
  }
}

class _HeaderLink extends StatelessWidget {
  const _HeaderLink({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: scheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
    );
  }
}

class _LandingHero extends StatelessWidget {
  const _LandingHero({
    required this.isWide,
    required this.onGetStarted,
    required this.onLearnMore,
  });

  final bool isWide;
  final VoidCallback onGetStarted;
  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mobileGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [Color(0xFF0C1A35), Color(0xFF102C62), Color(0xFF0753B9)]
          : const [Color(0xFFFFFFFF), Color(0xFFEAF4FF), Color(0xFFC9E8FF)],
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C1A35) : const Color(0xFFEAF4FF),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFD8E8FB),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: isWide
          ? SizedBox(
              height: 480,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/landing_nfc_hero.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        stops: const [0, 0.3, 0.52, 0.72, 1],
                        colors: isDark
                            ? [
                                const Color(0xF50C1A35),
                                const Color(0xE60C1A35),
                                const Color(0xB80C1A35),
                                const Color(0x300C1A35),
                                const Color(0x080C1A35),
                              ]
                            : [
                                const Color(0xFFF8FBFF),
                                const Color(0xF2F8FBFF),
                                const Color(0xB8F8FBFF),
                                const Color(0x20F8FBFF),
                                const Color(0x00F8FBFF),
                              ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(42),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: _HeroCopy(
                          isWide: true,
                          isDark: isDark,
                          onGetStarted: onGetStarted,
                          onLearnMore: onLearnMore,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(gradient: mobileGradient),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: _HeroCopy(
                      isWide: false,
                      isDark: isDark,
                      onGetStarted: onGetStarted,
                      onLearnMore: onLearnMore,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: AspectRatio(
                      aspectRatio: 1.6,
                      child: Image.asset(
                        'assets/images/landing_nfc_hero.jpg',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.isWide,
    required this.isDark,
    required this.onGetStarted,
    required this.onLearnMore,
  });

  final bool isWide;
  final bool isDark;
  final VoidCallback onGetStarted;
  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = isDark ? Colors.white : const Color(0xFF09245D);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF294779);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : theme.colorScheme.primary)
                .withValues(alpha: isDark ? 0.12 : 0.09),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bolt,
                color: isDark
                    ? const Color(0xFF78E7FF)
                    : theme.colorScheme.primary,
                size: 17,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'FAST  ·  SECURE  ·  NFC READY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark ? Colors.white : const Color(0xFF173B78),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.55,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text.rich(
          TextSpan(
            style: theme.textTheme.displaySmall?.copyWith(
              color: titleColor,
              fontSize: isWide ? 58 : 42,
              height: 0.98,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.7,
            ),
            children: [
              const TextSpan(text: 'Tap. Share.\n'),
              TextSpan(
                text: 'Connect.',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF72E4FF)
                      : const Color(0xFF0875F9),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            'The all-in-one NFC toolkit for reading, writing and managing tags with ease.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: subtitleColor,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onGetStarted,
              icon: const Icon(Icons.play_arrow_rounded, size: 19),
              label: const Text('Get started'),
            ),
            OutlinedButton.icon(
              onPressed: onLearnMore,
              icon: const Icon(Icons.menu_book_outlined, size: 17),
              label: const Text('Learn more'),
              style: OutlinedButton.styleFrom(
                foregroundColor: titleColor,
                side: BorderSide(color: titleColor.withValues(alpha: 0.45)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureBar extends StatelessWidget {
  const _FeatureBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    const features = [
      _Feature(
        icon: Icons.bolt,
        title: 'Quick actions',
        subtitle: 'Get things done fast',
      ),
      _Feature(
        icon: Icons.verified_user_outlined,
        title: 'Secure & private',
        subtitle: 'Your data stays yours',
      ),
      _Feature(
        icon: Icons.grid_view_rounded,
        title: 'Powerful tools',
        subtitle: 'Read, write and automate',
      ),
      _Feature(
        icon: Icons.devices_rounded,
        title: 'Modern experience',
        subtitle: 'Designed for your device',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: isWide ? 4 : 2,
        mainAxisExtent: 68,
        crossAxisSpacing: 8,
        mainAxisSpacing: 4,
        children: [
          for (final feature in features) _FeatureItem(feature: feature),
        ],
      ),
    );
  }
}

class _Feature {
  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(feature.icon, color: theme.colorScheme.primary, size: 25),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                feature.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                feature.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolsSection extends StatelessWidget {
  const _ToolsSection({required this.isWide, required this.onOpenDestination});

  final bool isWide;
  final ValueChanged<AppDestination> onOpenDestination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.onSurface
        : const Color(0xFF102C62);

    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your all-in-one\nNFC solution',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Whether you want to read a tag, write data or automate an action, '
          'SasaTap has you covered.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
    final tools = GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 164,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      children: [
        _ToolCard(
          icon: Icons.visibility_outlined,
          title: 'Read tag',
          description: 'View data from any NFC tag.',
          color: const Color(0xFF0877F9),
          onTap: () => onOpenDestination(AppDestination.read),
        ),
        _ToolCard(
          icon: Icons.edit_note,
          title: 'Write tag',
          description: 'Add your own content.',
          color: const Color(0xFF05B879),
          onTap: () => onOpenDestination(AppDestination.write),
        ),
        _ToolCard(
          icon: Icons.bolt,
          title: 'Automations',
          description: 'Run actions when a tag is scanned.',
          color: const Color(0xFF7040E8),
          onTap: () => onOpenDestination(AppDestination.tasks),
        ),
        _ToolCard(
          icon: Icons.tune,
          title: 'Tag tools',
          description: 'Inspect memory and manage tags.',
          color: const Color(0xFFFF941F),
          onTap: () => onOpenDestination(AppDestination.tools),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 270, child: intro),
              const SizedBox(width: 18),
              Expanded(child: tools),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [intro, const SizedBox(height: 18), tools],
          ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: color,
                foregroundColor: Colors.white,
                child: Icon(icon, size: 23),
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
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.all(isWide ? 26 : 20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: isWide
          ? Row(
              children: [
                Expanded(child: _aboutCopy(theme, scheme)),
                const SizedBox(width: 28),
                const _AboutHighlights(),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _aboutCopy(theme, scheme),
                const SizedBox(height: 18),
                const _AboutHighlights(),
              ],
            ),
    );
  }

  Widget _aboutCopy(ThemeData theme, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Made for everyday NFC',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'SasaTap brings tag reading, writing and automation together in one '
          'simple toolkit. Your NFC actions happen on your device, with clear '
          'feedback at every step.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onPrimaryContainer.withValues(alpha: 0.82),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _AboutHighlights extends StatelessWidget {
  const _AboutHighlights();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const highlights = [
      (Icons.bolt, 'Fast actions'),
      (Icons.shield_outlined, 'Local-first'),
      (Icons.nfc, 'NFC focused'),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (icon, label) in highlights)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: theme.colorScheme.primary),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Need a hand?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Quick answers to get you started.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        if (isWide)
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _HelpCard(isLeft: true)),
              SizedBox(width: 14),
              Expanded(child: _HelpCard(isLeft: false)),
            ],
          )
        else
          const Column(
            children: [
              _HelpCard(isLeft: true),
              SizedBox(height: 10),
              _HelpCard(isLeft: false),
            ],
          ),
      ],
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.isLeft});

  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    final questions = isLeft
        ? const [
            (
              'How do I read a tag?',
              'Open NFC Tools and choose Read tag, then hold the tag near the '
                  'phone until the scan completes. SasaTap shows the UID, tag '
                  'type, capacity and decoded NDEF records. Reading is passive '
                  'and does not change the tag.',
            ),
            (
              'How do I write a tag?',
              'Choose Write tag, select a record type, fill in the fields and '
                  'add the record to your message. You can combine several '
                  'records before writing. SasaTap checks available capacity, '
                  'writes the message and reads it back to verify the result. '
                  'Writing replaces the tag\'s existing NDEF message.',
            ),
            (
              'Which record type should I choose?',
              'Use URL / URI for links and app schemes, Text for plain messages '
                  'with a language code, vCard for contact details, Wi-Fi for '
                  'network credentials, and Custom MIME for app-specific '
                  'payloads. Pick the type that matches how the tag will be '
                  'used.',
            ),
            (
              'What does each write field mean?',
              'URL / URI stores a link or action such as https:, tel: or '
                  'mailto:. Text is your message; Language code identifies '
                  'its language, such as en or sw. vCard fields describe a '
                  'contact: name, organization, job title, phone, email and '
                  'website. Address and notes adds optional street, city, '
                  'postal code, region, country and extra notes. For Wi-Fi, '
                  'SSID is the exact network name, Security must match the '
                  'router, and Password is its network password. Custom MIME '
                  'uses MIME type to label the format and Payload for raw '
                  'bytes written in hexadecimal. Fill only the fields you '
                  'need.',
            ),
            (
              'How do I save a tag?',
              'After reading a tag, tap the bookmark icon on the result card. '
                  'Saved tags live only on this device under the Saved tab, '
                  'where you can search, review or remove them. Saving keeps a '
                  'local reference; it does not copy or lock the physical tag.',
            ),
          ]
        : const [
            (
              'How do I lock a tag after writing it?',
              'Write and save the tag first. Then choose Lock with password on '
                  'the write result or in the Saved tab. SasaTap asks you to '
                  'hold the same tag again, then writes an NTAG password, PACK '
                  'and protection settings. The tag stays readable, but '
                  'rewriting it requires the password. This works on NTAG213, '
                  'NTAG215 and NTAG216 tags.',
            ),
            (
              'Can I unlock or change the password?',
              'Password protection can be removed from Other → Tag tools by '
                  'scanning the tag and entering the current password. A '
                  'permanent read-only lock is different: it cannot be undone. '
                  'Store the password and PACK safely; losing them can leave '
                  'the tag permanently unwritable.',
            ),
            (
              'What can automations do?',
              'Automations connect a tag to actions. Create a task, add the '
                  'actions you want, then choose the tag trigger. When that tag '
                  'is scanned in SasaTap, the enabled actions run. Links are '
                  'copied instead of opened automatically so you stay in '
                  'control.',
            ),
            (
              'Why is my tag not detected?',
              'Check that NFC is on, remove thick cases and hold the tag '
                  'against the NFC antenna, which is often near the top of the '
                  'phone. Keep the tag still, confirm that the tag type is '
                  'supported, and try another position if the first scan does '
                  'not start.',
            ),
          ];

    return Card(
      child: Column(
        children: [
          for (final (question, answer) in questions)
            ExpansionTile(
              leading: Icon(
                Icons.help_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              title: Text(
                question,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(answer)],
            ),
        ],
      ),
    );
  }
}

class _FinalCallToAction extends StatelessWidget {
  const _FinalCallToAction({required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNarrow = MediaQuery.sizeOf(context).width < 460;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A4EDD), Color(0xFF087CEB)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CallToActionCopy(),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: onGetStarted,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: theme.colorScheme.primary,
                  ),
                  child: const Text('Open dashboard'),
                ),
              ],
            )
          : Row(
              children: [
                const Expanded(child: _CallToActionCopy()),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: onGetStarted,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: theme.colorScheme.primary,
                  ),
                  child: const Text('Open dashboard'),
                ),
              ],
            ),
    );
  }
}

class _CallToActionCopy extends StatelessWidget {
  const _CallToActionCopy();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ready to tap?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Open your NFC dashboard and choose a tool.',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}
