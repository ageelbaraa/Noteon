import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noteon/app.dart';
import 'package:noteon/core/providers/settings_providers.dart';
import 'package:noteon/features/folders/data/folder.dart';
import 'package:noteon/features/notes/data/note.dart';
import 'package:noteon/features/notes/presentation/notes_providers.dart';
import 'package:noteon/features/tags/data/tag.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight full-shell smoke test (no Isar) for packaging / FTL.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('FTL: Noteon shell opens empty notes list', (tester) async {
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
    await tester.pumpAndSettle();

    expect(find.text('Noteon'), findsWidgets);
    expect(find.text('No notes yet'), findsOneWidget);
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
