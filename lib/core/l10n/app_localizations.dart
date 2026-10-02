import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Noteon'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Simple and secure notes, stored on your device'**
  String get appTagline;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @allNotes.
  ///
  /// In en, this message translates to:
  /// **'All notes'**
  String get allNotes;

  /// No description provided for @folders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get folders;

  /// No description provided for @subfolders.
  ///
  /// In en, this message translates to:
  /// **'Subfolders'**
  String get subfolders;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @searchNotes.
  ///
  /// In en, this message translates to:
  /// **'Search notes'**
  String get searchNotes;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Noteon is a simple and secure notes app that keeps your data locally on your device.'**
  String get aboutDescription;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @emptyNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get emptyNotesTitle;

  /// No description provided for @emptyNotesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your first note to get started.'**
  String get emptyNotesSubtitle;

  /// No description provided for @newNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get newNote;

  /// No description provided for @untitledNote.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitledNote;

  /// No description provided for @emptyNotePreview.
  ///
  /// In en, this message translates to:
  /// **'No additional text'**
  String get emptyNotePreview;

  /// No description provided for @lockedNotePreview.
  ///
  /// In en, this message translates to:
  /// **'Locked note'**
  String get lockedNotePreview;

  /// No description provided for @lockedNoteEditorMessage.
  ///
  /// In en, this message translates to:
  /// **'This note is locked. Enter the password to open it.'**
  String get lockedNoteEditorMessage;

  /// No description provided for @lockNote.
  ///
  /// In en, this message translates to:
  /// **'Lock note'**
  String get lockNote;

  /// No description provided for @lockNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Lock this note'**
  String get lockNoteTitle;

  /// No description provided for @lockNoteMessage.
  ///
  /// In en, this message translates to:
  /// **'Protect this note’s content with a password. Images and sketches are encrypted too.'**
  String get lockNoteMessage;

  /// No description provided for @unlockNote.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockNote;

  /// No description provided for @unlockNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock note'**
  String get unlockNoteTitle;

  /// No description provided for @removePassword.
  ///
  /// In en, this message translates to:
  /// **'Remove password'**
  String get removePassword;

  /// No description provided for @removePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove password'**
  String get removePasswordTitle;

  /// No description provided for @removePasswordMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to store this note without encryption on this device.'**
  String get removePasswordMessage;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 4 characters.'**
  String get passwordTooShort;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordMismatch;

  /// No description provided for @incorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password.'**
  String get incorrectPassword;

  /// No description provided for @lockFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not lock the note. Please try again.'**
  String get lockFailed;

  /// No description provided for @unlockFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not unlock the note. Please try again.'**
  String get unlockFailed;

  /// No description provided for @corruptLockedNote.
  ///
  /// In en, this message translates to:
  /// **'This locked note’s data is missing or damaged and cannot be opened.'**
  String get corruptLockedNote;

  /// No description provided for @passwordNoRecoveryWarning.
  ///
  /// In en, this message translates to:
  /// **'There is no password recovery. If you forget it, this note’s protected content cannot be opened.'**
  String get passwordNoRecoveryWarning;

  /// No description provided for @togglePasswordVisibility.
  ///
  /// In en, this message translates to:
  /// **'Show or hide password'**
  String get togglePasswordVisibility;

  /// No description provided for @editNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get editNote;

  /// No description provided for @noteTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get noteTitleHint;

  /// No description provided for @noteBodyHint.
  ///
  /// In en, this message translates to:
  /// **'Start writing…'**
  String get noteBodyHint;

  /// No description provided for @deleteNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete note?'**
  String get deleteNoteTitle;

  /// No description provided for @deleteNoteMessage.
  ///
  /// In en, this message translates to:
  /// **'This note will be permanently removed from this device.'**
  String get deleteNoteMessage;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @notesLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load notes. Please try again.'**
  String get notesLoadError;

  /// No description provided for @foldersLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load folders. Please try again.'**
  String get foldersLoadError;

  /// No description provided for @tagsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load tags. Please try again.'**
  String get tagsLoadError;

  /// No description provided for @noteSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the note. Please try again.'**
  String get noteSaveFailed;

  /// No description provided for @noteMissing.
  ///
  /// In en, this message translates to:
  /// **'This note could not be found.'**
  String get noteMissing;

  /// No description provided for @noteLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this note. Please try again.'**
  String get noteLoadFailed;

  /// No description provided for @databaseOpenErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not open local storage'**
  String get databaseOpenErrorTitle;

  /// No description provided for @databaseOpenErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Noteon could not start its local database on this device. Try again. If the problem continues, restart the device. Reinstalling the app will erase local notes.'**
  String get databaseOpenErrorMessage;

  /// No description provided for @databaseOpenErrorCode.
  ///
  /// In en, this message translates to:
  /// **'Error code: {code}'**
  String databaseOpenErrorCode(String code);

  /// No description provided for @databaseOpenErrorDebugLabel.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic details (debug/profile)'**
  String get databaseOpenErrorDebugLabel;

  /// No description provided for @closeApp.
  ///
  /// In en, this message translates to:
  /// **'Close app'**
  String get closeApp;

  /// No description provided for @unfiledNotes.
  ///
  /// In en, this message translates to:
  /// **'Unfiled'**
  String get unfiledNotes;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @searchFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Search: {query}'**
  String searchFilterLabel(String query);

  /// No description provided for @noMatchingNotes.
  ///
  /// In en, this message translates to:
  /// **'No matching notes'**
  String get noMatchingNotes;

  /// No description provided for @noMatchingNotesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or clear the active filters.'**
  String get noMatchingNotesSubtitle;

  /// No description provided for @dateGroupToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dateGroupToday;

  /// No description provided for @dateGroupYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dateGroupYesterday;

  /// No description provided for @dateGroupThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get dateGroupThisWeek;

  /// No description provided for @dateGroupOlder.
  ///
  /// In en, this message translates to:
  /// **'Older'**
  String get dateGroupOlder;

  /// No description provided for @organize.
  ///
  /// In en, this message translates to:
  /// **'Organize'**
  String get organize;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @newSubfolder.
  ///
  /// In en, this message translates to:
  /// **'New subfolder'**
  String get newSubfolder;

  /// No description provided for @renameFolder.
  ///
  /// In en, this message translates to:
  /// **'Rename folder'**
  String get renameFolder;

  /// No description provided for @deleteFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete folder?'**
  String get deleteFolderTitle;

  /// No description provided for @deleteFolderMessage.
  ///
  /// In en, this message translates to:
  /// **'Notes in this folder will become unfiled. Subfolders will also be removed.'**
  String get deleteFolderMessage;

  /// No description provided for @folderNameHint.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderNameHint;

  /// No description provided for @folderActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the folder. Please try again.'**
  String get folderActionFailed;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @newTag.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get newTag;

  /// No description provided for @renameTag.
  ///
  /// In en, this message translates to:
  /// **'Rename tag'**
  String get renameTag;

  /// No description provided for @deleteTagTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete tag?'**
  String get deleteTagTitle;

  /// No description provided for @deleteTagMessage.
  ///
  /// In en, this message translates to:
  /// **'This tag will be removed from all notes.'**
  String get deleteTagMessage;

  /// No description provided for @tagNameHint.
  ///
  /// In en, this message translates to:
  /// **'Tag name'**
  String get tagNameHint;

  /// No description provided for @tagActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the tag. Please try again.'**
  String get tagActionFailed;

  /// No description provided for @tagAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'A tag with this name already exists.'**
  String get tagAlreadyExists;

  /// No description provided for @addTag.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get addTag;

  /// No description provided for @noteFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get noteFolder;

  /// No description provided for @noteTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get noteTags;

  /// No description provided for @noFolder.
  ///
  /// In en, this message translates to:
  /// **'No folder'**
  String get noFolder;

  /// No description provided for @manageFolders.
  ///
  /// In en, this message translates to:
  /// **'Manage folders'**
  String get manageFolders;

  /// No description provided for @manageTags.
  ///
  /// In en, this message translates to:
  /// **'Manage tags'**
  String get manageTags;

  /// No description provided for @filterByTag.
  ///
  /// In en, this message translates to:
  /// **'Tag: {name}'**
  String filterByTag(String name);

  /// No description provided for @filterByFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder: {name}'**
  String filterByFolder(String name);

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @emptyFolders.
  ///
  /// In en, this message translates to:
  /// **'No folders yet'**
  String get emptyFolders;

  /// No description provided for @emptyFoldersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a folder to organize your notes.'**
  String get emptyFoldersSubtitle;

  /// No description provided for @emptyTags.
  ///
  /// In en, this message translates to:
  /// **'No tags yet'**
  String get emptyTags;

  /// No description provided for @emptyTagsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create tags to label and find notes faster.'**
  String get emptyTagsSubtitle;

  /// No description provided for @addImage.
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get addImage;

  /// No description provided for @addImageFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get addImageFromGallery;

  /// No description provided for @addImageFromCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get addImageFromCamera;

  /// No description provided for @imageMissing.
  ///
  /// In en, this message translates to:
  /// **'Image unavailable'**
  String get imageMissing;

  /// No description provided for @imageImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add the image. Please try again.'**
  String get imageImportFailed;

  /// No description provided for @imagePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Photo access was denied. You can enable it in system settings.'**
  String get imagePermissionDenied;

  /// No description provided for @addSketch.
  ///
  /// In en, this message translates to:
  /// **'Add sketch'**
  String get addSketch;

  /// No description provided for @newSketch.
  ///
  /// In en, this message translates to:
  /// **'Sketch'**
  String get newSketch;

  /// No description provided for @sketchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Draw something before saving.'**
  String get sketchEmpty;

  /// No description provided for @sketchSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the sketch. Please try again.'**
  String get sketchSaveFailed;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @clearCanvas.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearCanvas;

  /// No description provided for @sketchPen.
  ///
  /// In en, this message translates to:
  /// **'Pen'**
  String get sketchPen;

  /// No description provided for @sketchHighlighter.
  ///
  /// In en, this message translates to:
  /// **'Highlighter'**
  String get sketchHighlighter;

  /// No description provided for @sketchEraser.
  ///
  /// In en, this message translates to:
  /// **'Eraser'**
  String get sketchEraser;

  /// No description provided for @sketchLasso.
  ///
  /// In en, this message translates to:
  /// **'Lasso'**
  String get sketchLasso;

  /// No description provided for @inkDrawingLabel.
  ///
  /// In en, this message translates to:
  /// **'Drawing'**
  String get inkDrawingLabel;

  /// No description provided for @inkDeleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get inkDeleteSelected;

  /// No description provided for @inkLassoHint.
  ///
  /// In en, this message translates to:
  /// **'Draw around strokes to select, then drag to move.'**
  String get inkLassoHint;

  /// No description provided for @inkLassoSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected — drag to move'**
  String inkLassoSelected(int count);

  /// No description provided for @addPdf.
  ///
  /// In en, this message translates to:
  /// **'Add PDF'**
  String get addPdf;

  /// No description provided for @pdfDocumentLabel.
  ///
  /// In en, this message translates to:
  /// **'PDF document'**
  String get pdfDocumentLabel;

  /// No description provided for @pdfTapToAnnotate.
  ///
  /// In en, this message translates to:
  /// **'Double-tap or Edit to annotate'**
  String get pdfTapToAnnotate;

  /// No description provided for @pdfMissing.
  ///
  /// In en, this message translates to:
  /// **'PDF unavailable'**
  String get pdfMissing;

  /// No description provided for @pdfImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add the PDF. Please try again.'**
  String get pdfImportFailed;

  /// No description provided for @pdfAnnotateSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save annotations. Please try again.'**
  String get pdfAnnotateSaveFailed;

  /// No description provided for @pdfPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String pdfPageLabel(int page);

  /// No description provided for @insertTable.
  ///
  /// In en, this message translates to:
  /// **'Insert table'**
  String get insertTable;

  /// No description provided for @insertTableTitle.
  ///
  /// In en, this message translates to:
  /// **'Insert table'**
  String get insertTableTitle;

  /// No description provided for @insertTableMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose how many rows and columns to start with.'**
  String get insertTableMessage;

  /// No description provided for @tableRows.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get tableRows;

  /// No description provided for @tableColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get tableColumns;

  /// No description provided for @tableLabel.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get tableLabel;

  /// No description provided for @tableTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Table title'**
  String get tableTitleHint;

  /// No description provided for @tableTitleOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get tableTitleOptional;

  /// No description provided for @tableActions.
  ///
  /// In en, this message translates to:
  /// **'Table actions'**
  String get tableActions;

  /// No description provided for @tableAddRow.
  ///
  /// In en, this message translates to:
  /// **'Add row'**
  String get tableAddRow;

  /// No description provided for @tableRemoveRow.
  ///
  /// In en, this message translates to:
  /// **'Remove row'**
  String get tableRemoveRow;

  /// No description provided for @tableAddColumn.
  ///
  /// In en, this message translates to:
  /// **'Add column'**
  String get tableAddColumn;

  /// No description provided for @tableRemoveColumn.
  ///
  /// In en, this message translates to:
  /// **'Remove column'**
  String get tableRemoveColumn;

  /// No description provided for @deleteTable.
  ///
  /// In en, this message translates to:
  /// **'Delete table'**
  String get deleteTable;

  /// No description provided for @deleteTableTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete table?'**
  String get deleteTableTitle;

  /// No description provided for @deleteTableMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes the table from the note. This cannot be undone.'**
  String get deleteTableMessage;

  /// No description provided for @notesViewList.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get notesViewList;

  /// No description provided for @notesViewGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get notesViewGrid;

  /// No description provided for @blockMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get blockMoveUp;

  /// No description provided for @blockMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get blockMoveDown;

  /// No description provided for @resizeImage.
  ///
  /// In en, this message translates to:
  /// **'Resize image'**
  String get resizeImage;

  /// No description provided for @replaceImage.
  ///
  /// In en, this message translates to:
  /// **'Replace image'**
  String get replaceImage;

  /// No description provided for @editBlock.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editBlock;

  /// No description provided for @resizeImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Image size'**
  String get resizeImageTitle;

  /// No description provided for @resizeImageMessage.
  ///
  /// In en, this message translates to:
  /// **'Adjust how large the image appears. The original file is kept.'**
  String get resizeImageMessage;

  /// No description provided for @deleteBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this item?'**
  String get deleteBlockTitle;

  /// No description provided for @deleteBlockMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes only the selected item from the note.'**
  String get deleteBlockMessage;

  /// No description provided for @addAudio.
  ///
  /// In en, this message translates to:
  /// **'Add audio'**
  String get addAudio;

  /// No description provided for @recordAudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Record audio'**
  String get recordAudioTitle;

  /// No description provided for @recordAudioMessage.
  ///
  /// In en, this message translates to:
  /// **'Tap record, then insert the clip into this note.'**
  String get recordAudioMessage;

  /// No description provided for @audioStartRecording.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get audioStartRecording;

  /// No description provided for @audioStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get audioStop;

  /// No description provided for @insertAudio.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get insertAudio;

  /// No description provided for @audioLabel.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audioLabel;

  /// No description provided for @audioPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get audioPlay;

  /// No description provided for @audioPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get audioPause;

  /// No description provided for @audioMissing.
  ///
  /// In en, this message translates to:
  /// **'Audio unavailable'**
  String get audioMissing;

  /// No description provided for @audioPlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play this audio.'**
  String get audioPlayFailed;

  /// No description provided for @audioRecordFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not record audio. Please try again.'**
  String get audioRecordFailed;

  /// No description provided for @audioPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access was denied. You can enable it in system settings.'**
  String get audioPermissionDenied;

  /// No description provided for @shareNote.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareNote;

  /// No description provided for @shareAsText.
  ///
  /// In en, this message translates to:
  /// **'Share as text'**
  String get shareAsText;

  /// No description provided for @shareAsImage.
  ///
  /// In en, this message translates to:
  /// **'Share as image'**
  String get shareAsImage;

  /// No description provided for @shareAsPdf.
  ///
  /// In en, this message translates to:
  /// **'Share as PDF'**
  String get shareAsPdf;

  /// No description provided for @shareEmptyNote.
  ///
  /// In en, this message translates to:
  /// **'Empty note'**
  String get shareEmptyNote;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not share this note. Please try again.'**
  String get shareFailed;

  /// No description provided for @ocrImage.
  ///
  /// In en, this message translates to:
  /// **'Copy text from image'**
  String get ocrImage;

  /// No description provided for @ocrTitle.
  ///
  /// In en, this message translates to:
  /// **'Text from image'**
  String get ocrTitle;

  /// No description provided for @ocrInsert.
  ///
  /// In en, this message translates to:
  /// **'Insert into note'**
  String get ocrInsert;

  /// No description provided for @ocrCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get ocrCopy;

  /// No description provided for @ocrProgress.
  ///
  /// In en, this message translates to:
  /// **'Reading text…'**
  String get ocrProgress;

  /// No description provided for @ocrUnsupported.
  ///
  /// In en, this message translates to:
  /// **'On-device text recognition is available on Android and iOS.'**
  String get ocrUnsupported;

  /// No description provided for @ocrNoText.
  ///
  /// In en, this message translates to:
  /// **'No text was found in this image.'**
  String get ocrNoText;

  /// No description provided for @ocrFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read text from this image.'**
  String get ocrFailed;

  /// No description provided for @ocrCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard.'**
  String get ocrCopied;

  /// No description provided for @assistNote.
  ///
  /// In en, this message translates to:
  /// **'Local assist'**
  String get assistNote;

  /// No description provided for @assistTidy.
  ///
  /// In en, this message translates to:
  /// **'Tidy spacing'**
  String get assistTidy;

  /// No description provided for @assistTidySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Trim extra spaces and blank lines (selection).'**
  String get assistTidySubtitle;

  /// No description provided for @assistBullets.
  ///
  /// In en, this message translates to:
  /// **'Make bullet list'**
  String get assistBullets;

  /// No description provided for @assistBulletsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn each line into a bullet (selection).'**
  String get assistBulletsSubtitle;

  /// No description provided for @assistFirstLine.
  ///
  /// In en, this message translates to:
  /// **'Separate first line'**
  String get assistFirstLine;

  /// No description provided for @assistFirstLineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a blank line after the first line (selection).'**
  String get assistFirstLineSubtitle;

  /// No description provided for @assistSelectText.
  ///
  /// In en, this message translates to:
  /// **'Select some text in the note first.'**
  String get assistSelectText;

  /// No description provided for @assistApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied locally — nothing was sent to the cloud.'**
  String get assistApplied;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacyOcrTitle.
  ///
  /// In en, this message translates to:
  /// **'On-device OCR'**
  String get privacyOcrTitle;

  /// No description provided for @privacyOcrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Image text recognition runs on this phone. Nothing is uploaded.'**
  String get privacyOcrSubtitle;

  /// No description provided for @privacyAssistTitle.
  ///
  /// In en, this message translates to:
  /// **'Local assist'**
  String get privacyAssistTitle;

  /// No description provided for @privacyAssistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tidy and list helpers run on-device with no cloud AI.'**
  String get privacyAssistSubtitle;

  /// No description provided for @privacyExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Share & export'**
  String get privacyExportTitle;

  /// No description provided for @privacyExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'PDF and shares stay on your device until you choose an app to send them.'**
  String get privacyExportSubtitle;

  /// No description provided for @notePageBackground.
  ///
  /// In en, this message translates to:
  /// **'Note page background'**
  String get notePageBackground;

  /// No description provided for @notePageBackgroundPlain.
  ///
  /// In en, this message translates to:
  /// **'Plain'**
  String get notePageBackgroundPlain;

  /// No description provided for @notePageBackgroundLined.
  ///
  /// In en, this message translates to:
  /// **'Lined'**
  String get notePageBackgroundLined;

  /// No description provided for @notePageBackgroundGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get notePageBackgroundGrid;

  /// No description provided for @backupTransfer.
  ///
  /// In en, this message translates to:
  /// **'Backup & transfer'**
  String get backupTransfer;

  /// No description provided for @backupExportEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Export encrypted backup'**
  String get backupExportEncrypted;

  /// No description provided for @backupExportEncryptedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a password-protected .noteonbak file you can move to another phone.'**
  String get backupExportEncryptedSubtitle;

  /// No description provided for @backupImportEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Import encrypted backup'**
  String get backupImportEncrypted;

  /// No description provided for @backupImportEncryptedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore notes from a .noteonbak file.'**
  String get backupImportEncryptedSubtitle;

  /// No description provided for @backupExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get backupExportTitle;

  /// No description provided for @backupExportMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose a passphrase to encrypt this backup. Locked notes stay locked and keep their own passwords.'**
  String get backupExportMessage;

  /// No description provided for @backupPassphraseNoRecoveryWarning.
  ///
  /// In en, this message translates to:
  /// **'There is no passphrase recovery. If you forget it, this backup cannot be opened.'**
  String get backupPassphraseNoRecoveryWarning;

  /// No description provided for @backupPassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Backup passphrase'**
  String get backupPassphraseLabel;

  /// No description provided for @backupExportAction.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get backupExportAction;

  /// No description provided for @backupExportProgress.
  ///
  /// In en, this message translates to:
  /// **'Creating encrypted backup…'**
  String get backupExportProgress;

  /// No description provided for @backupExportReady.
  ///
  /// In en, this message translates to:
  /// **'Backup ready to share.'**
  String get backupExportReady;

  /// No description provided for @backupExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the backup. Please try again.'**
  String get backupExportFailed;

  /// No description provided for @backupShareSubject.
  ///
  /// In en, this message translates to:
  /// **'Noteon backup'**
  String get backupShareSubject;

  /// No description provided for @backupImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import backup'**
  String get backupImportTitle;

  /// No description provided for @backupImportPassphraseMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter the passphrase used when this backup was created.'**
  String get backupImportPassphraseMessage;

  /// No description provided for @backupImportAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get backupImportAction;

  /// No description provided for @backupImportProgress.
  ///
  /// In en, this message translates to:
  /// **'Importing backup…'**
  String get backupImportProgress;

  /// No description provided for @backupImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import the backup. Please try again.'**
  String get backupImportFailed;

  /// No description provided for @backupIncorrectPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Incorrect backup passphrase.'**
  String get backupIncorrectPassphrase;

  /// No description provided for @backupCorruptFile.
  ///
  /// In en, this message translates to:
  /// **'This backup file is missing, damaged, or not a Noteon backup.'**
  String get backupCorruptFile;

  /// No description provided for @backupImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} notes.'**
  String backupImportSuccess(int count);

  /// No description provided for @backupImportModeTitle.
  ///
  /// In en, this message translates to:
  /// **'How should notes be imported?'**
  String get backupImportModeTitle;

  /// No description provided for @backupImportModeMessage.
  ///
  /// In en, this message translates to:
  /// **'Merge keeps your current notes. Replace deletes everything on this device first.'**
  String get backupImportModeMessage;

  /// No description provided for @backupImportModeMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get backupImportModeMerge;

  /// No description provided for @backupImportModeMergeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add backup notes alongside existing ones.'**
  String get backupImportModeMergeSubtitle;

  /// No description provided for @backupImportModeReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace library'**
  String get backupImportModeReplace;

  /// No description provided for @backupImportModeReplaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all local notes, folders, and tags, then restore the backup.'**
  String get backupImportModeReplaceSubtitle;

  /// No description provided for @backupReplaceConfirmWord.
  ///
  /// In en, this message translates to:
  /// **'REPLACE'**
  String get backupReplaceConfirmWord;

  /// No description provided for @backupReplaceConfirmPrompt.
  ///
  /// In en, this message translates to:
  /// **'Type {word} to confirm replacing everything on this device.'**
  String backupReplaceConfirmPrompt(String word);

  /// No description provided for @backupReplaceConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get backupReplaceConfirmLabel;

  /// No description provided for @backupReplaceConfirmMismatch.
  ///
  /// In en, this message translates to:
  /// **'Confirmation text does not match.'**
  String get backupReplaceConfirmMismatch;

  /// No description provided for @nearbySendTitle.
  ///
  /// In en, this message translates to:
  /// **'Send to nearby device'**
  String get nearbySendTitle;

  /// No description provided for @nearbySendSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show a QR code so another phone on the same Wi‑Fi can receive this backup.'**
  String get nearbySendSubtitle;

  /// No description provided for @nearbyReceiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive from nearby device'**
  String get nearbyReceiveTitle;

  /// No description provided for @nearbyReceiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan the sender’s QR code, confirm the code, then import.'**
  String get nearbyReceiveSubtitle;

  /// No description provided for @nearbySendMessage.
  ///
  /// In en, this message translates to:
  /// **'Keep this screen open. Both phones must be on the same Wi‑Fi network.'**
  String get nearbySendMessage;

  /// No description provided for @nearbyPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing encrypted backup…'**
  String get nearbyPreparing;

  /// No description provided for @nearbyWaitingReceiver.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the other phone to scan and download…'**
  String get nearbyWaitingReceiver;

  /// No description provided for @nearbyTransferring.
  ///
  /// In en, this message translates to:
  /// **'Receiver is downloading the backup…'**
  String get nearbyTransferring;

  /// No description provided for @nearbySendComplete.
  ///
  /// In en, this message translates to:
  /// **'Transfer finished on this phone.'**
  String get nearbySendComplete;

  /// No description provided for @nearbyMarkComplete.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get nearbyMarkComplete;

  /// No description provided for @nearbyDone.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get nearbyDone;

  /// No description provided for @nearbySendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start nearby transfer. Check Wi‑Fi and try again.'**
  String get nearbySendFailed;

  /// No description provided for @nearbyNoWifiAddress.
  ///
  /// In en, this message translates to:
  /// **'Could not find a local Wi‑Fi address. Connect both phones to the same network and try again.'**
  String get nearbyNoWifiAddress;

  /// No description provided for @nearbyReceiveScanMessage.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code on the sender’s phone.'**
  String get nearbyReceiveScanMessage;

  /// No description provided for @nearbyConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Make sure this code matches the one on the sender’s phone before downloading.'**
  String get nearbyConfirmMessage;

  /// No description provided for @nearbyVerifyCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get nearbyVerifyCodeLabel;

  /// No description provided for @nearbyVerifyHint.
  ///
  /// In en, this message translates to:
  /// **'Compare this code on both phones.'**
  String get nearbyVerifyHint;

  /// No description provided for @nearbyCodesMatch.
  ///
  /// In en, this message translates to:
  /// **'Codes match — download'**
  String get nearbyCodesMatch;

  /// No description provided for @nearbyRescan.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get nearbyRescan;

  /// No description provided for @nearbyDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading encrypted backup…'**
  String get nearbyDownloading;

  /// No description provided for @nearbyReceiveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not download the backup. Stay on the same Wi‑Fi and try again.'**
  String get nearbyReceiveFailed;

  /// No description provided for @nearbyMethodQr.
  ///
  /// In en, this message translates to:
  /// **'QR code'**
  String get nearbyMethodQr;

  /// No description provided for @nearbyMethodNfc.
  ///
  /// In en, this message translates to:
  /// **'NFC'**
  String get nearbyMethodNfc;

  /// No description provided for @nearbyReceiveNfcMessage.
  ///
  /// In en, this message translates to:
  /// **'Hold this phone near the NFC tag the sender wrote. QR still works if you prefer.'**
  String get nearbyReceiveNfcMessage;

  /// No description provided for @nearbyNfcWriteAction.
  ///
  /// In en, this message translates to:
  /// **'Write pairing to NFC tag'**
  String get nearbyNfcWriteAction;

  /// No description provided for @nearbyNfcWriteHint.
  ///
  /// In en, this message translates to:
  /// **'Hold an NFC tag to the back of this phone…'**
  String get nearbyNfcWriteHint;

  /// No description provided for @nearbyNfcWriteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Pairing written to NFC tag.'**
  String get nearbyNfcWriteSuccess;

  /// No description provided for @nearbyNfcWriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not write the NFC tag. Try again or use the QR code.'**
  String get nearbyNfcWriteFailed;

  /// No description provided for @nearbyNfcCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel NFC'**
  String get nearbyNfcCancel;

  /// No description provided for @nearbyNfcListening.
  ///
  /// In en, this message translates to:
  /// **'Ready — hold near the sender’s NFC tag…'**
  String get nearbyNfcListening;

  /// No description provided for @nearbyNfcReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read a Noteon pairing tag. Try again or use QR.'**
  String get nearbyNfcReadFailed;

  /// No description provided for @nearbyNfcRetry.
  ///
  /// In en, this message translates to:
  /// **'Try NFC again'**
  String get nearbyNfcRetry;

  /// No description provided for @appLockSection.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get appLockSection;

  /// No description provided for @appLockTitle.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get appLockTitle;

  /// No description provided for @appLockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask for biometrics or a PIN when Noteon opens'**
  String get appLockSubtitle;

  /// No description provided for @appLockUnlockWith.
  ///
  /// In en, this message translates to:
  /// **'Unlock with'**
  String get appLockUnlockWith;

  /// No description provided for @appLockMethodBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Biometrics'**
  String get appLockMethodBiometrics;

  /// No description provided for @appLockMethodPin.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get appLockMethodPin;

  /// No description provided for @appLockChangePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get appLockChangePin;

  /// No description provided for @appLockReasonEnable.
  ///
  /// In en, this message translates to:
  /// **'Confirm to turn on app lock'**
  String get appLockReasonEnable;

  /// No description provided for @appLockReasonUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock Noteon'**
  String get appLockReasonUnlock;

  /// No description provided for @appLockReasonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm it’s you to change app lock'**
  String get appLockReasonConfirm;

  /// No description provided for @appLockReasonReset.
  ///
  /// In en, this message translates to:
  /// **'Confirm with your screen lock to reset the PIN'**
  String get appLockReasonReset;

  /// No description provided for @appLockCreatePin.
  ///
  /// In en, this message translates to:
  /// **'Create a PIN'**
  String get appLockCreatePin;

  /// No description provided for @appLockConfirmPin.
  ///
  /// In en, this message translates to:
  /// **'Enter the PIN again'**
  String get appLockConfirmPin;

  /// No description provided for @appLockPinMismatch.
  ///
  /// In en, this message translates to:
  /// **'The PINs don’t match. Try again.'**
  String get appLockPinMismatch;

  /// No description provided for @appLockEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get appLockEnterPin;

  /// No description provided for @appLockWrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get appLockWrongPin;

  /// No description provided for @appLockTryAgainIn.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {seconds} s.'**
  String appLockTryAgainIn(int seconds);

  /// No description provided for @appLockUseBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Use biometrics'**
  String get appLockUseBiometrics;

  /// No description provided for @appLockForgotPin.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN?'**
  String get appLockForgotPin;

  /// No description provided for @appLockNoScreenLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Can’t reset the PIN'**
  String get appLockNoScreenLockTitle;

  /// No description provided for @appLockNoScreenLockBody.
  ///
  /// In en, this message translates to:
  /// **'This device has no screen lock, so Noteon can’t confirm it’s you.\n\n• Set a screen lock in your device settings, then tap Forgot PIN again. Nothing is lost.\n• Or clear Noteon’s app data in your device settings. This removes the PIN but also deletes all notes on this device, unless you restore an encrypted backup.'**
  String get appLockNoScreenLockBody;

  /// No description provided for @appLockSetNewPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a new PIN'**
  String get appLockSetNewPinTitle;

  /// No description provided for @appLockSetNewPinBody.
  ///
  /// In en, this message translates to:
  /// **'App lock was turned off. Set a new PIN to turn it back on.'**
  String get appLockSetNewPinBody;

  /// No description provided for @appLockLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get appLockLater;

  /// No description provided for @appLockSetPin.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get appLockSetPin;

  /// No description provided for @appLockNoBiometricsForPin.
  ///
  /// In en, this message translates to:
  /// **'Biometrics aren’t set up on this device.'**
  String get appLockNoBiometricsForPin;

  /// No description provided for @appLockLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Noteon is locked'**
  String get appLockLockedTitle;

  /// No description provided for @appLockPinProgress.
  ///
  /// In en, this message translates to:
  /// **'{entered} of {total} digits entered'**
  String appLockPinProgress(int entered, int total);

  /// No description provided for @appLockBackspace.
  ///
  /// In en, this message translates to:
  /// **'Delete last digit'**
  String get appLockBackspace;

  /// No description provided for @appLockOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get appLockOk;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
