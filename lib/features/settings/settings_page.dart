import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppSettings extends ChangeNotifier {
  AppSettings(this._preferences);

  static const _themeKey = 'sasatap.theme_mode';
  final SharedPreferences _preferences;
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final stored = _preferences.getString(_themeKey);
    _themeMode = switch (stored) {
      'system' => ThemeMode.system,
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final stored = switch (mode) {
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
    };
    final saved = await _preferences.setString(_themeKey, stored);
    if (!saved) {
      throw StateError('The appearance setting could not be saved.');
    }
    _themeMode = mode;
    notifyListeners();
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.accountEmail, this.onSignOut});

  final String? accountEmail;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Consumer<AppSettings>(
      builder: (context, settings, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Text(
            'Settings',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Personalize SasaTap and review how your data is handled.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (accountEmail != null && onSignOut != null) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('Signed in'),
                subtitle: Text(accountEmail!),
                trailing: IconButton(
                  tooltip: 'Sign out',
                  onPressed: () async {
                    try {
                      await onSignOut!();
                    } on AuthException catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Could not sign out: ${error.message}',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.logout),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Personalization', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Choose the app appearance.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.settings_suggest_outlined),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (selection) async {
                      try {
                        await settings.setThemeMode(selection.single);
                      } on Object catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not save setting: $error'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scan & privacy', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Scans, saved tag snapshots, and automation rules are '
                    'cached on this device. Saved tags sync to your signed-in '
                    'account, remain private by default, and can be shared '
                    'with an organization you belong to. Offline cache is '
                    'partitioned by account.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.nfc),
                    title: Text('NFC scans require the app to be open'),
                    subtitle: Text('Background tag scanning is not enabled.'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About SasaTap'),
              subtitle: const Text('NFC Toolkit · Version 1.0.0'),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'SasaTap',
                applicationVersion: '1.0.0',
                applicationLegalese: 'NFC tools with private account storage.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
