import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/app.dart';
import 'package:noteon/core/providers/settings_providers.dart';
import 'package:noteon/features/folders/data/folder.dart';
import 'package:noteon/features/notes/data/note.dart';
import 'package:noteon/features/notes/presentation/notes_providers.dart';
import 'package:noteon/features/tags/data/tag.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpApp(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localeProvider.overrideWith(_EnglishLocale.new),
          notesListProvider.overrideWith(_EmptyNotesList.new),
          foldersListProvider.overrideWith(_EmptyFoldersList.new),
          tagsListProvider.overrideWith(_EmptyTagsList.new),
        ],
        child: const NoteonApp(),
      ),
    );
    await tester.pump();
  }

  testWidgets('Noteon shell shows empty notes and settings', (tester) async {
    await pumpApp(tester);

    expect(find.text('Noteon'), findsWidgets);
    expect(find.text('No notes yet'), findsOneWidget);
    expect(find.text('New note'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.textContaining('Version'), findsOneWidget);
  });

  testWidgets('theme preference survives notifier recreation', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            final mode = ref.watch(themeModeProvider);
            return MaterialApp(
              home: Text(mode.name),
            );
          },
        ),
      ),
    );
    await tester.pump();

    await container.read(themeModeProvider.notifier).setMode(AppThemeMode.light);
    await tester.pump();
    expect(find.text('light'), findsOneWidget);

    // Recreate from prefs as a cold start would.
    final store = container.read(appSettingsStoreProvider);
    expect(store.readThemeMode(), AppThemeMode.light);
  });
}

class _EnglishLocale extends LocaleNotifier {
  @override
  Locale? build() => const Locale('en');
}

class _EmptyNotesList extends NotesListNotifier {
  @override
  Future<List<Note>> build() async => [];
}

class _EmptyFoldersList extends FoldersListNotifier {
  @override
  Future<List<Folder>> build() async => [];
}

class _EmptyTagsList extends TagsListNotifier {
  @override
  Future<List<Tag>> build() async => [];
}
