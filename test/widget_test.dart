import 'package:flutter_test/flutter_test.dart';
import 'package:sasatap/features/saved/saved_tag_repository.dart';
import 'package:sasatap/features/settings/settings_page.dart';
import 'package:sasatap/features/tasks/task_repository.dart';
import 'package:sasatap/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('main navigation opens the four app sections', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final tasks = TaskRepository(preferences);
    final savedTags = SavedTagRepository(preferences);
    final settings = AppSettings(preferences);
    await tasks.load();
    await savedTags.load();
    await settings.load();

    await tester.pumpWidget(
      SasaTapApp(repository: tasks, savedTags: savedTags, settings: settings),
    );
    await tester.pumpAndSettle();

    expect(find.text('Read and write NFC tags faster'), findsOneWidget);

    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();
    expect(find.text('More tools'), findsOneWidget);

    await tester.tap(find.text('Saved').last);
    await tester.pumpAndSettle();
    expect(find.text('Your library is empty'), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Personalization'), findsOneWidget);
  });
}
