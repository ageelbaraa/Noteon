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

  /// No description provided for @editorZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get editorZoomIn;

  /// No description provided for @editorZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get editorZoomOut;

  /// No description provided for @editorZoomReset.
  ///
  /// In en, this message translates to:
  /// **'Reset zoom'**
  String get editorZoomReset;

  /// No description provided for @editorZoomPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String editorZoomPercent(int percent);

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
