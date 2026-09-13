// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Noteon';

  @override
  String get appTagline => 'Simple and secure notes, stored on your device';

  @override
  String get notes => 'Notes';

  @override
  String get allNotes => 'All notes';

  @override
  String get folders => 'Folders';

  @override
  String get tags => 'Tags';

  @override
  String get searchNotes => 'Search notes';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get about => 'About';

  @override
  String get aboutDescription =>
      'Noteon is a simple and secure notes app that keeps your data locally on your device.';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get emptyNotesTitle => 'No notes yet';

  @override
  String get emptyNotesSubtitle => 'Create your first note to get started.';

  @override
  String get newNote => 'New note';

  @override
  String get untitledNote => 'Untitled';

  @override
  String get emptyNotePreview => 'No additional text';

  @override
  String get lockedNotePreview => 'Locked note';

  @override
  String get lockedNoteEditorMessage =>
      'This note is locked. Enter the password to open it.';

  @override
  String get lockNote => 'Lock note';

  @override
  String get lockNoteTitle => 'Lock this note';

  @override
  String get lockNoteMessage =>
      'Protect this note’s content with a password. Images and sketches are encrypted too.';

  @override
  String get unlockNote => 'Unlock';

  @override
  String get unlockNoteTitle => 'Unlock note';

  @override
  String get removePassword => 'Remove password';

  @override
  String get removePasswordTitle => 'Remove password';

  @override
  String get removePasswordMessage =>
      'Enter your password to store this note without encryption on this device.';

  @override
  String get passwordLabel => 'Password';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get passwordTooShort => 'Use at least 4 characters.';

  @override
  String get passwordMismatch => 'Passwords do not match.';

  @override
  String get incorrectPassword => 'Incorrect password.';

  @override
  String get lockFailed => 'Could not lock the note. Please try again.';

  @override
  String get unlockFailed => 'Could not unlock the note. Please try again.';

  @override
  String get corruptLockedNote =>
      'This locked note’s data is missing or damaged and cannot be opened.';

  @override
  String get passwordNoRecoveryWarning =>
      'There is no password recovery. If you forget it, this note’s protected content cannot be opened.';

  @override
  String get togglePasswordVisibility => 'Show or hide password';

  @override
  String get editNote => 'Note';

  @override
  String get noteTitleHint => 'Title';

  @override
  String get noteBodyHint => 'Start writing…';

  @override
  String get deleteNoteTitle => 'Delete note?';

  @override
  String get deleteNoteMessage =>
      'This note will be permanently removed from this device.';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Try again';

  @override
  String get notesLoadError => 'Could not load notes. Please try again.';

  @override
  String get foldersLoadError => 'Could not load folders. Please try again.';

  @override
  String get tagsLoadError => 'Could not load tags. Please try again.';

  @override
  String get noteSaveFailed => 'Could not save the note. Please try again.';

  @override
  String get noteMissing => 'This note could not be found.';

  @override
  String get noteLoadFailed => 'Could not open this note. Please try again.';

  @override
  String get databaseOpenErrorTitle => 'Could not open local storage';

  @override
  String get databaseOpenErrorMessage =>
      'Noteon could not start its local database on this device. Try again. If the problem continues, restart the device. Reinstalling the app will erase local notes.';

  @override
  String databaseOpenErrorCode(String code) {
    return 'Error code: $code';
  }

  @override
  String get databaseOpenErrorDebugLabel =>
      'Diagnostic details (debug/profile)';

  @override
  String get closeApp => 'Close app';

  @override
  String get unfiledNotes => 'Unfiled';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String searchFilterLabel(String query) {
    return 'Search: $query';
  }

  @override
  String get noMatchingNotes => 'No matching notes';

  @override
  String get noMatchingNotesSubtitle =>
      'Try a different search or clear the active filters.';

  @override
  String get dateGroupToday => 'Today';

  @override
  String get dateGroupYesterday => 'Yesterday';

  @override
  String get dateGroupThisWeek => 'This week';

  @override
  String get dateGroupOlder => 'Older';

  @override
  String get organize => 'Organize';

  @override
  String get newFolder => 'New folder';

  @override
  String get newSubfolder => 'New subfolder';

  @override
  String get renameFolder => 'Rename folder';

  @override
  String get deleteFolderTitle => 'Delete folder?';

  @override
  String get deleteFolderMessage =>
      'Notes in this folder will become unfiled. Subfolders will also be removed.';

  @override
  String get folderNameHint => 'Folder name';

  @override
  String get folderActionFailed =>
      'Could not update the folder. Please try again.';

  @override
  String get save => 'Save';

  @override
  String get newTag => 'New tag';

  @override
  String get renameTag => 'Rename tag';

  @override
  String get deleteTagTitle => 'Delete tag?';

  @override
  String get deleteTagMessage => 'This tag will be removed from all notes.';

  @override
  String get tagNameHint => 'Tag name';

  @override
  String get tagActionFailed => 'Could not update the tag. Please try again.';

  @override
  String get tagAlreadyExists => 'A tag with this name already exists.';

  @override
  String get addTag => 'Add tag';

  @override
  String get noteFolder => 'Folder';

  @override
  String get noteTags => 'Tags';

  @override
  String get noFolder => 'No folder';

  @override
  String get manageFolders => 'Manage folders';

  @override
  String get manageTags => 'Manage tags';

  @override
  String filterByTag(String name) {
    return 'Tag: $name';
  }

  @override
  String filterByFolder(String name) {
    return 'Folder: $name';
  }

  @override
  String get create => 'Create';

  @override
  String get rename => 'Rename';

  @override
  String get emptyFolders => 'No folders yet';

  @override
  String get emptyFoldersSubtitle => 'Create a folder to organize your notes.';

  @override
  String get emptyTags => 'No tags yet';

  @override
  String get emptyTagsSubtitle => 'Create tags to label and find notes faster.';

  @override
  String get addImage => 'Add image';

  @override
  String get addImageFromGallery => 'Choose from gallery';

  @override
  String get addImageFromCamera => 'Take a photo';

  @override
  String get imageMissing => 'Image unavailable';

  @override
  String get imageImportFailed => 'Could not add the image. Please try again.';

  @override
  String get imagePermissionDenied =>
      'Photo access was denied. You can enable it in system settings.';

  @override
  String get addSketch => 'Add sketch';

  @override
  String get newSketch => 'Sketch';

  @override
  String get sketchEmpty => 'Draw something before saving.';

  @override
  String get sketchSaveFailed => 'Could not save the sketch. Please try again.';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get clearCanvas => 'Clear';

  @override
  String get insertTable => 'Insert table';

  @override
  String get insertTableTitle => 'Insert table';

  @override
  String get insertTableMessage =>
      'Choose how many rows and columns to start with.';

  @override
  String get tableRows => 'Rows';

  @override
  String get tableColumns => 'Columns';

  @override
  String get tableLabel => 'Table';

  @override
  String get tableActions => 'Table actions';

  @override
  String get tableAddRow => 'Add row';

  @override
  String get tableRemoveRow => 'Remove row';

  @override
  String get tableAddColumn => 'Add column';

  @override
  String get tableRemoveColumn => 'Remove column';

  @override
  String get deleteTable => 'Delete table';

  @override
  String get deleteTableTitle => 'Delete table?';

  @override
  String get deleteTableMessage =>
      'This removes the table from the note. This cannot be undone.';

  @override
  String get backupTransfer => 'Backup & transfer';

  @override
  String get backupExportEncrypted => 'Export encrypted backup';

  @override
  String get backupExportEncryptedSubtitle =>
      'Create a password-protected .noteonbak file you can move to another phone.';

  @override
  String get backupImportEncrypted => 'Import encrypted backup';

  @override
  String get backupImportEncryptedSubtitle =>
      'Restore notes from a .noteonbak file.';

  @override
  String get backupExportTitle => 'Export backup';

  @override
  String get backupExportMessage =>
      'Choose a passphrase to encrypt this backup. Locked notes stay locked and keep their own passwords.';

  @override
  String get backupPassphraseNoRecoveryWarning =>
      'There is no passphrase recovery. If you forget it, this backup cannot be opened.';

  @override
  String get backupPassphraseLabel => 'Backup passphrase';

  @override
  String get backupExportAction => 'Export';

  @override
  String get backupExportProgress => 'Creating encrypted backup…';

  @override
  String get backupExportReady => 'Backup ready to share.';

  @override
  String get backupExportFailed =>
      'Could not create the backup. Please try again.';

  @override
  String get backupShareSubject => 'Noteon backup';

  @override
  String get backupImportTitle => 'Import backup';

  @override
  String get backupImportPassphraseMessage =>
      'Enter the passphrase used when this backup was created.';

  @override
  String get backupImportAction => 'Import';

  @override
  String get backupImportProgress => 'Importing backup…';

  @override
  String get backupImportFailed =>
      'Could not import the backup. Please try again.';

  @override
  String get backupIncorrectPassphrase => 'Incorrect backup passphrase.';

  @override
  String get backupCorruptFile =>
      'This backup file is missing, damaged, or not a Noteon backup.';

  @override
  String backupImportSuccess(int count) {
    return 'Imported $count notes.';
  }

  @override
  String get backupImportModeTitle => 'How should notes be imported?';

  @override
  String get backupImportModeMessage =>
      'Merge keeps your current notes. Replace deletes everything on this device first.';

  @override
  String get backupImportModeMerge => 'Merge';

  @override
  String get backupImportModeMergeSubtitle =>
      'Add backup notes alongside existing ones.';

  @override
  String get backupImportModeReplace => 'Replace library';

  @override
  String get backupImportModeReplaceSubtitle =>
      'Delete all local notes, folders, and tags, then restore the backup.';

  @override
  String get backupReplaceConfirmWord => 'REPLACE';

  @override
  String backupReplaceConfirmPrompt(String word) {
    return 'Type $word to confirm replacing everything on this device.';
  }

  @override
  String get backupReplaceConfirmLabel => 'Confirmation';

  @override
  String get backupReplaceConfirmMismatch =>
      'Confirmation text does not match.';

  @override
  String get nearbySendTitle => 'Send to nearby device';

  @override
  String get nearbySendSubtitle =>
      'Show a QR code so another phone on the same Wi‑Fi can receive this backup.';

  @override
  String get nearbyReceiveTitle => 'Receive from nearby device';

  @override
  String get nearbyReceiveSubtitle =>
      'Scan the sender’s QR code, confirm the code, then import.';

  @override
  String get nearbySendMessage =>
      'Keep this screen open. Both phones must be on the same Wi‑Fi network.';

  @override
  String get nearbyPreparing => 'Preparing encrypted backup…';

  @override
  String get nearbyWaitingReceiver =>
      'Waiting for the other phone to scan and download…';

  @override
  String get nearbyTransferring => 'Receiver is downloading the backup…';

  @override
  String get nearbySendComplete => 'Transfer finished on this phone.';

  @override
  String get nearbyMarkComplete => 'Done';

  @override
  String get nearbyDone => 'Close';

  @override
  String get nearbySendFailed =>
      'Could not start nearby transfer. Check Wi‑Fi and try again.';

  @override
  String get nearbyNoWifiAddress =>
      'Could not find a local Wi‑Fi address. Connect both phones to the same network and try again.';

  @override
  String get nearbyReceiveScanMessage =>
      'Point the camera at the QR code on the sender’s phone.';

  @override
  String get nearbyConfirmMessage =>
      'Make sure this code matches the one on the sender’s phone before downloading.';

  @override
  String get nearbyVerifyCodeLabel => 'Verification code';

  @override
  String get nearbyVerifyHint => 'Compare this code on both phones.';

  @override
  String get nearbyCodesMatch => 'Codes match — download';

  @override
  String get nearbyRescan => 'Scan again';

  @override
  String get nearbyDownloading => 'Downloading encrypted backup…';

  @override
  String get nearbyReceiveFailed =>
      'Could not download the backup. Stay on the same Wi‑Fi and try again.';

  @override
  String get nearbyMethodQr => 'QR code';

  @override
  String get nearbyMethodNfc => 'NFC';

  @override
  String get nearbyReceiveNfcMessage =>
      'Hold this phone near the NFC tag the sender wrote. QR still works if you prefer.';

  @override
  String get nearbyNfcWriteAction => 'Write pairing to NFC tag';

  @override
  String get nearbyNfcWriteHint => 'Hold an NFC tag to the back of this phone…';

  @override
  String get nearbyNfcWriteSuccess => 'Pairing written to NFC tag.';

  @override
  String get nearbyNfcWriteFailed =>
      'Could not write the NFC tag. Try again or use the QR code.';

  @override
  String get nearbyNfcCancel => 'Cancel NFC';

  @override
  String get nearbyNfcListening => 'Ready — hold near the sender’s NFC tag…';

  @override
  String get nearbyNfcReadFailed =>
      'Could not read a Noteon pairing tag. Try again or use QR.';

  @override
  String get nearbyNfcRetry => 'Try NFC again';
}
