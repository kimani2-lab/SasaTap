import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sasatap/features/home/landing_page.dart';
import 'package:sasatap/features/saved/saved_tag_repository.dart';
import 'package:sasatap/features/settings/settings_page.dart';
import 'package:sasatap/features/tasks/task_repository.dart';
import 'package:sasatap/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('landing, NFC tools and dashboard sections navigate correctly', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final tasks = TaskRepository(preferences);
    final savedTags = SavedTagRepository(preferences);
    final settings = AppSettings(preferences);
    await tasks.load();
    await savedTags.load();
    await settings.load();
    expect(settings.themeMode, ThemeMode.light);

    await tester.pumpWidget(
      SasaTapApp(repository: tasks, savedTags: savedTags, settings: settings),
    );
    await tester.pumpAndSettle();

    expect(find.text('Get started'), findsWidgets);
    await tester.tap(find.text('Get started').last);
    await tester.pumpAndSettle();
    expect(find.text('Hello there 👋'), findsOneWidget);
    expect(
      find.text('Welcome back! Explore the tools below to get started.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('app-page-background')), findsNothing);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.white,
    );
    expect(find.byTooltip('Landing page'), findsOneWidget);
    await tester.tap(find.byTooltip('Landing page'));
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsWidgets);
    await tester.tap(find.text('Get started').last);
    await tester.pumpAndSettle();

    await openNfcAction(tester, 'Read tag', 'Read NFC tag');
    await openNfcAction(tester, 'Write tag', 'Write NFC tag');
    await openNfcAction(tester, 'Automations', 'Tasks & Automation');
    await openNfcAction(tester, 'Tag tools', 'Tag tools');

    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();
    expect(find.text('More tools'), findsOneWidget);
    expect(find.byTooltip('Landing page'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-page-background')), findsNothing);

    await tester.tap(find.text('Saved').last);
    await tester.pumpAndSettle();
    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-page-background')), findsNothing);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Personalization'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-page-background')), findsNothing);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();
    expect(find.text('More tools'), findsOneWidget);
  });

  testWidgets('landing help explains the write form fields', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: LandingPage(onGetStarted: () {}, onOpenDestination: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    final question = find.text('What does each write field mean?');
    await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.ensureVisible(question);
    await tester.pumpAndSettle();
    await tester.tap(question);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('SSID is the exact network name'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Payload for raw bytes written in hexadecimal'),
      findsOneWidget,
    );
  });
}

Future<void> openNfcAction(
  WidgetTester tester,
  String action,
  String expectedTitle,
) async {
  final actionFinder = find.text(action);
  await tester.scrollUntilVisible(
    actionFinder,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(actionFinder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.text(expectedTitle), findsOneWidget);
  expect(find.byKey(const ValueKey('app-page-background')), findsNothing);
  await tester.tap(find.byTooltip('Back'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
