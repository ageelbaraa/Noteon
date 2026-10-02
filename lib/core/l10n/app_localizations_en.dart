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
  String get subfolders => 'Subfolders';

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
  String get sketchPen => 'Pen';

  @override
  String get sketchHighlighter => 'Highlighter';

  @override
  String get sketchEraser => 'Eraser';

  @override
  String get sketchLasso => 'Lasso';

  @override
  String get inkDrawingLabel => 'Drawing';

  @override
  String get inkDeleteSelected => 'Delete selected';

  @override
  String get inkLassoHint =>
      'Draw around strokes to select, then drag to move.';

  @override
  String inkLassoSelected(int count) {
    return '$count selected — drag to move';
  }

  @override
  String get addPdf => 'Add PDF';

  @override
  String get pdfDocumentLabel => 'PDF document';

  @override
  String get pdfTapToAnnotate => 'Double-tap or Edit to annotate';

  @override
  String get pdfMissing => 'PDF unavailable';

  @override
  String get pdfImportFailed => 'Could not add the PDF. Please try again.';

  @override
  String get pdfAnnotateSaveFailed =>
      'Could not save annotations. Please try again.';

  @override
  String pdfPageLabel(int page) {
    return 'Page $page';
  }

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
  String get tableTitleHint => 'Table title';

  @override
  String get tableTitleOptional => 'Optional';

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
  String get notesViewList => 'List view';

  @override
  String get notesViewGrid => 'Grid view';

  @override
  String get blockMoveUp => 'Move up';

  @override
  String get blockMoveDown => 'Move down';

  @override
  String get resizeImage => 'Resize image';

  @override
  String get replaceImage => 'Replace image';

  @override
  String get editBlock => 'Edit';

  @override
  String get resizeImageTitle => 'Image size';

  @override
  String get resizeImageMessage =>
      'Adjust how large the image appears. The original file is kept.';

  @override
  String get deleteBlockTitle => 'Delete this item?';

  @override
  String get deleteBlockMessage =>
      'This removes only the selected item from the note.';

  @override
  String get addAudio => 'Add audio';

  @override
  String get recordAudioTitle => 'Record audio';

  @override
  String get recordAudioMessage =>
      'Tap record, then insert the clip into this note.';

  @override
  String get audioStartRecording => 'Record';

  @override
  String get audioStop => 'Stop';

  @override
  String get insertAudio => 'Insert';

  @override
  String get audioLabel => 'Audio';

  @override
  String get audioPlay => 'Play';

  @override
  String get audioPause => 'Pause';

  @override
  String get audioMissing => 'Audio unavailable';

  @override
  String get audioPlayFailed => 'Could not play this audio.';

  @override
  String get audioRecordFailed => 'Could not record audio. Please try again.';

  @override
  String get audioPermissionDenied =>
      'Microphone access was denied. You can enable it in system settings.';

  @override
  String get shareNote => 'Share';

  @override
  String get shareAsText => 'Share as text';

  @override
  String get shareAsImage => 'Share as image';

  @override
  String get shareAsPdf => 'Share as PDF';

  @override
  String get shareEmptyNote => 'Empty note';

  @override
  String get shareFailed => 'Could not share this note. Please try again.';

  @override
  String get ocrImage => 'Copy text from image';

  @override
  String get ocrTitle => 'Text from image';

  @override
  String get ocrInsert => 'Insert into note';

  @override
  String get ocrCopy => 'Copy';

  @override
  String get ocrProgress => 'Reading text…';

  @override
  String get ocrUnsupported =>
      'On-device text recognition is available on Android and iOS.';

  @override
  String get ocrNoText => 'No text was found in this image.';

  @override
  String get ocrFailed => 'Could not read text from this image.';

  @override
  String get ocrCopied => 'Copied to clipboard.';

  @override
  String get assistNote => 'Local assist';

  @override
  String get assistTidy => 'Tidy spacing';

  @override
  String get assistTidySubtitle =>
      'Trim extra spaces and blank lines (selection).';

  @override
  String get assistBullets => 'Make bullet list';

  @override
  String get assistBulletsSubtitle =>
      'Turn each line into a bullet (selection).';

  @override
  String get assistFirstLine => 'Separate first line';

  @override
  String get assistFirstLineSubtitle =>
      'Add a blank line after the first line (selection).';

  @override
  String get assistSelectText => 'Select some text in the note first.';

  @override
  String get assistApplied =>
      'Applied locally — nothing was sent to the cloud.';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacyOcrTitle => 'On-device OCR';

  @override
  String get privacyOcrSubtitle =>
      'Image text recognition runs on this phone. Nothing is uploaded.';

  @override
  String get privacyAssistTitle => 'Local assist';

  @override
  String get privacyAssistSubtitle =>
      'Tidy and list helpers run on-device with no cloud AI.';

  @override
  String get privacyExportTitle => 'Share & export';

  @override
  String get privacyExportSubtitle =>
      'PDF and shares stay on your device until you choose an app to send them.';

  @override
  String get notePageBackground => 'Note page background';

  @override
  String get notePageBackgroundPlain => 'Plain';

  @override
  String get notePageBackgroundLined => 'Lined';

  @override
  String get notePageBackgroundGrid => 'Grid';

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

  @override
  String get appLockSection => 'Security';

  @override
  String get appLockTitle => 'App lock';

  @override
  String get appLockSubtitle => 'Ask for biometrics or a PIN when Noteon opens';

  @override
  String get appLockUnlockWith => 'Unlock with';

  @override
  String get appLockMethodBiometrics => 'Biometrics';

  @override
  String get appLockMethodPin => 'PIN';

  @override
  String get appLockChangePin => 'Change PIN';

  @override
  String get appLockReasonEnable => 'Confirm to turn on app lock';

  @override
  String get appLockReasonUnlock => 'Unlock Noteon';

  @override
  String get appLockReasonConfirm => 'Confirm it’s you to change app lock';

  @override
  String get appLockReasonReset =>
      'Confirm with your screen lock to reset the PIN';

  @override
  String get appLockCreatePin => 'Create a PIN';

  @override
  String get appLockConfirmPin => 'Enter the PIN again';

  @override
  String get appLockPinMismatch => 'The PINs don’t match. Try again.';

  @override
  String get appLockEnterPin => 'Enter your PIN';

  @override
  String get appLockWrongPin => 'Wrong PIN';

  @override
  String appLockTryAgainIn(int seconds) {
    return 'Too many attempts. Try again in $seconds s.';
  }

  @override
  String get appLockUseBiometrics => 'Use biometrics';

  @override
  String get appLockForgotPin => 'Forgot PIN?';

  @override
  String get appLockNoScreenLockTitle => 'Can’t reset the PIN';

  @override
  String get appLockNoScreenLockBody =>
      'This device has no screen lock, so Noteon can’t confirm it’s you.\n\n• Set a screen lock in your device settings, then tap Forgot PIN again. Nothing is lost.\n• Or clear Noteon’s app data in your device settings. This removes the PIN but also deletes all notes on this device, unless you restore an encrypted backup.';

  @override
  String get appLockSetNewPinTitle => 'Set a new PIN';

  @override
  String get appLockSetNewPinBody =>
      'App lock was turned off. Set a new PIN to turn it back on.';

  @override
  String get appLockLater => 'Later';

  @override
  String get appLockSetPin => 'Set PIN';

  @override
  String get appLockNoBiometricsForPin =>
      'Biometrics aren’t set up on this device.';

  @override
  String get appLockLockedTitle => 'Noteon is locked';

  @override
  String appLockPinProgress(int entered, int total) {
    return '$entered of $total digits entered';
  }

  @override
  String get appLockBackspace => 'Delete last digit';

  @override
  String get appLockOk => 'OK';
}
