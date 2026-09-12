import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar_community/isar.dart';

import '../../../core/crypto/note_crypto_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/providers/media_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/navigation/noteon_page_route.dart';
import '../../folders/data/folder.dart';
import '../../tags/data/tag.dart';
import '../data/media_ref.dart';
import '../data/note.dart';
import '../data/note_content_codec.dart';
import '../data/note_lock_service.dart';
import '../data/note_media_paths.dart';
import 'note_password_dialogs.dart';
import 'noteon_image_embed.dart';
import 'notes_providers.dart';
import 'sketch_editor_screen.dart';

/// Creates or edits a single note with a Quill rich-text body.
///
/// Saves when leaving if content changed. Blank new notes are discarded.
/// Locked notes stay encrypted on disk; decrypted content lives only in a
/// session while unlocked in this screen.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    super.key,
    this.noteId,
    this.initialFolderId,
  });

  /// Existing note id. Null opens a new unsaved draft.
  final Id? noteId;

  /// Optional folder applied to brand-new notes (e.g. active list filter).
  final int? initialFolderId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _titleController = TextEditingController();
  late final QuillController _quillController;
  final _editorFocusNode = FocusNode();
  final _editorScrollController = ScrollController();

  Note? _note;
  bool _loading = true;
  bool _dirty = false;
  bool _isLocked = false;
  bool _sessionUnlocked = false;
  bool _saving = false;
  bool _busyCrypto = false;
  Object? _loadError;
  int? _folderId;
  List<int> _tagIds = [];

  /// True when this session created a persisted note that may need discard.
  bool _isNewDraft = false;

  @override
  void initState() {
    super.initState();
    _quillController = QuillController.basic();
    _titleController.addListener(_markDirty);
    _quillController.addListener(_markDirty);
    _bootstrap();
  }

  void _markDirty() {
    if (!_loading && !_dirty) {
      setState(() => _dirty = true);
    } else {
      _dirty = true;
    }
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(noteRepositoryProvider);
    try {
      if (widget.noteId == null) {
        final id = await repo.create(
          title: '',
          contentJson: NoteContentCodec.emptyDeltaJson(),
          folderId: widget.initialFolderId,
        );
        final note = await repo.getById(id);
        _note = note;
        _folderId = note?.folderId;
        _tagIds = List<int>.from(note?.tagIds ?? const []);
        _isNewDraft = true;
        _isLocked = note?.isLocked ?? false;
      } else {
        final note = await repo.getById(widget.noteId!);
        if (note == null) {
          _loadError = 'missing';
        } else {
          _note = note;
          _isLocked = note.isLocked;
          _folderId = note.folderId;
          _tagIds = List<int>.from(note.tagIds);
          _titleController.text = note.title;
          if (!note.isLocked) {
            _quillController.document = NoteContentCodec.documentFromJson(
              note.contentJson,
            );
          }
        }
      }
    } catch (error) {
      _loadError = error;
    }

    _dirty = false;
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _clearUnlockSession() {
    final session = ref.read(unlockedNoteSessionProvider);
    session?.clearSensitive();
    ref.read(unlockedNoteSessionProvider.notifier).state = null;
    _sessionUnlocked = false;
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_markDirty)
      ..dispose();
    _quillController
      ..removeListener(_markDirty)
      ..dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    // Session may still be referenced via provider; clear on leave via pop.
    super.dispose();
  }

  String get _contentJson {
    if (_isLocked && !_sessionUnlocked) {
      return '';
    }
    return NoteContentCodec.encodeDocument(_quillController.document);
  }

  List<MediaRef> _currentMediaRefs(String contentJson) {
    final session = ref.read(unlockedNoteSessionProvider);
    final previous = session?.mediaRefs ?? _note?.mediaRefs ?? const <MediaRef>[];
    final live = NoteMediaPaths.extractFromContentJson(contentJson);
    final byPath = {
      for (final ref in previous) ref.relativePath.replaceAll('\\', '/'): ref,
    };
    return live.map((path) {
      final existing = byPath[path];
      if (existing != null) {
        return existing;
      }
      return MediaRef()
        ..relativePath = path
        ..kind = path.startsWith('sketches/') ? 'sketch' : 'image'
        ..createdAt = DateTime.now();
    }).toList();
  }

  Future<bool> _persistChanges() async {
    if (_saving) {
      return false;
    }
    final note = _note;
    if (note == null) {
      return false;
    }

    final title = _titleController.text;
    final contentJson = _contentJson;
    final repo = ref.read(noteRepositoryProvider);
    final lockService = ref.read(noteLockServiceProvider);

    if (_isNewDraft &&
        !_isLocked &&
        NoteContentCodec.isBlankNote(title: title, contentJson: contentJson)) {
      await repo.delete(note.id);
      _note = null;
      _clearUnlockSession();
      return true;
    }

    if (!_dirty && !_isNewDraft) {
      return false;
    }

    _saving = true;
    try {
      note
        ..title = title.trim()
        ..folderId = _folderId
        ..tagIds = List<int>.from(_tagIds);

      if (_isLocked && _sessionUnlocked) {
        final session = ref.read(unlockedNoteSessionProvider);
        if (session == null) {
          throw const NoteCryptoException(NoteCryptoErrorCode.invalidSession);
        }
        // Ensure newly imported plaintext files are available to the session.
        await _hydrateSessionMedia(session, contentJson);
        await lockService.saveUnlockedNote(
          note: note,
          session: session,
          contentJson: contentJson,
          mediaRefs: _currentMediaRefs(contentJson),
        );
        await repo.update(note);
      } else if (!_isLocked) {
        final media = ref.read(mediaStorageProvider);
        note
          ..contentJson = contentJson
          ..mediaRefs = await media.reconcile(
            previous: note.mediaRefs,
            liveRelativePaths: NoteMediaPaths.extractFromContentJson(
              contentJson,
            ),
          );
        await repo.update(note);
      } else {
        // Locked without session: only metadata (title/folder/tags).
        await repo.update(note);
      }

      _dirty = false;
      _isNewDraft = false;
      return true;
    } finally {
      _saving = false;
    }
  }

  Future<void> _hydrateSessionMedia(
    UnlockedNoteSession session,
    String contentJson,
  ) async {
    final media = ref.read(mediaStorageProvider);
    for (final path in NoteMediaPaths.extractFromContentJson(contentJson)) {
      if (session.mediaBytes.containsKey(path)) {
        continue;
      }
      final file = await media.fileFor(path);
      if (file != null) {
        session.mediaBytes[path] = await file.readAsBytes();
      }
    }
  }

  Future<void> _lockNote() async {
    final l10n = AppLocalizations.of(context);
    final note = _note;
    if (note == null || _isLocked || _busyCrypto) {
      return;
    }

    final result = await showSetNotePasswordDialog(context);
    if (result == null || !mounted) {
      return;
    }

    setState(() => _busyCrypto = true);
    try {
      // Persist any pending plaintext edits first so lock seals current content.
      _dirty = true;
      final contentJson = NoteContentCodec.encodeDocument(
        _quillController.document,
      );
      final media = ref.read(mediaStorageProvider);
      final mediaRefs = await media.reconcile(
        previous: note.mediaRefs,
        liveRelativePaths: NoteMediaPaths.extractFromContentJson(contentJson),
      );

      note
        ..title = _titleController.text.trim()
        ..folderId = _folderId
        ..tagIds = List<int>.from(_tagIds)
        ..contentJson = contentJson
        ..mediaRefs = mediaRefs;

      await ref.read(noteLockServiceProvider).lockNote(
            note: note,
            password: result.password,
            contentJson: contentJson,
            mediaRefs: mediaRefs,
          );
      await ref.read(noteRepositoryProvider).update(note);

      _quillController.document = Document();
      _clearUnlockSession();
      setState(() {
        _isLocked = true;
        _sessionUnlocked = false;
        _dirty = false;
        _isNewDraft = false;
      });
    } on NoteCryptoException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.lockFailed)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.lockFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _busyCrypto = false);
      }
    }
  }

  Future<void> _unlockNote() async {
    final l10n = AppLocalizations.of(context);
    final note = _note;
    if (note == null || !_isLocked || _sessionUnlocked || _busyCrypto) {
      return;
    }

    final result = await showUnlockNotePasswordDialog(
      context,
      title: l10n.unlockNoteTitle,
      subtitle: l10n.passwordNoRecoveryWarning,
    );
    if (result == null || !mounted) {
      return;
    }

    setState(() => _busyCrypto = true);
    try {
      final session = await ref.read(noteLockServiceProvider).unlockNote(
            note: note,
            password: result.password,
          );
      ref.read(unlockedNoteSessionProvider.notifier).state = session;
      _quillController.document = NoteContentCodec.documentFromJson(
        session.contentJson,
      );
      setState(() {
        _sessionUnlocked = true;
        _dirty = false;
      });
    } on NoteCryptoException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cryptoErrorMessage(l10n, error))),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unlockFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _busyCrypto = false);
      }
    }
  }

  Future<void> _removePassword() async {
    final l10n = AppLocalizations.of(context);
    final note = _note;
    if (note == null || !_isLocked || _busyCrypto) {
      return;
    }

    // Require password again even if already unlocked in this session.
    final auth = await showUnlockNotePasswordDialog(
      context,
      title: l10n.removePasswordTitle,
      subtitle:
          '${l10n.removePasswordMessage}\n\n${l10n.passwordNoRecoveryWarning}',
      confirmLabel: l10n.removePassword,
    );
    if (auth == null || !mounted) {
      return;
    }

    setState(() => _busyCrypto = true);
    try {
      var session = ref.read(unlockedNoteSessionProvider);
      if (session == null || !_sessionUnlocked) {
        session = await ref.read(noteLockServiceProvider).unlockNote(
              note: note,
              password: auth.password,
            );
        ref.read(unlockedNoteSessionProvider.notifier).state = session;
        _quillController.document = NoteContentCodec.documentFromJson(
          session.contentJson,
        );
        _sessionUnlocked = true;
      } else {
        // Re-verify without exposing which check failed beyond auth errors.
        final verified = await ref.read(noteCryptoServiceProvider).verifyPassword(
              password: auth.password,
              salt: session.salt,
              storedVerifier: session.passwordVerifier,
            );
        if (!verified) {
          throw const NoteCryptoException(NoteCryptoErrorCode.incorrectPassword);
        }
      }

      final contentJson = NoteContentCodec.encodeDocument(
        _quillController.document,
      );
      await _hydrateSessionMedia(session, contentJson);
      final mediaRefs = _currentMediaRefs(contentJson);

      await ref.read(noteLockServiceProvider).removePassword(
            note: note,
            session: session,
            contentJson: contentJson,
            mediaRefs: mediaRefs,
          );
      note
        ..title = _titleController.text.trim()
        ..folderId = _folderId
        ..tagIds = List<int>.from(_tagIds);
      await ref.read(noteRepositoryProvider).update(note);
      _clearUnlockSession();
      setState(() {
        _isLocked = false;
        _sessionUnlocked = false;
        _dirty = false;
      });
    } on NoteCryptoException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cryptoErrorMessage(l10n, error))),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unlockFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _busyCrypto = false);
      }
    }
  }

  String _cryptoErrorMessage(AppLocalizations l10n, NoteCryptoException error) {
    return switch (error.code) {
      NoteCryptoErrorCode.incorrectPassword => l10n.incorrectPassword,
      NoteCryptoErrorCode.corruptData ||
      NoteCryptoErrorCode.missingData ||
      NoteCryptoErrorCode.authenticationFailed =>
        l10n.corruptLockedNote,
      NoteCryptoErrorCode.passwordTooShort => l10n.passwordTooShort,
      NoteCryptoErrorCode.alreadyLocked ||
      NoteCryptoErrorCode.notLocked ||
      NoteCryptoErrorCode.invalidSession =>
        l10n.unlockFailed,
    };
  }

  Future<void> _showImageSourceSheet() async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l10n.addImageFromGallery),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(l10n.addImageFromCamera),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }
    await _importAndInsertImage(source);
  }

  Future<void> _importAndInsertImage(ImageSource source) async {
    final l10n = AppLocalizations.of(context);
    final picker = ImagePicker();

    try {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 92,
      );
      if (picked == null || !mounted) {
        return;
      }

      final media = ref.read(mediaStorageProvider);
      final refMedia = await media.importImageFile(File(picked.path));
      final bytes = await media.fileFor(refMedia.relativePath);
      final session = ref.read(unlockedNoteSessionProvider);
      if (session != null && bytes != null) {
        session.mediaBytes[refMedia.relativePath] = await bytes.readAsBytes();
        session.mediaRefs = [...session.mediaRefs, refMedia];
      }
      _insertImageEmbed(refMedia.relativePath);
      setState(() => _dirty = true);
    } on PathAccessException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.imagePermissionDenied)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.toString().toLowerCase().contains('permission')
          ? l10n.imagePermissionDenied
          : l10n.imageImportFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _insertImageEmbed(String relativePath) {
    final index = _quillController.selection.isValid
        ? _quillController.selection.baseOffset
        : _quillController.document.length - 1;
    final safeIndex = index.clamp(0, _quillController.document.length - 1);

    _quillController.replaceText(
      safeIndex,
      0,
      BlockEmbed.image(relativePath),
      TextSelection.collapsed(offset: safeIndex + 1),
    );
    _quillController.replaceText(
      safeIndex + 1,
      0,
      '\n',
      TextSelection.collapsed(offset: safeIndex + 2),
    );
  }

  Future<void> _openSketchEditor() async {
    final l10n = AppLocalizations.of(context);
    try {
      final relativePath = await Navigator.of(context).push<String>(
        NoteonPageRoute(builder: (_) => const SketchEditorScreen()),
      );
      if (relativePath == null || !mounted) {
        return;
      }
      final media = ref.read(mediaStorageProvider);
      final file = await media.fileFor(relativePath);
      final session = ref.read(unlockedNoteSessionProvider);
      if (session != null && file != null) {
        session.mediaBytes[relativePath] = await file.readAsBytes();
        session.mediaRefs = [
          ...session.mediaRefs,
          MediaRef()
            ..relativePath = relativePath
            ..kind = 'sketch'
            ..createdAt = DateTime.now(),
        ];
      }
      _insertImageEmbed(relativePath);
      setState(() => _dirty = true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sketchSaveFailed)),
      );
    }
  }

  Future<void> _handlePop() async {
    final l10n = AppLocalizations.of(context);
    try {
      final changed = await _persistChanges();
      _clearUnlockSession();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(changed);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noteSaveFailed)),
      );
      // Keep the editor open so the user can retry or discard intentionally.
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.deleteNoteTitle),
          content: Text(l10n.deleteNoteMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || _note == null) {
      return;
    }

    await ref.read(noteRepositoryProvider).delete(_note!.id);
    _clearUnlockSession();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _pickFolder(List<Folder> folders) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.inbox_outlined),
                title: Text(l10n.noFolder),
                onTap: () => Navigator.pop(context, -1),
              ),
              for (final folder in folders)
                ListTile(
                  leading: Icon(
                    folder.parentFolderId == null
                        ? Icons.folder_outlined
                        : Icons.folder_open_outlined,
                    color: AppColors.teal,
                  ),
                  title: Text(
                    folder.parentFolderId == null
                        ? folder.name
                        : '  ${folder.name}',
                  ),
                  selected: _folderId == folder.id,
                  onTap: () => Navigator.pop(context, folder.id),
                ),
            ],
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }
    setState(() {
      _folderId = selected == -1 ? null : selected;
      _dirty = true;
    });
  }

  Future<void> _addTag(List<Tag> existingTags) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.addTag),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.tagNameHint),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(l10n.addTag),
            ),
          ],
        );
      },
    );

    if (name == null || name.trim().isEmpty) {
      return;
    }

    final tagId = await ref.read(tagRepositoryProvider).createOrGet(name);
    await ref.read(tagsListProvider.notifier).refresh();
    if (!_tagIds.contains(tagId)) {
      setState(() {
        _tagIds = [..._tagIds, tagId];
        _dirty = true;
      });
    }
  }

  bool get _canEditBody => !_isLocked || _sessionUnlocked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await _handlePop();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const BackButtonIcon(),
            onPressed: _handlePop,
          ),
          title: Text(
            _isNewDraft ? l10n.newNote : l10n.editNote,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            if (_dirty && !_busyCrypto)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.teal,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            if (_busyCrypto)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            if (_note != null && !_busyCrypto)
              PopupMenuButton<_NoteSecurityAction>(
                tooltip: l10n.lockNote,
                onSelected: (action) {
                  switch (action) {
                    case _NoteSecurityAction.lock:
                      _lockNote();
                    case _NoteSecurityAction.unlock:
                      _unlockNote();
                    case _NoteSecurityAction.removePassword:
                      _removePassword();
                    case _NoteSecurityAction.delete:
                      _confirmDelete();
                  }
                },
                itemBuilder: (context) {
                  return [
                    if (!_isLocked)
                      PopupMenuItem(
                        value: _NoteSecurityAction.lock,
                        child: Text(l10n.lockNote),
                      ),
                    if (_isLocked && !_sessionUnlocked)
                      PopupMenuItem(
                        value: _NoteSecurityAction.unlock,
                        child: Text(l10n.unlockNote),
                      ),
                    if (_isLocked)
                      PopupMenuItem(
                        value: _NoteSecurityAction.removePassword,
                        child: Text(l10n.removePassword),
                      ),
                    if (!_isNewDraft)
                      PopupMenuItem(
                        value: _NoteSecurityAction.delete,
                        child: Text(l10n.delete),
                      ),
                  ];
                },
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: _buildBody(l10n, theme),
        ),
      ),
    );
  }

  String _tagLabel(List<Tag> tags, int tagId) {
    final matches = tags.where((tag) => tag.id == tagId);
    return matches.isEmpty ? '#$tagId' : matches.first.name;
  }

  Widget _buildBody(AppLocalizations l10n, ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null || _note == null) {
      final message =
          _loadError == 'missing' ? l10n.noteMissing : l10n.noteLoadFailed;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
    }

    final folders = ref.watch(foldersListProvider).valueOrNull ?? const [];
    final tags = ref.watch(tagsListProvider).valueOrNull ?? const [];
    final folderMatches = folders.where((folder) => folder.id == _folderId);
    final folderName =
        _folderId == null || folderMatches.isEmpty
            ? l10n.noFolder
            : folderMatches.first.name;

    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: TextField(
            controller: _titleController,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.25,
            ),
            maxLength: 200,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: l10n.noteTitleHint,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
              counterText: '',
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.folder_outlined, size: 18),
                  label: Text(folderName),
                  onPressed: () => _pickFolder(folders),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                for (final tagId in _tagIds) ...[
                  InputChip(
                    label: Text(_tagLabel(tags, tagId)),
                    onDeleted: () {
                      setState(() {
                        _tagIds = _tagIds.where((id) => id != tagId).toList();
                        _dirty = true;
                      });
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                ],
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.addTag),
                  onPressed: () => _addTag(tags),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
        if (_isLocked && !_sessionUnlocked)
          Expanded(
            child: _LockedBody(
              message: l10n.lockedNoteEditorMessage,
              unlockLabel: l10n.unlockNote,
              onUnlock: _busyCrypto ? null : _unlockNote,
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDarkElevated
                    : AppColors.surfaceLightAlt,
                borderRadius: AppRadii.control,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: QuillSimpleToolbar(
                      controller: _quillController,
                      config: const QuillSimpleToolbarConfig(
                        multiRowsDisplay: false,
                        showDividers: false,
                        showFontFamily: false,
                        showFontSize: false,
                        showStrikeThrough: false,
                        showInlineCode: false,
                        showColorButton: false,
                        showBackgroundColorButton: false,
                        showClearFormat: false,
                        showHeaderStyle: false,
                        showListCheck: false,
                        showCodeBlock: false,
                        showQuote: false,
                        showIndent: false,
                        showLink: false,
                        showSearchButton: false,
                        showSubscript: false,
                        showSuperscript: false,
                        showBoldButton: true,
                        showItalicButton: true,
                        showUnderLineButton: true,
                        showListBullets: true,
                        showListNumbers: true,
                        showUndo: true,
                        showRedo: true,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.addImage,
                    onPressed: _canEditBody ? _showImageSourceSheet : null,
                    icon: const Icon(Icons.image_outlined),
                  ),
                  IconButton(
                    tooltip: l10n.addSketch,
                    onPressed: _canEditBody ? _openSketchEditor : null,
                    icon: const Icon(Icons.brush_outlined),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: QuillEditor.basic(
                controller: _quillController,
                focusNode: _editorFocusNode,
                scrollController: _editorScrollController,
                config: QuillEditorConfig(
                  placeholder: l10n.noteBodyHint,
                  padding: const EdgeInsets.only(bottom: 48),
                  autoFocus: _isNewDraft,
                  embedBuilders: [
                    NoteonImageEmbedBuilder(noteId: _note?.id),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum _NoteSecurityAction {
  lock,
  unlock,
  removePassword,
  delete,
}

class _LockedBody extends StatelessWidget {
  const _LockedBody({
    required this.message,
    required this.unlockLabel,
    required this.onUnlock,
  });

  final String message;
  final String unlockLabel;
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: AppRadii.logoTile,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: 40,
                  color: isDark ? AppColors.tealLight : AppColors.tealDark,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onUnlock,
                icon: const Icon(Icons.lock_open_outlined),
                label: Text(unlockLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
