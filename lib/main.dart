import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sasatap/core/nfc_service.dart';
import 'package:sasatap/features/home/home_page.dart';
import 'package:sasatap/features/other/other_hub_page.dart';
import 'package:sasatap/features/other/other_page.dart';
import 'package:sasatap/features/other/other_provider.dart';
import 'package:sasatap/features/read/read_page.dart';
import 'package:sasatap/features/read/read_provider.dart';
import 'package:sasatap/features/saved/saved_page.dart';
import 'package:sasatap/features/saved/saved_tag_repository.dart';
import 'package:sasatap/features/settings/settings_page.dart';
import 'package:sasatap/features/tasks/task_executor.dart';
import 'package:sasatap/features/tasks/task_repository.dart';
import 'package:sasatap/features/tasks/tasks_page.dart';
import 'package:sasatap/features/tasks/tasks_provider.dart';
import 'package:sasatap/features/write/write_page.dart';
import 'package:sasatap/features/write/write_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted automation rules before the first frame so the Tasks tab
  // never flashes an empty list.
  final preferences = await SharedPreferences.getInstance();
  final repository = TaskRepository(preferences);
  await repository.load();
  final savedTags = SavedTagRepository(preferences);
  await savedTags.load();
  final settings = AppSettings(preferences);
  await settings.load();

  runApp(
    SasaTapApp(
      repository: repository,
      savedTags: savedTags,
      settings: settings,
    ),
  );
}

class SasaTapApp extends StatelessWidget {
  const SasaTapApp({
    super.key,
    required this.repository,
    required this.savedTags,
    required this.settings,
  });

  final TaskRepository repository;
  final SavedTagRepository savedTags;
  final AppSettings settings;

  static const Color _seedColor = Color(0xFF16C7D9);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskRepository>.value(value: repository),
        ChangeNotifierProvider<SavedTagRepository>.value(value: savedTags),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
        Provider<NfcService>(
          create: (_) => NfcService(),
          dispose: (_, service) => unawaited(service.shutdown()),
        ),
        Provider<TaskExecutor>(
          create: (context) => TaskExecutor(context.read<TaskRepository>()),
        ),
        ChangeNotifierProvider<ReadProvider>(
          create: (context) => ReadProvider(
            context.read<NfcService>(),
            context.read<TaskExecutor>(),
          ),
        ),
        ChangeNotifierProvider<WriteProvider>(
          create: (context) => WriteProvider(context.read<NfcService>()),
        ),
        ChangeNotifierProvider<OtherProvider>(
          create: (context) => OtherProvider(context.read<NfcService>()),
        ),
        ChangeNotifierProvider<TasksProvider>(
          create: (context) => TasksProvider(
            context.read<NfcService>(),
            context.read<TaskRepository>(),
            context.read<TaskExecutor>(),
          )..syncFromRepository(),
        ),
      ],
      child: Consumer<AppSettings>(
        builder: (context, appSettings, _) => MaterialApp(
          title: 'SasaTap',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: appSettings.themeMode,
          home: const HomeShell(),
        ),
      ),
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? const Color(0xFF59D8E8) : const Color(0xFF006B80),
          onPrimary: isDark ? const Color(0xFF04202A) : Colors.white,
          primaryContainer: isDark
              ? const Color(0xFF103A50)
              : const Color(0xFFD1F4F8),
          onPrimaryContainer: isDark
              ? const Color(0xFFB8F4FC)
              : const Color(0xFF002F3B),
          secondary: isDark ? const Color(0xFF4AA8F4) : const Color(0xFF315FA8),
          surface: isDark ? const Color(0xFF081322) : const Color(0xFFF4F7FA),
          surfaceContainerLowest: isDark
              ? const Color(0xFF060D18)
              : const Color(0xFFFFFFFF),
          surfaceContainerLow: isDark
              ? const Color(0xFF0B192A)
              : const Color(0xFFF7F9FC),
          surfaceContainer: isDark
              ? const Color(0xFF102238)
              : const Color(0xFFEDF2F7),
          surfaceContainerHigh: isDark
              ? const Color(0xFF152A42)
              : const Color(0xFFE7EDF4),
          surfaceContainerHighest: isDark
              ? const Color(0xFF1B334D)
              : const Color(0xFFDDE5EE),
          outline: isDark ? const Color(0xFF34516A) : const Color(0xFF728394),
          outlineVariant: isDark
              ? const Color(0xFF203A52)
              : const Color(0xFFCAD4DE),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF07111F)
          : const Color(0xFFF4F7FA),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF0D1D30) : Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark
            ? const Color(0xFF07111F)
            : const Color(0xFFF4F7FA),
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF0A1727)
            : const Color(0xFFFFFFFF),
        indicatorColor: isDark
            ? const Color(0xFF07516A)
            : const Color(0xFFD1F4F8),
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF0A192B) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  AppDestination? _destination;

  static const _tabTitles = ['NFC Tools', 'Other', 'Saved', 'Settings'];

  static const _destinationTitles = {
    AppDestination.read: 'Read NFC tag',
    AppDestination.write: 'Write NFC tag',
    AppDestination.tools: 'Tag tools',
    AppDestination.tasks: 'Tasks & Automation',
  };

  void _openDestination(AppDestination destination) {
    setState(() => _destination = destination);
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return HomePage(onOpen: _openDestination);
      case 1:
        return OtherHubPage(onOpen: _openDestination);
      case 2:
        return const SavedPage();
      case 3:
        return const SettingsPage();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDestination(AppDestination destination) {
    switch (destination) {
      case AppDestination.read:
        return const ReadPage();
      case AppDestination.write:
        return const WritePage();
      case AppDestination.tools:
        return const TagToolsPage();
      case AppDestination.tasks:
        return const TasksPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destination = _destination;
    return Scaffold(
      appBar: AppBar(
        leading: destination == null
            ? null
            : IconButton(
                tooltip: 'Back',
                onPressed: () => setState(() => _destination = null),
                icon: const Icon(Icons.arrow_back),
              ),
        title: destination == null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.contactless,
                      size: 21,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SasaTap',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _tabTitles[_index],
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Text(_destinationTitles[destination]!),
      ),
      body: SafeArea(
        top: false,
        child: destination == null
            ? IndexedStack(
                index: _index,
                children: List<Widget>.generate(4, _buildTab),
              )
            : _buildDestination(destination),
      ),
      bottomNavigationBar: destination == null
          ? NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (index) {
                setState(() {
                  _index = index;
                  _destination = null;
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.contactless_outlined),
                  selectedIcon: Icon(Icons.contactless),
                  label: 'NFC Tools',
                ),
                NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view),
                  label: 'Other',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bookmark_border),
                  selectedIcon: Icon(Icons.bookmark),
                  label: 'Saved',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            )
          : null,
    );
  }
}
